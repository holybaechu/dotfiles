vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.pick", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.files", version = "stable" },
}, { confirm = false })

local pick = require("mini.pick")
local files = require("mini.files")
pick.setup()
files.setup({ options = { permanent_delete = false } })

vim.keymap.set("n", "<leader>ff", pick.builtin.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", pick.builtin.grep_live, { desc = "Search project text" })
vim.keymap.set("n", "<leader>fb", pick.builtin.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", pick.builtin.help, { desc = "Search help" })
vim.keymap.set("n", "<leader>e", function()
  local path = vim.api.nvim_buf_get_name(0)
  files.open(path ~= "" and path or vim.uv.cwd())
end, { desc = "Browse files" })
