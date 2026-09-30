vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Review and update plugin revisions" })

vim.api.nvim_create_user_command("PackRestore", function()
  vim.pack.update(nil, { target = "lockfile" })
end, { desc = "Review and restore plugins to the lockfile revisions" })

-- Register any future PackChanged build hooks here, before plugins are added.
