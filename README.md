# Dotfiles

My Windows desktop and Arch Linux WSL2 configuration, managed with
[chezmoi](https://www.chezmoi.io/). The desktop uses komorebi for tiling, whkd for shortcuts,
and Canopy, a custom YASB bar and launcher.

## Start here

These are personal defaults. Bootstrap applies dotfiles, changes Windows preferences, removes
selected apps (including Edge and OneDrive), and provisions Arch WSL2. Review the [setup
guide](docs/setup.md) and [Windows removal details](system/windows/debloat.md) before running
it. For a fork, update the Git identity and SSH public key first.

On Windows with WSL2 support, internet access, and WinGet 1.11+, open a normal PowerShell window
and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/holybaechu/dotfiles/main/bootstrap.ps1 -ErrorAction Stop))); exit $LASTEXITCODE'
```

Setup requests elevation when needed. If it requests a restart, restart and rerun the command.
Sign out and back in after setup to start the desktop tools.

## Guides

| I want to… | Read |
| --- | --- |
| Set up a machine or fork | [Setup](docs/setup.md) |
| Use the launcher and desktop shortcuts | [Daily use](docs/desktop.md) |
| Use and configure the editor | [Neovim](docs/neovim.md) |
| Change dotfiles or update tools | [Maintenance](docs/maintenance.md) |
| See the software and runtime setup | [Software](docs/software.md) |
| Check Windows settings or recover changes | [Windows setup and recovery](system/windows/README.md) |

## Repository layout

- [home/](home/) — application configuration deployed by chezmoi.
- [apps/yasb/](apps/yasb/) — Canopy's launcher, widgets, and styling.
- [system/windows/](system/windows/) — Windows packages, preferences, and startup.
- [system/wsl/](system/wsl/) — Arch WSL provisioning.
- [docs/](docs/) — usage and maintenance guides.

`chezmoi apply` deploys application configuration. System provisioning runs separately; see
[Maintenance](docs/maintenance.md).
