# Desktop shortcuts

Defined in [whkdrc](../home/dot_config/whkdrc.tmpl).
`H / J / K / L` means left / down / up / right. Punctuation uses US keyboard labels.

## Apps and launcher

| Shortcut | Action |
| --- | --- |
| `Alt + Space` | Toggle Canopy launcher |
| `Alt + Enter` | Open Windows Terminal in the default WSL distribution |
| `Ctrl + Alt + Enter` | Open PowerShell 7 |
| `Ctrl + Alt + Shift + Enter` | Open PowerShell 7 as administrator |
| `Alt + E` | Open File Explorer |
| `Alt + B` | Open the default browser |

In the launcher, type an app name or `file report.pdf` to search files. Use `↑ / ↓` to select,
`Enter` to open, `Esc` to dismiss, and `Ctrl + R` to refresh the app list.

## Windows and workspaces

| Shortcut | Action |
| --- | --- |
| `Alt + H / J / K / L` | Focus a window in that direction |
| `Alt + Shift + H / J / K / L` | Move a window in that direction |
| `Alt + Shift + [ / ]` | Focus the previous / next window |
| `Alt + Shift + Enter` | Promote the focused window to the main position |
| `Alt + Q` | Close the focused window |
| `Alt + M` | Minimize the focused window |
| `Alt + Arrow keys` | Stack the focused window in that direction |
| `Alt + ;` | Unstack the focused window |
| `Alt + [ / ]` | Select the previous / next window in a stack |
| `Alt + = / -` | Increase / decrease window width |
| `Alt + Shift + = / -` | Increase / decrease window height |
| `Alt + left mouse drag` | Move the window under the pointer |
| `Alt + right mouse drag` | Resize from the nearest side or corner |
| `Alt + T` | Toggle floating |
| `Alt + Shift + F` | Toggle monocle (one window fills the workspace) |
| `Alt + 1–8` | Switch workspace |
| `Alt + Shift + 1–8` | Move the focused window to a workspace |
| `Alt + X / Y` | Flip the layout horizontally / vertically |
| `Alt + Shift + R` | Retile windows |
| `Alt + P` | Pause / resume window management |
| `Alt + I` | Show / hide the komorebi shortcut helper |
| `Alt + O` | Reload whkd keybindings |
| `Alt + Shift + O` | Reload komorebi configuration |

Use `Alt + T` for free movement of a floating window.

## Terminal

Windows Terminal hides tabs and the title bar; tab shortcuts are disabled.
Fastfetch shows a startup summary. Its WSL memory display only queries a running Arch instance.

[Starship](../home/dot_config/starship.toml) shows the shell, folder, and Git status.
Git counts: `+` staged, `!` modified, `?` untracked, `↑` ahead, `↓` behind.
Failures turn the prompt red; commands lasting three seconds show their duration.

## Colors

Canopy uses the wallpaper's bright window green for desktop accents and lighter shades for code.
YASB's bar background is pure black. Windows Terminal keeps acrylic blur at 88% opacity
with a near-black olive tint; Neovim inherits that canvas and uses solid popups.

| Role | Color |
| --- | --- |
| Primary accent | `#7CAB3D` |
| Coding background / selection | `#11160F` / `#3C502B` |
| Text / comments | `#F0F3E7` / `#AAB69E` |
| Strings / success | `#BFDC96` |
| Numbers / warnings | `#EBC98A` |
| Functions / information | `#AECDDD` |
| Types / escapes | `#9BD1BD` |
| Keywords | `#CFB9DD` |
| Errors / deletions | `#EEA99A` |

Keep palette edits aligned in [Canopy](../apps/yasb/canopy/theme.py),
[Neovim](../home/dot_config/nvim/colors/canopy.lua),
[Windows Terminal](../home/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/modify_settings.json),
[Starship](../home/dot_config/starship.toml),
[PowerShell](../home/.chezmoitemplates/powershell-profile.ps1),
[Fish](../home/dot_config/fish/conf.d/chezmoi.fish),
[Fastfetch](../home/dot_config/fastfetch/config.jsonc.tmpl), and
[komorebi](../home/dot_config/komorebi/komorebi.json).
Apply with `chezmoi apply`, reopen shells, reload Neovim with `:colorscheme canopy`,
and restart Canopy to load its Python palette. Windows accent setup is in
[Windows appearance](../system/windows/preferences.md#appearance).
