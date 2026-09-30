vim.pack.add({ "https://github.com/folke/which-key.nvim" }, { confirm = false })

local wk = require("which-key")
wk.setup({
  win = { border = "rounded" },
  icons = { mappings = false },
  spec = {
    { "<leader>f", group = "Find" },
    { "<leader>c", group = "Code", mode = { "n", "x" } },
    { "<leader>g", group = "Git" },
    { "s", group = "Surround", mode = { "n", "x" } },
  },
})
vim.keymap.set("n", "<leader>?", function()
  wk.show({ global = false })
end, { desc = "Show buffer keymaps" })
