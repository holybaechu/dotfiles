# Dotfiles

My Windows desktop and Arch Linux WSL2 setup, managed with [chezmoi](https://www.chezmoi.io/). Tiling windows, a keyboard-driven workflow, and Canopy: a custom status bar and launcher built on YASB.

## Software

| Purpose | Software |
| --- | --- |
| Window manager | [komorebi](https://github.com/LGUG2Z/komorebi) |
| Status bar & launcher | [Canopy](apps/yasb/) / [YASB](https://github.com/amnweb/yasb) |
| Global keybindings | [whkd](https://github.com/LGUG2Z/whkd) |
| Terminal | Windows Terminal |
| Text editor | Neovim (Windows and Arch WSL) |
| Archive manager | [Bandizip](https://www.bandisoft.com/bandizip/) (Windows) |
| Shells | PowerShell 7 (Windows), Fish (WSL), Bash (fallback) |
| Prompt | Starship |
| Terminal startup summary | Fastfetch |
| Linux environment | Arch Linux on WSL2 |
| File search | Everything |
| Git & GitHub | Git, GitHub CLI |
| SSH & commit signing | 1Password |
| Fonts | JetBrainsMono Nerd Font Mono (terminal), Inter (bar) |
| Dotfile management | chezmoi |
| Windows provisioning | WinGet + DSC v3 |
| Linux provisioning | Ansible + pacman; yay for AUR packages |
| Python environment | uv |

Package lists: [Windows](system/windows/packages.winget) · [Arch](system/wsl/provision.yml).

## Getting started

### Bootstrap

Requires Windows with WSL2 support, internet access, and [WinGet 1.11+](https://learn.microsoft.com/en-us/windows/package-manager/configuration/create-v3). Open PowerShell as your regular user; setup requests elevation when needed and installs PowerShell 7, chezmoi, and DSC as needed.

These are personal defaults. Bootstrap applies managed files automatically, disables Windows Search indexing, window shadows, and mouse acceleration (Enhance pointer precision), hides desktop icons, shows hidden files and extensions, and enables taskbar auto-hide. Review the [Windows preferences](system/windows/preferences.winget) first. For your own fork, also change the [Git identity](home/dot_config/git/config.tmpl) and [SSH public key](home/dot_config/git/github.pub).

Run [bootstrap.ps1](bootstrap.ps1) directly from the web, without saving a script file:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/holybaechu/dotfiles/main/bootstrap.ps1 -ErrorAction Stop))); exit $LASTEXITCODE'
```

Setup installs the Windows apps and Canopy, applies dotfiles, configures sign-in startup, and provisions Arch Linux on WSL2 with Fish as the login shell. Arch becomes the default WSL distribution. The default Linux user is `holybaechu`; add `-WslUser yourname` before `; exit` in the command to change it, or `-Repository https://github.com/yourname/dotfiles.git` to use a fork.

If setup requests a Windows restart, restart and rerun the same bootstrap command. Set the Linux password when prompted.

### First launch

Sign out and back in to start komorebi, whkd, and Canopy. To start them immediately, open a new PowerShell 7 window and run:

```powershell
Set-Location (chezmoi execute-template '{{ .chezmoi.workingTree }}')
komorebic start --whkd
.\apps\yasb\Start.ps1
```

Use this launcher for Canopy; it loads the custom widget. Keep Everything running for file search.

For Git authentication and signing, sign in to 1Password for Windows and enable **Settings → Developer → Use the SSH Agent**. The configured public key must match a key in 1Password and be registered on GitHub for both authentication and signing. WSL uses the Windows 1Password integration.

Authenticate GitHub CLI once in each environment you use (Windows and WSL):

```sh
gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key
```

## Keybindings

Global shortcuts are defined in [whkdrc](home/dot_config/whkdrc.tmpl). `H / J / K / L` means left / down / up / right; punctuation keys below use US keyboard labels.

### Apps

| Shortcut | Action |
| --- | --- |
| `Alt + Space` | Toggle Canopy launcher |
| `Alt + Enter` | Open Windows Terminal in the default WSL distribution |
| `Ctrl + Alt + Enter` | Open PowerShell 7 |
| `Ctrl + Alt + Shift + Enter` | Open PowerShell 7 as administrator |
| `Alt + E` | Open File Explorer |
| `Alt + B` | Open the default browser |

In the launcher, type an app name or `file report.pdf` to search files. Use `↑ / ↓` to select, `Enter` to open, `Esc` to dismiss, and `Ctrl + R` to refresh the app list.

Terminal opens separate windows in focus mode, with its title bar and tabs hidden. Tab shortcuts are disabled; copy, paste, and pane shortcuts remain available. Fish provides autosuggestions, syntax highlighting, and completions, with Starship as the prompt.

Fastfetch shows a compact summary with a small logo and OS, shell, uptime, and memory when a new interactive Fish, Bash, or PowerShell terminal starts. Windows and Arch provisioning install it automatically. Startup hooks skip redirected sessions, PowerShell script/command invocations, and non-interactive shells so automation and whkd stay quiet.

The shared [Starship configuration](home/dot_config/starship.toml) uses two lines: a shell label (`pwsh`, `fish`, or `bash`), folder, and Git details above a clean prompt arrow. Git markers show counts (`+` staged, `!` modified, `?` untracked, `↑` ahead, `↓` behind). Commands taking at least three seconds show their duration; failures show an exit code and turn the arrow red. Chezmoi renders the configuration to `~/.config/starship.toml` on each platform.

### Windows & workspaces

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

## Making changes

Configuration files use application-native formats: Lua for Neovim; YAML for YASB, GitHub CLI, Ansible, and WinGet (`.winget`); TOML for Starship and Python project settings; and JSON/JSONC for Komorebi, Windows Terminal, and Fastfetch. Git, SSH, systemd, whkd, shell scripts, and stylesheets retain their own native syntax. Chezmoi templates are used only where substitution or partial-file updates are needed.

Edit application settings in [home/](home/), then preview and apply them:

```sh
chezmoi diff
chezmoi apply
```

Press `Alt + O` after changing keybindings, or `Alt + Shift + O` after changing komorebi settings. Windows and WSL have separate chezmoi checkouts; update and apply changes in each environment.

Keep personal Fish settings in `~/.config/fish/config.fish`; chezmoi manages [conf.d/chezmoi.fish](home/dot_config/fish/conf.d/chezmoi.fish). For an existing Bash setup, install Fish with `sudo pacman -Syu --needed fish starship`, apply the updated dotfiles, then run `chsh -s /usr/bin/fish` and open a new terminal.

System setup is separate from `chezmoi apply`. From the repository root in PowerShell 7:

```powershell
.\system\windows\Configure.ps1                         # Check Windows configuration
.\system\windows\Configure.ps1 -Action Apply -Module preferences
.\system\wsl\Setup.ps1 -LinuxUser holybaechu            # Reprovision Arch, including a system upgrade
```

Use `-Module packages` or `-Module startup` to apply those Windows settings separately. Replace `holybaechu` with your Linux username if customized.

Setup installs WSL when needed and uses the existing version on configured machines. Update WSL separately with `wsl --update --web-download`; wait for any other Windows installations to finish first.

## Neovim

Neovim 0.12+ uses a personal Lua configuration and its built-in `vim.pack` plugin manager. The shared source is [home/dot_config/nvim/](home/dot_config/nvim/): `init.lua` loads editor settings from `lua/config/`, then `lua/plugins/init.lua` loads each feature explicitly. Plugin declarations and setup stay together in their feature modules.

Chezmoi deploys the shared Lua files to `~/.config/nvim` on both platforms. On Windows, a small entry point in `%LOCALAPPDATA%\nvim` loads those files, and a template copies the shared plugin lockfile into that native configuration directory. Each OS keeps its own installed plugins and tools in Neovim's data directory.

| Feature | Configuration |
| --- | --- |
| Theme | Canopy High Contrast, using Tokyo Night's syntax and plugin highlights |
| File search and browser | MiniPick and MiniFiles; ripgrep for project search |
| Completion | MiniCompletion, with native snippet support |
| Language support | Native LSP and nvim-lspconfig; Mason installs Lua Language Server |
| Formatting | Conform and StyLua, installed through Mason |
| Git | Gitsigns |

Bootstrap installs the editor and ripgrep on both platforms, curl and unzip on Arch, and Bandizip as the Windows archive app. Mason uses PowerShell to extract this starter's Windows Lua tool downloads; it does not call Bandizip directly. Open `nvim` with internet access on first launch: it installs the plugins recorded in `nvim-pack-lock.json`, then Mason installs Lua Language Server and StyLua. Check `:Mason` for installation progress. Lua is the initial supported language; add more servers in `lua/plugins/lsp.lua` and formatters in `lua/plugins/formatting.lua` as needed.

Space is the leader key. Formatting runs when requested, rather than automatically on save.

The `canopy` colorscheme uses Canopy's black background, forest-green surfaces, mint accents, and warm-white text. Comments and line numbers stay readable, while selections, search matches, completion menus, and diagnostics have explicit high-contrast colors. Its palette and overrides live in [colors/canopy.lua](home/dot_config/nvim/colors/canopy.lua); reload it with `:colorscheme canopy` after editing.

| Shortcut | Action |
| --- | --- |
| `Space ff` / `Space fg` | Find files / search project text |
| `Space fb` / `Space fh` | Find buffers / search help |
| `Space e` | Browse files; press `g?` for browser help |
| `Space w` | Save the current buffer |
| `Ctrl+h/j/k/l` | Move between split windows |
| `Ctrl+n` / `Ctrl+p` / `Ctrl+y` | Next completion / previous completion / accept |
| `gd` / `K` | Go to definition / show hover documentation |
| `Space cr` / `Space ca` / `Space cd` | Rename symbol / code action / line diagnostics |
| `Space cf` | Format the buffer or selected range |
| `]h` / `[h` | Next / previous Git hunk |
| `Space gp` / `Space gb` | Preview Git hunk / toggle line blame |

Use `:PackUpdate` to review plugin updates, then `:write` in the review buffer to apply them. Keep the generated lockfile in version control. Update it from WSL and capture it with `chezmoi re-add ~/.config/nvim/nvim-pack-lock.json`, then commit the source change. After applying that lockfile on another installation, use `:PackRestore` to review and synchronize existing plugins to its revisions. Mason's external tools are managed separately from the plugin lockfile.

Use `:checkhealth vim.pack`, `:checkhealth vim.lsp`, `:Mason`, and `:ConformInfo` to inspect the setup.
