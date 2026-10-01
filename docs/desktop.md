# Daily use

Global shortcuts are defined in [whkdrc](../home/dot_config/whkdrc.tmpl). `H / J / K / L` means
left / down / up / right; punctuation keys below use US keyboard labels.

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

## Terminal and shell

Terminal opens separate windows in focus mode, with its title bar and tabs hidden. Tab shortcuts
are disabled; copy, paste, and pane shortcuts remain available. Fish provides autosuggestions,
syntax highlighting, and completions, with Starship as the prompt.

### Startup summary

Fastfetch shows a compact summary with a small logo and OS, shell, uptime, and memory when a new
interactive Fish, Bash, or PowerShell terminal starts. Windows and Arch provisioning install it
automatically. Startup hooks skip redirected sessions, PowerShell script/command invocations,
and non-interactive shells so automation and whkd stay quiet.

On Windows, the WSL memory row is queried only when Arch is already running. A
stopped/unavailable distro or failed/timed-out query produces no WSL text or label and does not
start Arch just for the display.

### Prompt

The shared [Starship configuration](../home/dot_config/starship.toml) uses two lines: a shell
label (`pwsh`, `fish`, or `bash`), folder, and Git details above a clean prompt arrow. Git
markers show counts (`+` staged, `!` modified, `?` untracked, `↑` ahead, `↓` behind). Commands
taking at least three seconds show their duration; failures show an exit code and turn the arrow
red. Chezmoi renders the configuration to `~/.config/starship.toml` on each platform.

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

AltSnap handles the mouse gestures using [its managed
settings](../home/AppData/Roaming/AltSnap/AltSnap.ini). Its own snapping is disabled, and
move/resize notifications let komorebi update the tiled layout. Komorebi animations are disabled
for smooth mouse resizing. Use `Alt + T` for free movement of a floating window.

Editor shortcuts are in [Neovim](neovim.md). Reload commands are in
[Maintenance](maintenance.md).
