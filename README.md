# Dotfiles

Chezmoi manages application configuration in `home/`. DSC manages Windows packages and preferences in `system/windows/`. Ansible manages the Arch Linux environment in WSL.

```text
bootstrap.ps1                 # Provision Windows and Arch WSL2; apply chezmoi in both
home/                         # Chezmoi source state, selected by .chezmoiroot
apps/yasb/                    # Native PyQt6 Canopy widget, hosted by YASB
system/wsl/
  Setup.ps1                   # Install/update WSL2 and select the Arch user
  provision.sh                # Bootstrap Ansible and prompt for an initial password
  provision.yml               # Ansible: Arch packages, user, system configuration, chezmoi
  yay.yml                     # Build yay as the Linux user; install its package as root
system/windows/
  Configure.ps1               # Test or apply all modules, or select one
  packages.winget             # YAML: Windows Terminal, fonts, Starship, komorebi, whkd, Git, 1Password, Everything, GitHub CLI, uv
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

Alt+Enter opens Windows Terminal. Chezmoi adds a default `WSL` profile that runs `wsl.exe --cd ~` to open the default WSL distribution's shell in its Linux home directory. DSC installs Windows Terminal and JetBrainsMono Nerd Font Mono. Terminal uses the font at 12 pt with programming ligatures, the Canopy color scheme, a block cursor, and no scrollbar. Its dark green background (`#060c08`) uses 70% Acrylic opacity, including when unfocused, subject to Windows transparency and power settings.

Terminal opens new windows in focus mode, hiding both the title bar and tabs. Use komorebi to move, resize, minimize, and close windows. The default shortcuts for creating, duplicating, selecting, and switching tabs, plus the new-tab dropdown shortcut, are unbound. Ctrl+Shift+N still opens a separate window; copy/paste and pane shortcuts remain available. Terminal can still create tabs through explicit command-palette or command-line actions. Closing a window skips the close-all-tabs confirmation and terminates its programs; save and exit Neovim normally before closing its window.

| Shortcut | Action |
| --- | --- |
| Alt+Enter | Open the default WSL distribution in Windows Terminal |
| Ctrl+Alt+Enter | Open Windows PowerShell in Windows Terminal |
| Ctrl+Alt+Shift+Enter | Open elevated Windows PowerShell in Windows Terminal (UAC prompt) |
| Alt+Shift+Enter | Promote the focused komorebi window |

Each terminal shortcut requests a new window with `wt.exe -w new`; the PowerShell shortcuts select the built-in Windows PowerShell profile, and the elevated shortcut requests UAC elevation. Komorebi's existing Alt+Shift+Enter promote binding is preserved.

Bootstrap installs the official `archlinux` distribution on WSL2 and makes it the default. Check `wsl --list --verbose` to confirm. The terminal configuration follows WSL's default instead of hard-coding a distribution or Linux shell.

Chezmoi updates the stable Windows Terminal settings at `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` using a modify template. It preserves existing profiles, unrelated shortcuts and settings, themes, and color schemes while updating managed appearance defaults and tab shortcut overrides. JSONC comments and formatting are normalized to JSON. The configuration is ignored on Linux.

On an existing setup, install the packages and apply the configuration:

```powershell
.\system\windows\Configure.ps1 -Action Apply -Module packages
chezmoi apply --parent-dirs "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" ~/.config/whkdrc
```

Press Alt+O to reload whkd after changing shortcuts. Open a new Terminal window to use focus mode. If `wt.exe` is unavailable, enable Windows Terminal's app execution alias in Windows Settings and ensure `%LOCALAPPDATA%\Microsoft\WindowsApps` is on PATH.

### Starship

Windows DSC installs `Starship.Starship` through WinGet; Arch provisioning installs `starship` through pacman. Chezmoi enables the prompt in Arch's `~/.bashrc` and in the Windows PowerShell and PowerShell 7 console profiles under `~/Documents/WindowsPowerShell` and `~/Documents/PowerShell`. Modify templates maintain a marked Starship block while preserving the rest of each file. Initialization is skipped until the executable is available.

