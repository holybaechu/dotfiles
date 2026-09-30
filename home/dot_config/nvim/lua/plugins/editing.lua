vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.surround", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.ai", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.pairs", version = "stable" },
}, { confirm = false })

require("mini.surround").setup()
require("mini.ai").setup({
  -- Preserve Neovim 0.12's incremental selection mappings.
  mappings = { around_next = "", inside_next = "", around_last = "", inside_last = "" },
})
-- Load before cmp so its Enter fallback can use MiniPairs' newline handling.
require("mini.pairs").setup()
