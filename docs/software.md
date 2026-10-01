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

Mise manages `bun@latest` and `node@lts`, including npm, on Windows and Arch WSL.
Shell hooks load its tools and project-specific `mise.toml` settings. Open a new
terminal after provisioning.

```sh
mise use -g bun@latest node@lts  # Install defaults manually
mise upgrade bun node          # Update
```

Before switching, uninstall standalone Bun and nvm/fnm packages. Their data and
global npm packages are not migrated or deleted automatically.

## Browsers

Setup installs Helium and Aside before removing Edge. Choose your default browser
in **Settings → Apps → Default apps**.
