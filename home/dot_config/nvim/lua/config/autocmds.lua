vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("dotfiles_yank", { clear = true }),
  desc = "Highlight copied text",
  callback = function()
    vim.hl.on_yank()
  end,
})
