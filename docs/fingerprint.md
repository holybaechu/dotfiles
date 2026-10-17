# Fingerprint authentication

Bootstrap builds the experimental [likeablob driver fork](https://github.com/likeablob/libfprint-fmv-etu906axx-e)
for the Egis ETU906Axx-E reader (`1c7a:05d5`). The
[local package](../system/linux/libfprint-egis-05d5/PKGBUILD) pins its source
revision, adds this device ID, and builds only the Egis driver. It replaces the
distribution's `libfprint` package. Other reader models need their own driver.

Ansible configures SDDM, sudo, and Polkit to try fingerprints first and fall back
to passwords. It preserves their account/session rules and leaves `system-auth`
unchanged.

## Enroll

After bootstrap, enroll a finger for your normal account:

```sh
fprintd-enroll -f right-index-finger "$USER"
fprintd-verify -f right-index-finger "$USER"
```

Follow the enrollment prompts, lifting and touching the same finger repeatedly.
Wait for `enroll-completed` and `verify-match`. Enrollment is manual; bootstrap
does not create or delete fingerprints. Apply the home files with chezmoi to
enable Hyprlock's fingerprint support.

## Use

| Prompt | Fingerprint action |
| --- | --- |
| SDDM | Select your user, press Enter on Fingerprint, then scan |
| sudo | Scan when sudo requests authentication |
| Polkit permission dialog | Scan when the dialog appears |
| Hyprlock | Scan directly; password input also works |

SDDM, sudo, and Polkit fall back to the password after three unsuccessful scans
or ten seconds without a match. In SDDM, enter your password before submitting
to use it after scanning fails or times out. A successful scan needs no password.

Test with `sudo -k; sudo -v`: scan once, then repeat and wait for the password
prompt. GNOME Keyring still needs a password after fingerprint login; see
[Login keyring](setup.md#login-keyring).

The standard fingerprint module processes methods sequentially; see its
[limitations](https://manpages.debian.org/testing/libpam-fprintd/pam_fprintd.8.en.html#LIMITATIONS).
Hyprlock handles password and fingerprint input independently.

## Updates

Rerun `./bootstrap.sh --tags fingerprint` after editing the PAM rules.
The driver builds with the packages tasks; bump its package version or release
when updating the pinned source or patch, then run `./bootstrap.sh --tags packages`.
Review PAM `.pacnew` files after updates to `pambase`, SDDM, or Polkit.
