# Software

| Purpose | Software |
| --- | --- |
| Window manager | [komorebi](https://github.com/LGUG2Z/komorebi) |
| Status bar & launcher | [Canopy](../apps/yasb/) / [YASB](https://github.com/amnweb/yasb) |
| Global keybindings | [whkd](https://github.com/LGUG2Z/whkd) |
| Mouse window movement & resizing | [AltSnap](https://github.com/RamonUnch/AltSnap) |
| Terminal | Windows Terminal |
| Text editor | Neovim (Windows and Arch WSL) |
| Archive manager | [Bandizip](https://www.bandisoft.com/bandizip/) (Windows) |
| Shells | PowerShell 7 (Windows), Fish (WSL), Bash (fallback) |
| Prompt | Starship |
| Terminal startup summary | Fastfetch |
| Linux environment | Arch Linux on WSL2 |
| File search | Everything |
| Browsers | [Aside](https://aside.com/) and [Helium](https://helium.computer/) |
| Media player | [PotPlayer](https://potplayer.daum.net/) |
| Git & GitHub | Git, GitHub CLI |
| SSH & commit signing | 1Password |
| YubiKey authentication | [Yubico Authenticator](https://www.yubico.com/products/yubico-authenticator/) |
| Fonts | JetBrainsMono Nerd Font Mono (terminal), Inter (bar) |
| Dotfile management | chezmoi |
| Windows provisioning | WinGet + DSC v3 |
| Linux provisioning | Ansible + pacman; yay for AUR packages |
| Python environment | uv |
| JavaScript runtime & package manager | Latest [Bun](https://bun.sh/) through mise (Windows and Arch WSL) |
| Node.js & npm | Latest Node.js LTS with bundled npm through [mise](https://mise.jdx.dev/) (Windows and Arch WSL) |

Package lists: [Windows](../system/windows/packages.winget) ·
[Arch](../system/wsl/provision.yml).

## JavaScript runtimes

Bootstrap and provisioning install mise through WinGet on Windows and pacman on Arch WSL. Mise
installs `bun@latest` and `node@lts` as global defaults, including Node's bundled npm, while
preserving other mise configuration. The Windows runtime resource runs as your regular user and
depends on the `Mise` package by its WinGet resource name. Bootstrap loads the mise environment
and verifies Bun, Node, and npm.

Managed PowerShell, Fish, and Bash hooks put mise's selected tools on PATH. Interactive shells
support project-specific `mise.toml` settings; non-interactive Fish and the Windows PowerShell
fallback load the environment without prompt hooks. Open a new terminal after provisioning. Use
`mise use -g bun@latest node@lts` to install the defaults manually and `mise upgrade bun node`
to update them later.

Mise replaces nvm and fnm. Chezmoi removes the retired Fish hooks and the managed Bass bridge;
Bash removes the old managed nvm/fnm blocks when it adds mise. Uninstall standalone Bun and any
installed nvm/fnm packages before switching, so a second runtime manager does not remain on
PATH. Old manager data and global npm packages are not automatically migrated or deleted.

## Browsers

Windows setup installs Helium through WinGet and Aside through its official signed Windows
installer (x64). Existing installations are retained on reruns. Both browsers install before the
debloat step removes Edge. Choose your default browser in **Settings → Apps → Default apps**;
setup leaves that choice to you.

See [Maintenance](maintenance.md) for updates and [Setup](setup.md) for installation.
