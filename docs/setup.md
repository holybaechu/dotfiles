# Setup

Use a normal Linux user account with internet access. The desktop requires
Hyprland 0.56+ (Lua configuration) and Quickshell 0.3.2+; Neovim requires 0.12+.
See [Software](software.md) for applications and package lists. Other Wayland
compositors need their own desktop configuration.

## System setup

On Arch or a derivative, install `git`, `ansible-core`, `curl`, and `yay`, then run
from the checkout as your normal user in a graphical session:

```sh
cd ~/.local/share/chezmoi
./bootstrap.sh
```

Bootstrap installs the required Ansible collections and runs the
[local playbook](../system/linux/playbook.yml), asking for your Linux password
for privileged tasks. It configures the signed [Cider repository](https://repo.cider.sh/),
upgrades the system, installs the package lists and patched Egis fingerprint
driver, enables desktop services, installs SDDM's theme and monitors, configures
fingerprint authentication, and registers this checkout with chezmoi.
Fingerprint enrollment and applying home files remain manual.

AUR packages and the fingerprint driver build as your normal user. During those
tasks, Ansible grants that user passwordless access to pacman through
`/etc/sudoers.d/dotfiles-build`, then removes the rule when the build block finishes.
The playbook manages system files directly, without creating backup copies.

Preview supported changes with `./bootstrap.sh --check --diff`. Package builds
and commands that change system state are skipped in check mode. To rerun one
part, use `./bootstrap.sh --tags packages`, `services`, `sddm`, `fingerprint`, or
`dotfiles`; the packages tag includes the fingerprint driver build. The `power`
and `brightness` tags select those service settings alone.

On another distribution, install the equivalent packages from the
[Arch list](../system/linux/packages.arch) and [AUR list](../system/linux/packages.aur),
including Fisher, the required fonts, 1Password's desktop application, and Helium.
Then register the checkout:

```sh
chezmoi init --source ~/.local/share/chezmoi
```

## Review and apply

For a fork, first change the
[Git identity](../home/dot_config/git/config.tmpl) and
[public key](../home/dot_config/git/github.pub).

```sh
chezmoi diff
chezmoi apply
```

Chezmoi downloads the wallpaper and deploys settings. Open a new Fish terminal:

```fish
fisher update
cd ~
mise install bun node uv
```

Fisher installs the managed `done` and `autopair.fish` plugins. Fish does not load
a distribution's bundled configuration. Bash remains available for scripts;
its startup configuration is not managed. See [Fish shortcuts](maintenance.md#fish).

## Desktop services

Ansible enables and starts NetworkManager, BlueZ, power-profiles-daemon, and the
user's PipeWire sockets and WirePlumber service. It enables SDDM for the next
boot without restarting the current login session. Use SDDM as the system's
display manager and disable any competing network or display manager first.

Log out and select Hyprland at the login screen. Its startup launches Canopy,
hyprpaper, hypridle, Fcitx5, the Polkit agent, and 1Password. Do not run another
notification daemon alongside Canopy. Idle locking starts after five minutes; displays turn off
after ten. Save work before signing out: applying the new Hyprland settings can
reload shortcuts immediately, while startup programs need a new session.

## Login keyring

GNOME Keyring stores desktop application credentials; 1Password remains the SSH
agent. Arch's SDDM PAM configuration already starts the keyring and unlocks it
when you log in with your password. After installing `gnome-keyring`, sign out
and sign back in with your password. An existing login keyring must use the same
password as your Linux account.

PAM unlocks the keyring named **Login**. If an application uses a separate
**Default Keyring**, unlock Login first, then select **Automatically unlock this
on login** when unlocking Default Keyring. GNOME stores that keyring's unlock
password inside Login, allowing both to unlock after a password login. Changing
the default keyring alone does not enable this.

Fingerprint login cannot unlock the encrypted keyring because it does not supply
your password. After a fingerprint login, an application may ask you to unlock
the keyring. Keep its password set to preserve encryption.

## Login screen

See [SDDM setup](sddm.md) for the Canopy login theme and monitor layout.

## Fingerprint authentication

See [Fingerprint setup](fingerprint.md) for manual enrollment with the Egis
`1c7a:05d5` reader. Hyprlock has native
fingerprint authentication enabled; password unlocking remains available.

## Git authentication

Sign in to [1Password for Linux](https://support.1password.com/install-linux/),
then enable **Settings → Developer → Use the SSH Agent**. The managed public key
must match a key in 1Password and be registered on GitHub for authentication and
signing. The official Linux install supplies `/opt/1Password/op-ssh-sign`.

In a new Fish terminal, verify the agent and GitHub SSH authentication:

```sh
ssh-add -l
ssh -T git@github.com
```

GitHub reports successful authentication with exit status 1. Applying these
dotfiles does not sign in to accounts or copy private keys.