Starship uses its default appearance and any existing `~/.config/starship.toml` customization. Windows Terminal already uses a Nerd Font. The package names and shell initialization commands follow the [Starship guide](https://starship.rs/guide/).

On an existing Windows setup, run `system\windows\Configure.ps1 -Action Apply -Module packages`, then `chezmoi apply`. In Arch, rerun provisioning or run `sudo pacman -Syu --needed starship`, then `chezmoi apply` from the updated Linux checkout. Open a new terminal after installation to pick up PATH changes and the prompt.

### GitHub CLI

Bootstrap installs `GitHub.cli` on Windows and `github-cli` through pacman in Arch. Authenticate each native installation once with `gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key`. The CLI login authorizes GitHub API operations; Git authentication and commit signing use the SSH key in 1Password. The initial public bootstrap clone still uses HTTPS so it can run before 1Password is configured.

Chezmoi renders shared CLI defaults from `home/.chezmoitemplates/gh-config.yml` to `%APPDATA%\GitHub CLI\config.yml` on Windows and `~/.config/gh/config.yml` on Linux. Native CLI logins remain separate and their `hosts.yml` authentication files are excluded from chezmoi.

### Git signing and SSH with 1Password

Windows DSC installs 1Password and disables the Windows OpenSSH Authentication Agent service so 1Password can own the OpenSSH named pipe. Sign in to 1Password, turn on Settings > Developer > Use the SSH Agent, and keep the app running in the notification area. Account sign-in, vault unlock, and key-use approvals remain manual. Use 1Password 8.11.18 or later for the current Windows/WSL signer paths.

Chezmoi configures `~/.config/git/config` to sign commits and tags with SSH. The public key in `home/dot_config/git/github.pub` selects the matching private key in 1Password. That public key also supplies the local allowed-signers file and Windows SSH's GitHub identity selection. Register it on GitHub as both an Authentication key and a Signing key; a single key can serve both roles. Private keys and 1Password credentials are never stored in the dotfiles.

Windows uses `op-ssh-sign.exe` and Windows OpenSSH. Arch WSL uses the Windows `op-ssh-sign-wsl.exe` and `ssh.exe` through WSL interoperability; 1Password does not need to be installed inside Arch. The managed Bash hook aliases interactive `ssh` and `ssh-add` to their Windows executables. SSH host configuration for these commands lives in Windows `~/.ssh/config`. Native Linux programs that directly invoke Linux SSH do not automatically use this Windows bridge. Arch provisioning also keeps WSL's Windows-executable registration active when its `binfmt.d` directories are empty, so the Windows SSH and signer executables can launch.

1Password controls key authorization and how long approvals are remembered. The bootstrap no longer starts keychain or a separate SSH agent, and does not install standalone Windows GnuPG. Arch's preinstalled GnuPG remains an operating-system dependency of pacman/gpgme, not the Git signer.

Git reads machine-local `~/.gitconfig` after the shared config. Chezmoi creates it only when missing and preserves existing settings. When migrating from the previous OpenPGP setup, remove legacy `gpg.format`, `gpg.program`, and hexadecimal `user.signingkey` overrides from that local file after backing it up. Keep any intentional per-repository overrides separate. Existing GPG key files and historical GitHub public-key registrations are preserved.

See 1Password's [SSH setup](https://www.1password.dev/ssh/get-started), [Git signing](https://www.1password.dev/ssh/git-commit-signing), and [WSL integration](https://www.1password.dev/ssh/integrations/wsl) documentation.

## Canopy / YASB

Canopy is a native PyQt6 widget hosted by [YASB v2.0.7](https://github.com/amnweb/yasb/releases/tag/v2.0.7). The pinned upstream checkout stays unmodified in `apps/yasb/.upstream`; `launch.py` loads the custom widget from `canopy/`. Start through this launcher, because a stock YASB executable cannot import the custom widget.

The bar uses Inter, Lucide icons, the Simple Icons Windows 10 logo, Tailwind Neutral surfaces, and Catppuccin Mocha Green on pure black. Three sections reserve 40 logical pixels, with 4px logical edge insets and transparent gaps. Qt applies each monitor's native Windows scaling to all design dimensions: the bar is 40 physical pixels at 100%, 50 at 125%, 60 at 150%, and 80 at 200%. Windows receives physical monitor coordinates when reserving bar space. Media, brightness/volume, calendar, and tray panels expand as separate native windows with animated squircle corners, blur/fade transitions, shadows, and outside-click dismissal.

Click the Windows-logo button or press Alt+Space to open Canopy's centered app launcher on the active display. Search apps and Control Panel items together, or prefix the query with `file ` (for example, `file report.pdf`) to search files. whkd owns the shortcut in `~/.config/whkdrc`; chezmoi renders the repository path from `home/dot_config/whkdrc.tmpl`. `ToggleLauncher.ps1` sends the command directly from whkd's persistent PowerShell session, with bounded waits so an unavailable bar cannot hold up other shortcuts. Reload whkd after changing its bindings.

Canopy builds its application list at startup and refreshes it in the background every minute and whenever the launcher opens. Cached items remain searchable and launchable during refresh; the open list updates silently while preserving your selection and scroll position. Press Ctrl+R to request a background refresh. Bootstrap installs Everything through `packages.winget`; Everything must be running for file searches.

The launcher uses a compact 480 × 420 logical-pixel panel (960 × 840 physical pixels at 200% scaling) with its scrollbar at the right edge. Its frosted backdrop is captured and blurred in memory when opened, preserving the rounded corners and shadow while keeping text sharp. Search results stay visible until the next query finishes.

Quick controls include Wi-Fi, Bluetooth, Airplane mode, and Energy saver. The footer shows a battery icon beside its percentage and a power button with Lock, Sign out, Sleep, Hibernate, Restart, and Shut down actions. Power actions are disabled in the preview. Click a card to toggle its mode; click its separate arrow to open Windows Settings. Cards turn green only after Windows confirms the change, and show pending or failure feedback when necessary. Energy saver reads Windows 11's current saver status, including standard savings while plugged in. Airplane mode and Energy saver use private Windows interfaces for toggling, with system-state readback to catch unsupported behavior.

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

The small shell bootstrap initializes the signing keyring and installs Arch's `ansible` package, including Python and the `community.general` collection, if it is missing. Ansible then runs locally as root inside Arch; no SSH server is needed. Its playbook refreshes signing keys, performs a full system upgrade, installs official packages through pacman, creates or updates the Linux account with Bash and wheel membership, validates password-required sudo access, and maintains the WSL interop service override. The override reloads systemd and restarts the service only when its contents change.

Ansible also installs [yay from its AUR source package](https://github.com/Jguer/yay#installation) when `/usr/bin/yay` is missing. It installs Go for the build, runs Git and makepkg as the Linux user in a temporary directory, then installs the resulting package as root and removes the build directory even on failure. This avoids sudo prompts during package builds. Yay remains available for AUR use; provisioning uses pacman for official packages and system upgrades. It does not update existing AUR packages. The [Ansible pacman module](https://docs.ansible.com/projects/ansible/latest/collections/community/general/pacman_module.html) documents incompatibilities with yay, so the playbook does not use yay as its package backend.

The default Linux account is `holybaechu`; override it with `-WslUser <name>` on `bootstrap.ps1` or `-LinuxUser <name>` on `system/wsl/Setup.ps1`. After Ansible finishes, the shell bootstrap prompts for a password only if the account has no usable password. Existing passwords are retained. Arch becomes the default WSL distribution and the account becomes its default user.

Ansible initializes Linux chezmoi from the same `-Repository` URL into its own Linux home and applies pending dotfile changes as the Linux user, including the shared Git and GitHub CLI defaults. Existing source checkouts are reused without pulling or discarding local edits. It also adds the managed shell hook to `.bashrc` without replacing existing shell configuration. Windows-only files are excluded by `.chezmoiignore.tmpl`. Windows DSC stays on Windows, and `chezmoi apply` does not invoke Ansible.

Routine package and configuration confirmations are accepted automatically, including makepkg confirmations and chezmoi overwriting managed targets. Windows UAC and initial Linux password setup still require input. On an existing setup, pull remote changes before rerunning bootstrap. To rerun only Arch provisioning, use `system\wsl\Setup.ps1 -LinuxUser holybaechu`. Open a new terminal for persistent environment changes.

Once Ansible is installed, preview or apply Linux provisioning directly from the Linux checkout:

```bash
cd ~/.local/share/chezmoi
sudo env LC_ALL=C.UTF-8 ansible-playbook -i localhost, system/wsl/provision.yml --check --diff
sudo env LC_ALL=C.UTF-8 ansible-playbook -i localhost, system/wsl/provision.yml
```

Pass `-e linux_user=<name>` and `-e repository=<url>` for overrides. Check mode previews supported system changes; it skips building yay, applying dotfiles, and commands that depend on a new account or checkout. It does not install Ansible or set an initial password; use `Setup.ps1` for first-time setup. Each apply includes an Arch system upgrade, so treat this as an explicit maintenance command separate from routine `chezmoi apply`.
