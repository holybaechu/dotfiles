-- Canopy's core palette comes from apps/yasb/canopy/theme.py.
-- Additional pale accents distinguish syntax and diagnostic categories.
local p = {
  black = "#000000",
  surface = "#111a13",
  raised = "#293b2d",
  pressed = "#3a5540",
  green = "#a6e3a1",
  green_hover = "#b7edb3",
  text = "#f1f6f0",
  muted = "#a6b6a6",
  border = "#728673",
  error = "#f2a59e",
  amber = "#f2d08f",
  blue = "#adcfff",
  cyan = "#9ee0d1",
  lavender = "#d6c4ee",
}

require("tokyonight").load({
  style = "night",
  -- The terminal supplies acrylic blur; keep floating panels opaque below.
  transparent = true,
  dim_inactive = false,
  styles = {
    comments = { italic = false },
    keywords = { bold = true, italic = false },
    sidebars = "dark",
    floats = "dark",
  },
  on_colors = function(c)
    for name, value in pairs({
      bg = p.black,
      bg_dark = p.surface,
      bg_dark1 = p.black,
      bg_highlight = p.surface,
      bg_popup = p.surface,
      bg_float = p.surface,
      bg_sidebar = p.surface,
      bg_statusline = p.raised,
      bg_visual = p.pressed,
      bg_search = p.green,
      fg = p.text,
      fg_dark = p.muted,
      fg_float = p.text,
      fg_sidebar = p.text,
      fg_gutter = p.muted,
      comment = p.muted,
      black = p.black,
      border = p.border,
      border_highlight = p.green,
      dark3 = p.muted,
      dark5 = p.muted,
      terminal_black = p.border,
      blue = p.blue,
      blue0 = p.raised,
      blue1 = p.cyan,
      blue2 = p.cyan,
      blue5 = p.text,
      blue6 = p.cyan,
      blue7 = p.raised,
      green = p.green,
      green1 = p.green_hover,
      green2 = p.cyan,
      cyan = p.lavender,
      teal = p.cyan,
      magenta = p.lavender,
      magenta2 = p.lavender,
      purple = p.lavender,
      orange = p.amber,
      yellow = p.amber,
      red = p.error,
      red1 = p.error,
      error = p.error,
      warning = p.amber,
      info = p.blue,
      hint = p.green,
      todo = p.green,
      git = { add = p.green, change = p.amber, delete = p.error, ignore = p.muted },
      diff = { add = "#102516", change = "#172522", delete = "#2b1717", text = p.pressed },
      rainbow = { p.green, p.amber, p.blue, p.cyan, p.lavender, p.error },
      terminal = {
        black = p.black, black_bright = p.border,
        red = p.error, red_bright = p.error,
        green = p.green, green_bright = p.green_hover,
        yellow = p.amber, yellow_bright = p.amber,
        blue = p.blue, blue_bright = p.blue,
        magenta = p.lavender, magenta_bright = p.lavender,
        cyan = p.cyan, cyan_bright = p.cyan,
        white = p.muted, white_bright = p.text,
      },
    }) do
      c[name] = value
    end
  end,
  on_highlights = function(h)
    h.Identifier = { fg = p.text }
    h["@function.builtin"] = { fg = p.blue }
    h.Directory = { fg = p.green_hover }
    h.CursorLineNr = { fg = p.green, bg = p.surface, bold = true }
    h.Folded = { fg = p.green, bg = p.surface }
    h.Visual = { fg = p.text, bg = p.pressed }
    h.VisualNOS = h.Visual
    h.Search = { fg = p.black, bg = p.green }
    h.IncSearch = { fg = p.black, bg = p.amber, bold = true }
    h.CurSearch = h.IncSearch
    h.MatchParen = { fg = p.black, bg = p.green, bold = true }
    h.StatusLine = { fg = p.text, bg = p.raised }
    h.StatusLineNC = { fg = p.muted, bg = p.surface }
    h.PmenuSel = { fg = p.black, bg = p.green, bold = true }
    h.PmenuMatchSel = { fg = p.black, bg = p.green, bold = true, underline = true }
    h.PmenuSbar = { bg = p.raised }
    h.PmenuThumb = { bg = p.green }
    h.MiniPickMatchCurrent = { fg = p.text, bg = p.raised, bold = true }
    h.MiniPickMatchMarked = h.Visual
    h.MiniPickMatchRanges = { fg = p.green, bold = true, underline = true }
    h.MiniFilesCursorLine = h.MiniPickMatchCurrent
    h.LspReferenceText = { fg = p.text, bg = p.raised }
    h.LspReferenceRead = h.LspReferenceText
    h.LspReferenceWrite = h.LspReferenceText
    h.LspSignatureActiveParameter = { fg = p.green_hover, bg = p.raised, bold = true }
    h.LspInlayHint = { fg = p.muted, bg = p.surface }
    h.ComplHint = { fg = p.muted }
    h.DiagnosticUnnecessary = { fg = p.muted }
    h.DiagnosticVirtualTextError = { fg = p.error, bg = p.surface }
    h.DiagnosticVirtualTextWarn = { fg = p.amber, bg = p.surface }
    h.DiagnosticVirtualTextInfo = { fg = p.blue, bg = p.surface }
    h.DiagnosticVirtualTextHint = { fg = p.green, bg = p.surface }
  end,
})

vim.g.colors_name = "canopy"
