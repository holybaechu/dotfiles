# Set up a machine

Run bootstrap once, finish the prompts, then start the desktop and authenticate Git.

## Before running bootstrap

Requires Windows with WSL2 support, internet access, and [WinGet
1.11+](https://learn.microsoft.com/en-us/windows/package-manager/configuration/create-v3). Open
PowerShell as your regular user; setup requests elevation when needed and installs PowerShell 7,
chezmoi, and DSC as needed.

These are personal defaults. Bootstrap applies managed files automatically, disables Windows
Search indexing, window shadows, and mouse acceleration (Enhance pointer precision), hides
desktop icons, shows hidden files and extensions, enables taskbar auto-hide, and removes the
apps listed under [Windows removal guide](../system/windows/debloat.md). Review the [Windows
preferences](../system/windows/preferences.winget) and [removal
list](../system/windows/scripts/Debloat.ps1) first. For your own fork, also change the [Git
identity](../home/dot_config/git/config.tmpl) and [SSH public
key](../home/dot_config/git/github.pub).

## Run bootstrap

Run [bootstrap.ps1](../bootstrap.ps1) directly from the web, without saving a script file:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/holybaechu/dotfiles/main/bootstrap.ps1 -ErrorAction Stop))); exit $LASTEXITCODE'
```

Setup installs the Windows apps and Canopy, applies dotfiles, configures sign-in startup, and
provisions Arch Linux on WSL2 with Fish as the login shell. Arch becomes the default WSL
distribution. The default Linux user is `holybaechu`; add `-WslUser yourname` before `; exit` in
the command to change it, or `-Repository https://github.com/yourname/dotfiles.git` to use a
fork.

If setup requests a Windows restart, restart and rerun the same bootstrap command. Set the Linux
password when prompted.

## Start the desktop

Sign out and back in to start komorebi, whkd, AltSnap, and Canopy. To start them immediately,
open a new PowerShell 7 window and run:

```powershell
Set-Location (chezmoi execute-template '{{ .chezmoi.workingTree }}')
komorebic start --whkd
Start-Process "$env:APPDATA\AltSnap\AltSnap.exe" -WindowStyle Hidden
.\apps\yasb\Start.ps1
```

Use this launcher for Canopy; it loads the custom widget. Keep Everything running for file
search.

## Git authentication and signing

For Git authentication and signing, sign in to 1Password for Windows and enable **Settings →
Developer → Use the SSH Agent**. The configured public key must match a key in 1Password and be
registered on GitHub for both authentication and signing. WSL uses the Windows 1Password
integration.

Authenticate GitHub CLI once in each environment you use (Windows and WSL):

```sh
gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key
```

Continue with [Daily use](desktop.md) or [Neovim](neovim.md).
