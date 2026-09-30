vim.pack.add({
  "https://github.com/zbirenbaum/copilot.lua",
}, { confirm = false })

require("copilot").setup({
  suggestion = {
    enabled = true,
    auto_trigger = true,
    keymap = {
      -- Copilot's default Alt+l and Alt+[/] bindings belong to the window manager.
      accept = "<M-a>",
      accept_word = "<M-w>",
      accept_line = "<M-s>",
      next = "<M-.>",
      prev = "<M-,>",
      dismiss = "<C-]>",
    },
  },
  panel = { enabled = false },
})

local cmp = require("cmp")
cmp.event:on("menu_opened", function()
  vim.b.copilot_suggestion_hidden = true
  require("copilot.suggestion").update_preview()
end)
cmp.event:on("menu_closed", function()
  vim.b.copilot_suggestion_hidden = false
  require("copilot.suggestion").update_preview()
end)
