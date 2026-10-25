vim.g.undotree_SetFocusWhenToggle = 1

-- Git for Windows includes GNU diff but normally exposes only its cmd directory.
if vim.fn.has("win32") == 1 and vim.fn.executable("diff") == 0 then
  local git = vim.fn.exepath("git")
  local diff = vim.fs.dirname(vim.fs.dirname(git)) .. "/usr/bin/diff.exe"
  if vim.fn.executable(diff) == 1 then
    -- Undotree validates a command name, so quoted executable paths cannot be used.
    vim.env.PATH = vim.env.PATH .. ";" .. vim.fs.dirname(diff)
  end
end

vim.pack.add({ "https://github.com/mbbill/undotree" }, { confirm = false })
vim.keymap.set("n", "<leader>u", "<Cmd>UndotreeToggle<CR>", { desc = "Toggle undo history" })
