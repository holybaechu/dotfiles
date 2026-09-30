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
      -- Windows cannot overwrite a loaded DLL; move it aside before rebuilding.
      if vim.fn.has("win32") == 1 and event.data.active then
        local library = event.data.path .. "/deps/luasnip-jsregexp.so"
        if vim.uv.fs_stat(library) then
          local previous = library .. ".old-" .. vim.uv.hrtime()
          assert(vim.uv.fs_rename(library, previous))
          vim.uv.fs_unlink(previous)
        end
      end
      local command = vim.fn.has("win32") == 1
          and { "mingw32-make", "install_jsregexp", "CC=" .. (vim.env.CC or "clang") }
        or { "make", "install_jsregexp" }
      local result = vim.system(command, { cwd = event.data.path, text = true }):wait()
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
