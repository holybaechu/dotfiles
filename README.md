# Dotfiles

Chezmoi manages application configuration in `home/`. DSC manages Windows packages and preferences in `system/windows/`.

```text
bootstrap.ps1                 # Install chezmoi, provision Windows, apply dotfiles
home/                         # Chezmoi source state, selected by .chezmoiroot
system/windows/
  Configure.ps1               # Test or apply all modules, or select one
  packages.winget             # YAML: komorebi, whkd, and Zebar
  preferences.winget          # YAML: config directory, shadows, taskbar auto-hide
  startup.winget              # YAML: start komorebi, whkd, and Zebar at sign-in
  scripts/                   # Small Windows API helpers
```

## Windows

Requires WinGet 1.11+ and DSC v3. WinGet installs the DSC processor if missing. If the Store installation stalls, use the signed Windows MSIX bundle from the [official DSC releases](https://github.com/PowerShell/DSC/releases). Run as your regular Windows user; package installation requests elevation when needed.

From the repository:

```powershell
.\system\windows\Configure.ps1                         # Test all modules
.\system\windows\Configure.ps1 -Action Apply           # Apply all modules
.\system\windows\Configure.ps1 -Module preferences    # Test one module
.\system\windows\Configure.ps1 -Action Apply -Module preferences
```

The runner only loops over `.winget` files in filename order. Each module also works directly with `winget configure test -f <file>` or `winget configure -f <file>`. Add a module by creating another `.winget` YAML file; no registration is needed. Test exit code `1` means some settings are out of state.

Packages use `useLatest: false` to preserve installed versions. In `preferences.winget`, change `WindowShadows.properties.input.enabled` to `true` to restore Windows shadows. Apps that draw their own shadows may behave differently.

`preferences.winget` also enables Windows' built-in taskbar auto-hide. To turn it off, set `TaskbarAutoHide.properties.input.enabled` to `false` and run `Configure.ps1 -Action Apply -Module preferences`.

`startup.winget` creates two shortcuts in your Windows Startup folder: komorebi's native `enable-autostart --whkd` command creates one for komorebi and whkd, and DSC creates one for Zebar. Apply it separately with `Configure.ps1 -Action Apply -Module startup`. It takes effect at your next sign-in; applying the module does not launch or restart the apps. On a fresh setup, apply `packages` before `startup`; the full runner already uses that order.

Apply application configuration separately:

```powershell
chezmoi diff
chezmoi apply
komorebic reload-configuration
```

Reload whkd separately after editing its shortcuts. `chezmoi apply` does not run DSC. Keep chezmoi special files and hooks inside `home/`, and give each setting a single owner.

## Zebar

Zebar replaces komorebi-bar. The startup module launches the apps at sign-in. To start them manually:

```powershell
komorebic start --whkd
Start-Process zebar -WindowStyle Hidden
```

Omit `--bar` when starting komorebi. The komorebi package still includes the unused bar executable; chezmoi removes its old configuration.

The editable Komorebi starter lives in `home/dot_glzr/zebar/dotfiles/` and is applied to `~/.glzr/zebar/dotfiles/`. Edit `index.html` for content, `styles.css` for appearance, and `zpack.json` for placement. Its dock reserves space at the top of each monitor. No Node build step is required; the starter downloads its frontend dependencies on first load.

`home/dot_glzr/zebar/settings.json` selects this bar when Zebar starts; `startup.winget` handles Windows sign-in startup. After edits, run `chezmoi apply`, then reload the widget from Zebar's tray menu or restart Zebar. These files are ignored by chezmoi in WSL.

## Fresh setup

After committing and pushing this setup, download `bootstrap.ps1` and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

The bootstrap requires WinGet, uses chezmoi's built-in Git for the initial clone, then runs DSC and chezmoi. On an existing setup it uses the current checkout; use `chezmoi update` to pull remote changes. Open a new terminal for persistent environment changes.

Initialize the same repository with Linux chezmoi separately in WSL. Windows DSC runs on Windows; Linux provisioning is not defined yet.
