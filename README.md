# Dotfiles

Chezmoi manages application configuration in `home/`. DSC manages Windows packages and preferences in `system/windows/`.

```text
bootstrap.ps1                 # Provision Windows and Arch WSL2; apply chezmoi in both
home/                         # Chezmoi source state, selected by .chezmoiroot
apps/yasb/                    # Native PyQt6 Canopy widget, hosted by YASB
system/wsl/                   # Install official Arch WSL2, user, packages, and chezmoi
system/windows/
  Configure.ps1               # Test or apply all modules, or select one
  packages.winget             # YAML: WezTerm, komorebi, whkd, Git, uv
  preferences.winget          # YAML: config directory, shadows, taskbar auto-hide
  startup.winget              # YAML: start komorebi, whkd, and Canopy at sign-in
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

The runner only loops over `.winget` files in filename order. It accepts configuration agreements and disables interactive WinGet prompts. Each module also works directly with `winget configure test -f <file>` or `winget configure -f <file>`. Add a module by creating another `.winget` YAML file; no registration is needed. Test exit code `1` means some settings are out of state.

Packages use `useLatest: false` to preserve installed versions. In `preferences.winget`, change `WindowShadows.properties.input.enabled` to `true` to restore Windows shadows. Apps that draw their own shadows may behave differently.

`preferences.winget` also enables Windows' built-in taskbar auto-hide. To turn it off, set `TaskbarAutoHide.properties.input.enabled` to `false` and run `Configure.ps1 -Action Apply -Module preferences`.

The `ExplorerPreferences` resource hides desktop icons, shows hidden files and folders, and shows file extensions. Its three input switches can be changed independently. The helper updates Windows Shell settings and notifies Explorer without restarting it.

`startup.winget` creates two Windows Startup shortcuts: komorebi's native `enable-autostart --whkd` command creates one for komorebi and whkd; DSC creates `Canopy.lnk` for the native bar and removes the old Zebar shortcut. Apply it separately with `Configure.ps1 -Action Apply -Module startup`. Applying startup does not launch or restart apps. On a fresh setup, apply `packages` and run `apps\yasb\Setup.ps1` before applying startup.

Apply application configuration separately:

```powershell
chezmoi diff
chezmoi apply
komorebic reload-configuration
```

Reload whkd separately after editing its shortcuts. `chezmoi apply` does not run DSC. Keep chezmoi special files and hooks inside `home/`, and give each setting a single owner.

### Terminal

Alt+Enter opens WezTerm. Chezmoi manages its Windows configuration at `~/.config/wezterm/wezterm.lua` and ignores it on Linux. WezTerm runs `wsl.exe --cd ~` to open the default WSL distribution's shell in its Linux home directory. It uses the bundled JetBrains Mono font with programming ligatures enabled and shows the tab bar only when there is more than one tab.

The window has no title bar or window-control buttons. It keeps the native resize frame for komorebi management and Windows rounded corners; use komorebi to move, resize, minimize, and close it. WezTerm applies native Windows Acrylic blur as the window opens. A short-lived Windows appearance helper removes native caption buttons and preserves rounded corners without changing the blur. Windows controls Acrylic's unfocused appearance. The background uses Canopy's dark launcher tint (`#060c08` at `178 / 255` opacity). Windows controls the blur radius, so it is not identical to Canopy's custom Gaussian blur. Closing a window, including with Alt+Q, skips WezTerm's confirmation dialog and terminates the programs inside; save and exit Neovim normally before closing its window.

| Shortcut | Action |
| --- | --- |
| Alt+Enter | Open the default WSL distribution in WezTerm |
| Ctrl+Alt+Enter | Open Windows PowerShell in WezTerm |
| Ctrl+Alt+Shift+Enter | Open elevated Windows PowerShell in WezTerm (UAC prompt) |
| Alt+Shift+Enter | Promote the focused komorebi window |

The PowerShell shortcuts run `powershell.exe` in a separate WezTerm process so the elevated shortcut cannot reuse an unelevated terminal process. Komorebi's existing Alt+Shift+Enter promote binding is preserved.

