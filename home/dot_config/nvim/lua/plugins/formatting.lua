vim.pack.add({
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",
}, { confirm = false })

require("mason-tool-installer").setup({ ensure_installed = { "stylua" } })
require("conform").setup({ formatters_by_ft = { lua = { "stylua" } } })

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer or selection" })
