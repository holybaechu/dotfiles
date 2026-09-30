vim.pack.add({
  "https://github.com/hrsh7th/nvim-cmp",
  "https://github.com/hrsh7th/cmp-nvim-lsp",
  "https://github.com/hrsh7th/cmp-path",
  "https://github.com/hrsh7th/cmp-buffer",
}, { confirm = false })

local cmp = require("cmp")
-- cmp-path mistakes punctuation in a partial basename for part of the directory.
-- Pass only the directory prefix to its parser; keep the original completion context.
local path_source = require("cmp_path")
local dirname = path_source._dirname
path_source._dirname = function(self, params, option)
  local context = vim.tbl_extend("force", params.context, {
    cursor_before_line = params.context.cursor_before_line:gsub("[^/]*$", ""),
  })
  return dirname(self, vim.tbl_extend("force", params, { context = context }), option)
end

cmp.setup({
  preselect = cmp.PreselectMode.None,
  formatting = {
    format = function(entry, item)
      local labels = { nvim_lsp = "LSP", path = "Path", copilot = "Copilot", buffer = "Buffer" }
      item.menu = "[" .. (labels[entry.source.name] or entry.source.name) .. "]"
      return item
    end,
  },
  snippet = {
    expand = function(args)
      vim.snippet.expand(args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered({
      border = "rounded",
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:CmpSelected,Search:None",
    }),
    documentation = cmp.config.window.bordered({
      border = "rounded",
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,Search:None",
    }),
  },
  mapping = {
    ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
    ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
    ["<C-y>"] = cmp.mapping.confirm({ select = false }),
    ["<CR>"] = cmp.mapping.confirm({ select = false }),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
  },
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "path", option = { trailing_slash = true } },
    { name = "copilot" },
  }, {
    { name = "buffer" },
  }),
})

-- Advertise cmp's supported completion features before servers are enabled.
vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })
