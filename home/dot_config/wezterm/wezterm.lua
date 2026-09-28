local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Use the default WSL distribution's shell in its Linux home directory.
config.default_prog = { 'wsl.exe', '--cd', '~' }

-- JetBrains Mono is bundled with WezTerm, including its programming ligatures.
config.font = wezterm.font 'JetBrains Mono'
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }
config.hide_tab_bar_if_only_one_tab = true

-- Keep resizing available without a title bar; use a dark frosted backdrop.
config.window_decorations = 'RESIZE'
config.win32_system_backdrop = 'Acrylic'
config.window_background_opacity = 0.65
config.colors = { background = '#111a13' }

-- Alt+Q is an intentional close action in the tiling window manager.
config.window_close_confirmation = 'NeverPrompt'

return config
