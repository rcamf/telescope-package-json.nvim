local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local uv = vim.uv

-- Use Fidget if available, otherwise fall back to notify
local notify = vim.notify
local ok, fnotify = pcall(require, "fidget.notification")
if ok then
  notify = fnotify.notify
end

local config = {
	use_git_root = true,
	search = {
		exclude = { "node_modules", ".git" },
	},
	entries = {
		columns = { "name", "script", "code" },
		format = "%s: %s -> %s",
	},
}

local function run_script_in_new_tab(entry)
	local script = entry.script
	local dir = entry.path
	local initial_name = entry.name .. ": [pnpm] " .. script .. " (running)"

	vim.cmd("tabnew")
	local bufnr = vim.api.nvim_get_current_buf()

	vim.fn.termopen({ "pnpm", "run", script }, {
		cwd = dir,
		on_exit = function(_, code)
			local status = code == 0 and "✅" or "❌"
			local final_name = string.format("[pnpm] %s (%s)", script, status)
			vim.schedule(function()
				-- Safely rename the buffer to include status
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_set_name(bufnr, final_name)
					notify("Script '" .. script .. "' exited with code " .. code, vim.log.levels.INFO)
				end
			end)
		end,
	})

	vim.api.nvim_buf_set_name(bufnr, initial_name)
	vim.cmd("startinsert")
end

local function get_git_root(dir)
	if not uv.fs_stat(dir) then
		return nil
	end
	local cmd = string.format("git -C %s rev-parse --show-toplevel", vim.fn.shellescape(dir))
	local ok, git_root = pcall(vim.fn.systemlist, cmd)
	if not ok or not git_root or git_root == "" then
		return nil
	end
	return git_root[1]
end

local function get_package_json_paths(dir, exclude_dirs)
	local fd = "fd" -- or "fdfind" on Ubuntu, if fd is not aliased
	local exclude = ""
	if exclude_dirs and #exclude_dirs > 0 then
		for _, exclude_dir in ipairs(exclude_dirs) do
			exclude = exclude .. string.format("--exclude %s ", vim.fn.shellescape(exclude_dir))
		end
	end
	local cmd = string.format("%s package.json %s %s --color=never", fd, dir, exclude)
	local ok, output = pcall(vim.fn.systemlist, cmd)
	if not ok then
		notify("Error running fd command: " .. output[1], vim.log.levels.ERROR)
		return {}
	end
	if vim.v.shell_error ~= 0 then
		return {}
	end
	return output
end

local function readFileSync(path)
	local file = assert(uv.fs_open(path, "r", 438)) -- 438 is 0666 in octal
	local stat = assert(uv.fs_fstat(file))
	if stat.size == 0 then
		uv.fs_close(file)
		return nil
	end
	local content = assert(uv.fs_read(file, stat.size, 0))
	assert(uv.fs_close(file))
	return content
end

local function open_scripts_picker(opts)
	opts = opts or {}

	local effective_config = vim.tbl_deep_extend("force", config, opts)

	local buffer_dir = vim.fn.expand("%:p:h")
	local root_dir = effective_config.use_git_root and get_git_root(buffer_dir) or buffer_dir

	local locations = get_package_json_paths(root_dir, effective_config.search.exclude)

	if #locations == 0 then
		notify(
			"No package.json files found in the current directory or its subdirectories.",
			vim.log.levels.INFO
		)
		return
	end

	local entry_maker = function(entry)
		local column_values = {}
		for _, column in ipairs(effective_config.entries.columns) do
			if entry[column] then
				table.insert(column_values, entry[column])
			else
				table.insert(column_values, "N/A")
			end
		end

		local display = string.format(effective_config.entries.format, unpack(column_values))
		return {
			value = entry,
			display = display,
			ordinal = entry.name .. " " .. entry.script .. " " .. entry.code,
		}
	end

	local results = {}
	for _, package_json in pairs(locations) do
		local ok, content = pcall(readFileSync, package_json)
		if not ok or content == nil then
			notify("Error reading package.json at " .. package_json, vim.log.levels.ERROR)
			goto continue
		end
		local ok, json = pcall(vim.fn.json_decode, content)
		if not ok or not json then
			notify("Error parsing package.json at " .. package_json, vim.log.levels.ERROR)
			goto continue
		end
		local scripts = json["scripts"]
		local package_name = json["name"] or "unknown"
		if scripts ~= nil then
			for name, code in pairs(scripts) do
				if name and code then
					table.insert(results, {
						path = vim.fs.dirname(package_json),
						name = package_name,
						code = code,
						script = name,
					})
				end
			end
		end
		::continue::
	end

	pickers
		.new(opts, {
			prompt_title = "Scripts",
			finder = finders.new_table({
				results = results,
				entry_maker = entry_maker,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(_, _)
				actions.select_default:replace(function(prompt_bufnr)
					actions.close(prompt_bufnr)
					local entry = action_state.get_selected_entry()
					if not entry or not entry.value then
						return
					end
					run_script_in_new_tab(entry.value)
				end)
				return true
			end,
		})
		:find()
end

return require("telescope").register_extension({
	setup = function(user_config)
		local format_string = vim.F.if_nil(user_config.entries.format, config.entries.format)
		local placeholder_count = select(2, format_string:gsub("%%[^%%]", ""))
		local columns_count = #user_config.entries.columns

		if placeholder_count ~= columns_count then
			user_config.entries.format = "%s: %s -> %s"
			user_config.entries.columns = { "name", "script", "code" }
		end
		config = vim.tbl_deep_extend("force", config, user_config)
	end,
	exports = {
		scripts = function(opts)
			return open_scripts_picker(opts)
		end,
	},
})
