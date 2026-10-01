# Setup

Requires Windows with WSL2 support, internet access, and [WinGet 1.11+](https://learn.microsoft.com/en-us/windows/package-manager/configuration/create-v3).

Bootstrap installs the desktop tools and Arch WSL2, applies dotfiles, changes
[Windows preferences](../system/windows/preferences.winget), and [removes selected apps](../system/windows/debloat.md).
For a fork, change the [Git identity](../home/dot_config/git/config.tmpl) and
[SSH public key](../home/dot_config/git/github.pub) first.

## Bootstrap

Run in a normal PowerShell window. Setup installs PowerShell 7, chezmoi, and DSC,
and requests elevation when needed.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/holybaechu/dotfiles/main/bootstrap.ps1 -ErrorAction Stop))); exit $LASTEXITCODE'
```

Arch becomes the default WSL distribution, with Fish as the login shell.
The Linux user defaults to `holybaechu`. Before `; exit`, add `-WslUser yourname`
to change it, or `-Repository https://github.com/yourname/dotfiles.git` to use a fork.
Set the Linux password when prompted. If a restart is requested, restart and rerun bootstrap.

## Start the desktop

Sign out and back in, or run in a new PowerShell 7 window:

```powershell
Set-Location (chezmoi execute-template '{{ .chezmoi.workingTree }}')
komorebic start --whkd
Start-Process "$env:APPDATA\AltSnap\AltSnap.exe" -WindowStyle Hidden
.\apps\yasb\Start.ps1
```

Start Canopy with this launcher. Keep Everything running for file search.

## Git authentication

In 1Password for Windows, enable **Settings → Developer → Use the SSH Agent**.
The configured public key must match a key in 1Password and be registered on GitHub
for authentication and signing. WSL uses the Windows agent.

Authenticate GitHub CLI separately in Windows and WSL:

```sh
gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key
```
