vim.pack.add({
  { src = "https://github.com/L3MON4D3/LuaSnip", version = vim.version.range("2.*") },
  "https://github.com/rafamadriz/friendly-snippets",
}, { confirm = false })

require("luasnip").config.setup({
  update_events = "TextChanged,TextChangedI",
  delete_check_events = "TextChanged,TextChangedI",
})
require("luasnip.loaders.from_vscode").lazy_load()
