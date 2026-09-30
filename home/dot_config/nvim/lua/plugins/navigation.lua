vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.pick", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.files", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.extra", version = "stable" },
}, { confirm = false })

local pick = require("mini.pick")
local files = require("mini.files")
pick.setup()
files.setup({ options = { permanent_delete = false } })
require("mini.extra").setup()
local extra = MiniExtra.pickers

vim.keymap.set("n", "<leader>ff", pick.builtin.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", pick.builtin.grep_live, { desc = "Search project text" })
vim.keymap.set("n", "<leader>fb", pick.builtin.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", pick.builtin.help, { desc = "Search help" })
vim.keymap.set("n", "<leader>fd", extra.diagnostic, { desc = "Find diagnostics" })
vim.keymap.set("n", "<leader>fo", extra.oldfiles, { desc = "Find recent files" })
vim.keymap.set("n", "<leader>fs", function()
  extra.lsp({ scope = "document_symbol" })
end, { desc = "Find document symbols" })
vim.keymap.set("n", "<leader>fS", function()
  extra.lsp({ scope = "workspace_symbol" })
end, { desc = "Find workspace symbols" })
vim.keymap.set("n", "<leader>fr", function()
  extra.lsp({ scope = "references" })
end, { desc = "Find references" })
vim.keymap.set("n", "<leader>gB", extra.git_branches, { desc = "Browse Git branches" })
vim.keymap.set("n", "<leader>gc", extra.git_commits, { desc = "Browse Git commits" })
vim.keymap.set("n", "<leader>gh", extra.git_hunks, { desc = "Find Git hunks" })
vim.keymap.set("n", "<leader>e", function()
  local path = vim.api.nvim_buf_get_name(0)
  files.open(path ~= "" and path or vim.uv.cwd())
end, { desc = "Browse files" })
