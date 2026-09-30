vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/mason-org/mason.nvim",
  "https://github.com/mason-org/mason-lspconfig.nvim",
}, { confirm = false })

-- Expose WinGet's default 7-Zip installation to Mason on Windows.
if vim.fn.has("win32") == 1 then
  local seven_zip = vim.env.ProgramFiles .. "/7-Zip"
  if vim.fn.isdirectory(seven_zip) == 1 then
    vim.env.PATH = vim.env.PATH .. ";" .. seven_zip
  end
end

require("mason").setup()

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      telemetry = { enable = false },
    },
  },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("dotfiles_lsp", { clear = true }),
  callback = function(event)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = event.buf, desc = "Go to definition" })
    vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = event.buf, desc = "Rename symbol" })
    vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, {
      buffer = event.buf,
      desc = "Code action",
    })
  end,
})

require("mason-lspconfig").setup({ ensure_installed = { "lua_ls" } })
