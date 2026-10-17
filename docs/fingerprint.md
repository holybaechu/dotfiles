# Fingerprint authentication

The Egis ETU906Axx-E reader (`1c7a:05d5`) needs the experimental
[likeablob driver fork](https://github.com/likeablob/libfprint-fmv-etu906axx-e).
The [local package](../system/linux/libfprint-egis-05d5/PKGBUILD) pins its source
revision, adds this device ID, and builds only the Egis driver. It replaces
`libfprint` through pacman; other fingerprint reader models need their own driver.
The patched driver is an explicit setup step, outside bootstrap.

## Install and enroll

Keep a terminal open until password and fingerprint authentication both work.
From the checkout, install the packages and build the driver as your normal user:

```sh
sudo pacman -S --needed gnome-keyring fprintd
cd system/linux/libfprint-egis-05d5
makepkg -si
cd ../../..
sudo systemctl restart fprintd
fprintd-enroll -f right-index-finger
```

Accept replacing `libfprint` when pacman asks. `makepkg -si` installs the build
dependencies as needed. Follow the enrollment prompts, lifting and touching the
same finger repeatedly. If the reader is not detected or enrollment fails, stop
here; PAM has not been changed.

Enable authentication after enrollment:

```sh
python3 system/linux/setup-fingerprint.py
chezmoi apply ~/.config/hypr/hyprlock.conf
```

The helper requires a matching scan before asking sudo to update SDDM, sudo,
and Polkit. It preserves their account/session rules and the original files in
`/var/backups/dotfiles-fingerprint`. Rerunning keeps the first backups.
TTY login and the shared `system-auth` configuration remain available for recovery.

## Use

| Prompt | Fingerprint action |
| --- | --- |
| SDDM | Select your user and submit an empty password, then scan |
| sudo | Press Enter at the password prompt, then scan |
| Polkit permission dialog | Submit an empty password, then scan |
| Hyprlock | Scan directly; password input also works |

SDDM, sudo, and Polkit accept a password immediately. Fingerprint verification
allows three attempts within ten seconds before returning to password
authentication. This explicit submission helps distinguish an intended
administrative request from another application's request.

Try `sudo -k; sudo -v` with your password, then again with an empty password and a
scan. Test the lock screen before signing out to test SDDM. GNOME Keyring still
needs a password after fingerprint login; see [Login keyring](setup.md#login-keyring).

## Recovery and updates

To restore the original PAM configuration from the checkout or a TTY:

```sh
sudo python3 system/linux/setup-fingerprint.py --restore
```

To also return to the distribution driver:

```sh
sudo pacman -S libfprint
```

Accept replacing `libfprint-egis-05d5`. The original backups are retained. After
updates to `pambase`, SDDM, or Polkit, review any PAM `.pacnew` files and the
service overrides. The driver source is pinned; update its revision and checksums
deliberately when adopting a newer version.
