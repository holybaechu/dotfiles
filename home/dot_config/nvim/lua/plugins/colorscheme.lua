vim.pack.add({ "https://github.com/folke/tokyonight.nvim" }, { confirm = false })

require("tokyonight").setup({ style = "night" })
vim.cmd.colorscheme("tokyonight-night")
