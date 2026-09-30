vim.pack.add({
  "https://github.com/zbirenbaum/copilot.lua",
  "https://github.com/zbirenbaum/copilot-cmp",
}, { confirm = false })

-- Present Copilot through cmp, using the same explicit selection and acceptance keys.
require("copilot").setup({
  suggestion = { enabled = false },
  panel = { enabled = false },
})
require("copilot_cmp").setup()
