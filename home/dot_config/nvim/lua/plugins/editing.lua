vim.pack.add({
  { src = "https://github.com/nvim-mini/mini.surround", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.ai", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.pairs", version = "stable" },
  { src = "https://github.com/nvim-mini/mini.move", version = "stable" },
}, { confirm = false })

require("mini.surround").setup()
require("mini.ai").setup({
  -- Preserve Neovim 0.12's incremental selection mappings.
  mappings = { around_next = "", inside_next = "", around_last = "", inside_last = "" },
})
-- Load before cmp so its Enter fallback can use MiniPairs' newline handling.
require("mini.pairs").setup()
require("mini.move").setup({
  -- Alt+h/j/k/l and Alt+Shift+h/j/k/l are desktop window-manager bindings.
  mappings = {
    left = "<leader>mh",
    right = "<leader>ml",
    down = "<leader>mj",
    up = "<leader>mk",
    line_left = "<leader>mh",
    line_right = "<leader>ml",
    line_down = "<leader>mj",
    line_up = "<leader>mk",
  },
})