Bootstrap installs the official `archlinux` distribution on WSL2 and makes it the default. Check `wsl --list --verbose` to confirm. The terminal configuration follows WSL's default instead of hard-coding a distribution or Linux shell.

On an existing setup, install the package and apply the configuration:

```powershell
.\system\windows\Configure.ps1 -Action Apply -Module packages
chezmoi apply ~/.config/wezterm/wezterm.lua ~/.config/whkdrc
```

Restart whkd after installation so it picks up WezTerm's PATH entry and the new shortcut. Sign out and back in if the current desktop session still has the old PATH.

WezTerm does not yet support Windows' system-wide **Default terminal application** setting ([upstream issue](https://github.com/wezterm/wezterm/issues/7534)). This setup launches it through Alt+Enter or its Start menu entry.

## Canopy / YASB

Canopy is a native PyQt6 widget hosted by [YASB v2.0.7](https://github.com/amnweb/yasb/releases/tag/v2.0.7). The pinned upstream checkout stays unmodified in `apps/yasb/.upstream`; `launch.py` loads the custom widget from `canopy/`. Start through this launcher, because a stock YASB executable cannot import the custom widget.

The bar uses Inter, Lucide icons, the Simple Icons Windows 10 logo, Tailwind Neutral surfaces, and Catppuccin Mocha Green on pure black. Three sections reserve 40 logical pixels, with 4px logical edge insets and transparent gaps. Qt applies each monitor's native Windows scaling to all design dimensions: the bar is 40 physical pixels at 100%, 50 at 125%, 60 at 150%, and 80 at 200%. Windows receives physical monitor coordinates when reserving bar space. Media, brightness/volume, calendar, and tray panels expand as separate native windows with animated squircle corners, blur/fade transitions, shadows, and outside-click dismissal.

Click the Windows-logo button or press Alt+Space to open Canopy's centered app launcher on the active display. Search apps and Control Panel items together, or prefix the query with `file ` (for example, `file report.pdf`) to search files. whkd owns the shortcut in `~/.config/whkdrc`; chezmoi renders the repository path from `home/dot_config/whkdrc.tmpl`. `ToggleLauncher.ps1` sends the command directly from whkd's persistent PowerShell session, with bounded waits so an unavailable bar cannot hold up other shortcuts. Reload whkd after changing its bindings.

The launcher uses a compact 480 × 420 logical-pixel panel (960 × 840 physical pixels at 200% scaling) with its scrollbar at the right edge. Its frosted backdrop is captured and blurred in memory when opened, preserving the rounded corners and shadow while keeping text sharp. Search results stay visible until the next query finishes.

Quick controls include Wi-Fi, Bluetooth, Airplane mode, and Energy saver. Click a card to toggle its mode; click its separate arrow to open Windows Settings. Cards turn green only after Windows confirms the change, and show pending or failure feedback when necessary. Energy saver reads Windows 11's current saver status, including standard savings while plugged in. Airplane mode and Energy saver use private Windows interfaces for toggling, with system-state readback to catch unsupported behavior.

YASB services provide Komorebi events, Windows media artwork and playback, audio, battery, network status, brightness, and tray callbacks. Playback time is interpolated between Windows timeline updates. Brightness controls identify each connected display independently; external displays need DDC/CI support. Unsupported or ambiguous mirrored displays stay read-only.

Every monitor shows workspace slots 1–8 immediately, matching whkd's shortcuts, even before Komorebi creates those workspaces on a newly connected display. Workspace clicks resolve the bar's native monitor identity against the current Komorebi state, including after monitors are reordered or reconnected.

Install the runtime and apply the managed configuration:

```powershell
.\system\windows\Configure.ps1 -Action Apply -Module packages
# Open a new terminal if Git or uv was just installed.
.\apps\yasb\Setup.ps1
chezmoi apply --recursive ~/.config/yasb
.\system\windows\Configure.ps1 -Action Apply -Module startup
```

Start the bar from your normal PowerShell terminal:

```powershell
.\apps\yasb\Start.ps1
```

Komorebi and whkd must already be running (`komorebic start --whkd` starts them). Omit `--bar`. Use YASB's tray menu to restart after Python changes, or run `.\apps\yasb\.venv\Scripts\python.exe apps/yasb/launch.py --reload`. Its config and stylesheet reload automatically. Diagnostics go to `~/.config/yasb/yasb.log`. The managed `.env` selects FreeType for smooth Inter rendering at the monitor's native scaling.

For development, the preview uses the real native controls with fixture data and does not change Windows settings:

```powershell
.\apps\yasb\Setup.ps1 -Dev
.\apps\yasb\Start.ps1 -Preview
.\apps\yasb\.venv\Scripts\python.exe -m pytest apps/yasb/tests -q
.\apps\yasb\.venv\Scripts\python.exe apps/yasb/launch.py --snapshot apps/yasb/.artifacts/quick.png --panel quick --displays 2
.\apps\yasb\.venv\Scripts\python.exe apps/yasb/launch.py --snapshot apps/yasb/.artifacts/launcher.png --panel launcher
```

Use the preview to check styling, spacing, and animations; snapshots capture a static view. The small regression suite checks launcher reliability, monitor targeting, Windows-setting failures, hotkey timeouts, and startup/shutdown. Windows-setting tests use fakes; verify real setting changes manually when changing their implementation.

`upstream.json` pins YASB; `uv.lock` pins Python dependencies. To update YASB, intentionally update its checkout and pin together, regenerate the lockfile, and rerun the native tests. Bootstrap and sign-in startup use Canopy. The Windows bar configuration is ignored by chezmoi in WSL.

## Fresh setup

After committing and pushing this setup, download `bootstrap.ps1` and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

The bootstrap uses chezmoi's built-in Git for the initial clone, installs Windows packages, prepares Canopy with uv, applies dotfiles, and configures preferences and startup. Python 3.14 is managed by uv. It then installs or updates WSL, installs the [official Arch Linux image](https://archlinux.org/download/), and selects WSL2. An existing `archlinux` installation is reused. Setup checks Windows' pending component restart state before and after WSL commands, because enabling Virtual Machine Platform can return success while still requiring a reboot. It stops with exit code `3010` and restart instructions; bootstrap does not reboot automatically.

After restarting, rerun bootstrap or resume only the remaining Arch setup from your normal PowerShell (pass the same `-LinuxUser` and `-Repository` overrides if you used them):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.local\share\chezmoi\system\wsl\Setup.ps1"
```

Arch setup creates the `holybaechu` Linux account with Bash and installs [yay from its AUR source package](https://github.com/Jguer/yay#installation) before the application packages. Pacman is used only for the initial signing-key refresh and the Git, `base-devel`, and sudo prerequisites when yay is missing. Yay is built and run as the Linux user, then handles signing-key updates, system upgrades, and package installation, including chezmoi. Reruns reuse yay and skip the pacman bootstrap. Override the account name with `-WslUser <name>`. Initial account setup asks for a Linux password; existing passwords are retained, and sudo may ask for that password during package installation. Arch becomes the default WSL distribution and the account becomes its default user.

Linux chezmoi initializes the same `-Repository` URL into its own Linux home and applies it as the Linux user. Existing source checkouts are reused without pulling or discarding local edits. Windows-only files are excluded by `.chezmoiignore.tmpl`; this repository currently has no Linux application dotfiles, so the Linux apply prepares chezmoi for future additions. Windows DSC stays on Windows.

Routine package and configuration confirmations are accepted automatically, including makepkg/yay confirmations and chezmoi overwriting managed targets. Windows UAC, initial Linux password setup, and sudo authentication still require input. On an existing setup, pull remote changes before rerunning bootstrap. To rerun only Arch provisioning, use `system\wsl\Setup.ps1 -LinuxUser holybaechu`. Open a new terminal for persistent environment changes.
