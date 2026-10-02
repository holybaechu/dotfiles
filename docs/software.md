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
| Screen recording & streaming | [OBS Studio](https://obsproject.com/) (Windows) |
| Git & GitHub | Git, GitHub CLI |
| SSH & commit signing | 1Password |
| YubiKey authentication | [Yubico Authenticator](https://www.yubico.com/products/yubico-authenticator/) |
| Fonts | JetBrainsMono Nerd Font Mono (terminal), Inter (bar) |
| Dotfile management | chezmoi |
| Windows provisioning | WinGet + DSC v3 |
| Linux provisioning | Ansible + pacman; yay for AUR packages |
| Python environment | Latest uv through mise (Windows and Arch WSL) |
| JavaScript runtime & package manager | Latest [Bun](https://bun.sh/) through mise (Windows and Arch WSL) |
| Node.js & npm | Latest Node.js LTS with bundled npm through [mise](https://mise.jdx.dev/) (Windows and Arch WSL) |

Package lists: [Windows](../system/windows/packages.winget) ·
[Arch](../system/wsl/provision.yml).

## Runtimes and uv

Mise manages Bun, Node.js LTS (including npm), and uv on Windows and Arch WSL. Their versions
are declared in the [managed mise configuration](../home/dot_config/mise/modify_config.toml).
Bootstrap and Ansible apply it before installing the tools as your regular user.
The Windows `packages` module installs mise itself; bootstrap installs its managed tools.
Shell hooks load its tools and project-specific `mise.toml` settings. Open a new
terminal after provisioning.

```sh
chezmoi apply
mise install bun node uv  # Install configured defaults
mise upgrade bun node uv  # Update
```

Before switching, uninstall standalone Bun and nvm/fnm packages. Their data and
global npm packages are not migrated or deleted automatically.

Run mise commands from your home directory to avoid project overrides. For an existing
Windows installation, install the managed uv first, then remove the old copy with
`winget uninstall --id astral-sh.uv --exact`. Existing Python environments and uv's cache
are retained. Canopy uses `mise exec -- uv`, so shell activation is not required for setup.

## Browsers

Setup installs Helium and Aside before removing Edge. Choose your default browser
in **Settings → Apps → Default apps**.
