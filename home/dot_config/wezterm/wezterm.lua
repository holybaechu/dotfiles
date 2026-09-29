local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Use the default WSL distribution's shell in its Linux home directory.
config.default_prog = { 'wsl.exe', '--cd', '~' }

-- Launch WSL directly; do not block PowerShell windows on distro discovery.
config.wsl_domains = {}

-- JetBrains Mono is bundled with WezTerm, including its programming ligatures.
config.font = wezterm.font 'JetBrains Mono'
config.harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1' }
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

-- Keep the resize frame for komorebi; Appearance.ps1 removes native caption buttons.
config.window_decorations = 'RESIZE'
config.integrated_title_buttons = {}
-- Let WezTerm enable blur during window creation, before the appearance helper runs.
config.win32_system_backdrop = 'Acrylic'
-- Canopy-inspired dark tint over the native Windows Acrylic material.
config.window_background_opacity = 178 / 255
config.colors = { background = '#060c08' }

-- Alt+Q is an intentional close action in the tiling window manager.
config.window_close_confirmation = 'NeverPrompt'

-- One short-lived helper per new window/config reload; no background watcher.
wezterm.on('window-config-reloaded', function()
  wezterm.background_child_process {
    'powershell.exe', '-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden',
    '-ExecutionPolicy', 'RemoteSigned', '-File', wezterm.config_dir .. '/Appearance.ps1',
  }
end)
return config
