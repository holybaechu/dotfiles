# Maintain the setup

Edit files in their application-native formats. Chezmoi templates are used where substitution or
partial-file updates are needed. Windows and WSL have separate checkouts; update and apply each
environment.

## Edit and apply dotfiles

Edit application settings in [home/](../home/), then preview and apply them:

```sh
chezmoi diff
chezmoi apply
```

## Reload desktop tools

| Changed configuration | Reload |
| --- | --- |
| whkd keybindings | `Alt + O` |
| komorebi | `Alt + Shift + O` |
| AltSnap | Run `& "$env:APPDATA\AltSnap\AltSnap.exe" -r` in PowerShell |

## Shell configuration

Keep personal Fish settings in `~/.config/fish/config.fish`; chezmoi manages
[conf.d/chezmoi.fish](../home/dot_config/fish/conf.d/chezmoi.fish). For an existing Bash setup,
install Fish with `sudo pacman -Syu --needed fish starship`, apply the updated dotfiles, then
run `chsh -s /usr/bin/fish` and open a new terminal.

## Reapply system setup

System setup is separate from `chezmoi apply`. From the repository root in PowerShell 7:

```powershell
.\system\windows\Configure.ps1                         # Check Windows configuration
.\system\windows\Configure.ps1 -Action Apply -Module preferences
.\system\wsl\Setup.ps1 -LinuxUser holybaechu            # Reprovision Arch, including a system upgrade
```

Use `-Module packages` or `-Module startup` to apply those Windows settings separately. Replace
`holybaechu` with your Linux username if customized.

## Update WSL

Setup installs WSL when needed and uses the existing version on configured machines. Update WSL
separately with `wsl --update --web-download`; wait for any other Windows installations to
finish first.

## Update JavaScript runtimes

Run `mise upgrade bun node` to update the managed runtimes. See
[Software](software.md#javascript-runtimes) for environment hooks and migration from older
runtime managers.

## Update Neovim

See [plugin and language-tool updates](neovim.md#update-plugins-and-language-tools) for the
lockfile workflow shared between Windows and WSL.
