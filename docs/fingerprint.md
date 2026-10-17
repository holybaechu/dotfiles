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

Update the [SDDM theme](sddm.md#install) for its Fingerprint action.

The helper requires a matching scan before asking sudo to update SDDM, sudo,
and Polkit. It preserves their account/session rules and the original files in
`/var/backups/dotfiles-fingerprint`. Rerunning keeps the first backups.
It upgrades the previous password-first rules to fingerprint-first authentication.
TTY login and the shared `system-auth` configuration remain available for recovery.

## Use

| Prompt | Fingerprint action |
| --- | --- |
| SDDM | Select your user, press Enter on Fingerprint, then scan |
| sudo | Scan when sudo requests authentication |
| Polkit permission dialog | Scan when the dialog appears |
| Hyprlock | Scan directly; password input also works |

SDDM, sudo, and Polkit try fingerprints first. After three unsuccessful scans or
ten seconds without a match, they fall back to the password. In SDDM, enter your
password before pressing Enter or the sign-in arrow; it will be checked after the
scan fails or times out. A successful scan needs no password.

Test with `sudo -k; sudo -v`: scan once, then repeat and wait for the password
prompt. Test the lock screen before signing out to test SDDM. GNOME Keyring still
needs a password after fingerprint login; see [Login keyring](setup.md#login-keyring).

The standard fingerprint module processes methods sequentially. A Polkit agent or
sudo's graphical askpass prompt does not make them run in parallel; see the
[fingerprint module limitations](https://manpages.debian.org/testing/libpam-fprintd/pam_fprintd.8.en.html#LIMITATIONS).
Polkit handles applications that request it; it does not replace sudo's command
authorization. Hyprlock handles password and fingerprint input independently.

## Duplicate enrollment with no registered fingers

`NoEnrolledPrints` together with `enroll-duplicate` after touching the reader can
mean the sensor still holds a fingerprint whose Linux enrollment record is gone.
Repeating `fprintd-delete` cannot remove an enrollment it cannot discover.

The [storage utility](../system/linux/libfprint-egis-05d5/storage.c) targets only
the Egis `1c7a:05d5` reader and uses the installed driver. Build it from the
checkout and inspect the reader without deleting anything:

```sh
gcc -Wall -Wextra -O2 system/linux/libfprint-egis-05d5/storage.c \
    -o /tmp/egis-fingerprint-storage $(pkg-config --cflags --libs libfprint-2 gusb)
sudo systemctl stop fprintd
sudo /tmp/egis-fingerprint-storage --list
sudo systemctl start fprintd
```

If storage is already empty, investigate the driver instead of resetting it.
If fingerprints remain and you want to start over, the following reset erases
**all fingerprints on this reader**, including other users' or Windows
enrollments. They will need enrollment again. The utility requires typing
`CLEAR ALL` and checks that the reader is empty afterward.

```sh
sudo systemctl stop fprintd
sudo /tmp/egis-fingerprint-storage --clear
sudo systemctl start fprintd
```

Always start fprintd again, including after a cancelled or failed reset. Then
enroll for your normal account and verify the result:

```sh
sudo fprintd-enroll "$USER" -f right-index-finger
fprintd-verify -f right-index-finger
```

Wait for `enroll-completed` and `verify-match` before running the setup helper.
Keep the explicit username when enrolling through sudo; omitting it enrolls root.

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
