# telescope-package-json.nvim

A [Telescope](https://github.com/nvim-telescope/telescope.nvim) extension for discovering and running `package.json` scripts in your project — right from Neovim.

## ✨ Features

- Finds `package.json` files in your project (optionally from the Git root).
- Lists all `scripts` entries.
- Runs selected scripts in a new terminal tab using `pnpm` (customizeable).
- Configurable display columns & format string.

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "rcamf/telescope-package-json.nvim",
  },
  opts = {
    extensions = {
      package_json = {
        use_git_root = true,
        entries = {
          columns = { "name", "script", "code" }, -- Display these fields
          format = "%-20s %-15s %s", -- Format string for display
        }
      },
    },
  },
  config = function(_, opts)
    require("telescope").setup(opts)
    require("telescope").load_extension("package_json")
  end,
}
```

## ⚙️ Configuration

The extension accepts options via Telescope’s `extensions` table:

| Option            | Type       | Default                        | Description                                                                                           |
| ----------------- | ---------- | ------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `use_git_root`    | `boolean`  | `true`                         | Search from the Git root instead of the buffer’s directory.                                           |
| `entries.columns` | `string[]` | `{ "name", "script", "code" }` | Which fields to display, in order. The options are "name", "script", "code", and "path"               |
| `entries.format`  | `string`   | `"%-20s %-15s %s"`             | `string.format` pattern for the display line. Placeholders must match the number of `entries.columns`. |

## 🚀 Usage

Once installed and loaded, you can open the picker:

```vim
:Telescope package_json scripts
```

Then:

- Type to fuzzy-search by package name, script, or command.
- Press `<CR>` to run the script in a new tab.
- Script output will be shown in a Neovim terminal buffer.

## 📝 Example

```lua
require("telescope").extensions.package_json.scripts({
    entries = {
        columns = { "name", "script" },
        format = "%-20s %s", -- override defaults for this call
    }
})
```

## 🛠 Requirements

- [Telescope](https://github.com/nvim-telescope/telescope.nvim)
- [fd](https://github.com/sharkdp/fd) (for fast file search)
- `pnpm` in your `$PATH` (or adjust the run command in the source)

## 📄 License

MIT
