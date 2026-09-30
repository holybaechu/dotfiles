vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.completion", version = "stable" },
}, { confirm = false })

require("mini.completion").setup()
