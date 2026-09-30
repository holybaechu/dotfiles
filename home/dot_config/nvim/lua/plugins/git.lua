vim.pack.add({ "https://github.com/lewis6991/gitsigns.nvim" }, { confirm = false })

local gitsigns = require("gitsigns")
gitsigns.setup({
  on_attach = function(bufnr)
    vim.keymap.set("n", "]h", function()
      gitsigns.nav_hunk("next")
    end, { buffer = bufnr, desc = "Next Git hunk" })
    vim.keymap.set("n", "[h", function()
      gitsigns.nav_hunk("prev")
    end, { buffer = bufnr, desc = "Previous Git hunk" })
    vim.keymap.set("n", "<leader>gp", gitsigns.preview_hunk, { buffer = bufnr, desc = "Preview Git hunk" })
    vim.keymap.set("n", "<leader>gb", gitsigns.toggle_current_line_blame, {
      buffer = bufnr,
      desc = "Toggle Git blame",
    })
  end,
})
