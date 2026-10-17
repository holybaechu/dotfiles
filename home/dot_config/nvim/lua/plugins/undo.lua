vim.g.undotree_SetFocusWhenToggle = 1

vim.pack.add({ "https://github.com/mbbill/undotree" }, { confirm = false })
vim.keymap.set("n", "<leader>u", "<Cmd>UndotreeToggle<CR>", { desc = "Toggle undo history" })
