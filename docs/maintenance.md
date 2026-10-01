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
- Bun and Node: `mise upgrade bun node`.
- Neovim: follow the [lockfile workflow](neovim.md#update-plugins-and-language-tools).
