vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Review and update plugin revisions" })

vim.api.nvim_create_user_command("PackRestore", function()
  vim.pack.update(nil, { target = "lockfile" })
end, { desc = "Review and restore plugins to the lockfile revisions" })

-- Parser revisions must follow the queries shipped with nvim-treesitter.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("dotfiles_pack_builds", { clear = true }),
  callback = function(event)
    if event.data.spec.name == "LuaSnip" and (event.data.kind == "install" or event.data.kind == "update") then
      local result = vim.system({ "make", "install_jsregexp" }, { cwd = event.data.path, text = true }):wait()
      if result.code ~= 0 then
        vim.notify("LuaSnip regex build failed: " .. result.stderr, vim.log.levels.ERROR)
      end
    end
    if event.data.spec.name == "nvim-treesitter" and event.data.kind == "update" then
      vim.schedule(function()
        if not event.data.active then
          vim.cmd.packadd("nvim-treesitter")
        end
        require("nvim-treesitter").update(nil, { max_jobs = 4 })
      end)
    end
  end,
})
