# Maintenance

## Dotfiles

Edit [home/](../home/), then preview and apply:

```sh
chezmoi diff
chezmoi apply
```

Windows and WSL have separate checkouts. Update and apply both.

| Tool | Reload |
| --- | --- |
| whkd | `Alt + O` |
| komorebi | `Alt + Shift + O` |
| AltSnap | Run `& "$env:APPDATA\AltSnap\AltSnap.exe" -r` in PowerShell |

Keep personal Fish settings in `~/.config/fish/config.fish`;
chezmoi manages [conf.d/chezmoi.fish](../home/dot_config/fish/conf.d/chezmoi.fish).
To migrate an existing Bash setup, install Fish with `sudo pacman -Syu --needed fish starship`,
apply dotfiles, then run `chsh -s /usr/bin/fish` and open a new terminal.

## System setup

Run from the repository root in PowerShell 7:

```powershell
.\system\windows\Configure.ps1                         # Check Windows configuration
.\system\windows\Configure.ps1 -Action Apply -Module preferences
.\system\wsl\Setup.ps1 -LinuxUser holybaechu            # Reprovision Arch, including a system upgrade
```

Use `-Module packages` or `-Module startup` to apply those modules separately.
Replace `holybaechu` if you chose another Linux username.

## Updates

- WSL: `wsl --update --web-download`. Wait for other Windows installations to finish first.
- Bun, Node, and uv: from your home directory, run `mise upgrade bun node uv`.
  See [runtime setup and migration](software.md#runtimes-and-uv).
- Neovim: follow the [lockfile workflow](neovim.md#update-plugins-and-language-tools).

## Configuration ownership

| Responsibility | Location |
| --- | --- |
| Installation order and failure guidance | [bootstrap.ps1](../bootstrap.ps1) |
| Application settings and runtime version policy | [home/](../home/) |
| Windows packages, privileges, and setting checks | [Windows setup](../system/windows/README.md) |
| Arch packages, accounts, interop, and yay | [WSL provisioning](../system/wsl/README.md) |
| Canopy runtime and upstream integration | [Canopy](../apps/yasb/README.md) |

`.chezmoiroot` limits chezmoi to `home/`; the ignore template selects OS-specific targets.
Shared templates and Windows Neovim's entry file keep common configuration in one place.
`chezmoi apply` deploys application settings; system provisioning remains separate.

The OS package manager installs mise. Chezmoi owns its tool selection, and bootstrap or
Ansible installs those tools after applying dotfiles. Change the [mise defaults](../home/dot_config/mise/modify_config.toml),
apply in both environments, then run `mise install bun node uv` from your home directory.

Windows DSC keeps user/machine privileges and rollback journals with their setting helpers.
WSL retains Ansible for declarative maintenance and yay for optional AUR use.
