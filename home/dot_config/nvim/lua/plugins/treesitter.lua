vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" }, { confirm = false })

-- Windows virtualized paths must resolve before becoming query junction targets.
if vim.fn.has("win32") == 1 then
  local path = vim.pack.get({ "nvim-treesitter" }, { info = false })[1].path
  vim.opt.runtimepath:prepend(vim.uv.fs_realpath(path) or path)
end

local ts = require("nvim-treesitter")
ts.setup()
-- The Windows CLI targets MSVC by default; bootstrap supplies x64 LLVM MinGW.
if vim.fn.has("win32") == 1 and not vim.env.CC then
  vim.env.CC = "clang"
  vim.env.CFLAGS = (vim.env.CFLAGS or "") .. " --target=x86_64-w64-windows-gnu"
end
vim.treesitter.language.register("json", "jsonc")

-- Dotfiles and JavaScript/web project languages; extend this list as needed.
local languages = {
  "bash",
  "css",
  "fish",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "powershell",
  "python",
  "query",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local function start(buf)
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang or not vim.list_contains(languages, lang) then
    return
  end
  if pcall(vim.treesitter.start, buf, lang) then
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.wo[win].foldmethod ~= "expr" then
        vim.wo[win].foldlevel = 99
      end
      vim.wo[win].foldmethod = "expr"
      vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end
  end
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("dotfiles_treesitter", { clear = true }),
  callback = function(event)
    start(event.buf)
  end,
})

-- Build missing parsers asynchronously, then attach to files already open.
ts.install(languages, { max_jobs = 4 }):await(function()
  vim.schedule(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        start(buf)
      end
    end
  end)
end)
