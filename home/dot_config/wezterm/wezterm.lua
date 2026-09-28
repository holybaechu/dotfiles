local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Use the default WSL distribution's shell in its Linux home directory.
config.default_prog = { 'wsl.exe', '--cd', '~' }

-- JetBrains Mono is bundled with WezTerm, including its programming ligatures.
config.font = wezterm.font 'JetBrains Mono'
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }
config.hide_tab_bar_if_only_one_tab = true

return config
