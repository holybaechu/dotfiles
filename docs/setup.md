# Setup

Use a normal Linux user account with internet access. The desktop requires
Hyprland 0.56+ (Lua configuration) and Quickshell 0.3.2+; Neovim requires 0.12+.
See [Software](software.md) for applications and package lists. Other Wayland
compositors need their own desktop configuration.

## Install packages

On Arch or a derivative, install `git`, `curl`, and `yay`, then run from the checkout:

```sh
cd ~/.local/share/chezmoi
./bootstrap.sh
```

The helper adds the signed [Cider repository](https://repo.cider.sh/), runs a full
pacman upgrade, installs the listed repository/AUR packages,
marks them explicitly installed to protect them from dependency cleanup, and
registers this checkout with chezmoi. Review AUR build prompts. It does not
apply dotfiles or enable system services. If a package step fails, resolve the error
and rerun the helper.

To configure only Cider's repository, run `./system/linux/setup-cider.sh`.
The setup pins its signing key fingerprint and can be rerun without adding
duplicate repository entries.

On another distribution, install the equivalent packages from the
[Arch list](../system/linux/packages.arch) and [AUR list](../system/linux/packages.aur),
including Fisher, the required fonts, 1Password's desktop application, and Helium.
Then register the checkout:

```sh
chezmoi init --source ~/.local/share/chezmoi
```

## Review and apply

Back up any existing configuration you want to keep, especially `~/.config/hypr`
and `~/.config/fish`. For a fork, first change the
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

Use NetworkManager for network connections, BlueZ for Bluetooth, PipeWire with
WirePlumber for audio, and power-profiles-daemon for power profiles. On a systemd
installation, after checking that no competing network manager is configured:

```sh
sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber
```

Log out and select Hyprland at the login screen. Its startup launches Canopy,
hyprpaper, hypridle, Fcitx5, the Polkit agent, and 1Password. Do not run another
notification daemon alongside Canopy. Idle locking starts after five minutes; displays turn off
after ten. Save work before signing out: applying the new Hyprland settings can
reload shortcuts immediately, while startup programs need a new session.

If the desktop fails, use a TTY (`Ctrl+Alt+F3`) to restore your configuration backup
before logging in again. Individual configuration recovery is covered in
[Maintenance](maintenance.md#recovery).

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

See [SDDM setup](sddm.md) to install the Canopy login theme and match the desktop's
monitor layout. Its system configuration is installed separately from chezmoi.

## Fingerprint authentication

See [Fingerprint setup](fingerprint.md) for the experimental Egis `1c7a:05d5`
driver, enrollment, and SDDM/sudo/Polkit configuration. Hyprlock has native
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
