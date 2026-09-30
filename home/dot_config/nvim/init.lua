assert(vim.fn.has("nvim-0.12") == 1, "This configuration requires Neovim 0.12 or newer")

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.pack")
require("plugins")
