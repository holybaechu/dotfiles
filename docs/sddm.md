# SDDM login screen

The [Canopy theme](../system/linux/sddm/canopy/Main.qml) uses the desktop wallpaper,
Inter, and the Canopy palette, with a large clock at the top right and a transparent
login form at the bottom left. The selected account appears as a fixed label;
press Left/Right to cycle through users when more than one is available. The last
account and session are remembered. Press Enter or click the arrow beside the
password to sign in. The password field receives keyboard focus when the login
screen opens. A correct password signs in immediately and unlocks the login
keyring. Press Enter with the field empty, or choose Fingerprint, to start a
[fingerprint login](fingerprint.md). The Fingerprint action ignores any text left
in the password field. A failed scan focuses the password field. The form shows
authentication messages; Tab from Fingerprint also moves to the password field.
Power actions require a second click.

The [Hyprlock configuration](../home/dot_config/hypr/hyprlock.conf) shares the
wallpaper, Inter typography, top-right clock, and bottom-left account and
transparent password field. Apply lock-screen changes with
`chezmoi apply ~/.config/hypr/hyprlock.conf`; they appear the next time you lock.

## Install

Bootstrap installs the theme and display settings. After editing them, rerun
the SDDM tasks from the checkout as your normal user:

```sh
./bootstrap.sh --tags sddm
```

Ansible installs the theme and shared wallpaper under
`/usr/local/share/sddm/themes/canopy`, the monitor helper under
`/usr/local/libexec`, and settings at `/etc/sddm.conf.d/20-canopy.conf`.
Rerun these tasks after editing the theme, wallpaper, or monitor settings. These system
files are separate from `chezmoi apply`.

Reboot when ready to activate the display settings. Restarting SDDM immediately
would end the current desktop session. The services tasks enable `sddm.service`
for the next boot.

## Displays

| Display | Mode | Scale | Login form |
| --- | --- | --- | --- |
| Acer XV272U W2 | 2560×1440 at 144 Hz | 100% | Preferred |
| Laptop eDP-1 | 2880×1800 at 120 Hz | 200% | Fallback |

Both displays stay enabled, with the Acer on the left and their top edges
aligned. The laptop shows the wallpaper while the Acer has the login form.
The [monitor helper](../system/linux/sddm/monitors.py) identifies the Acer
from its EDID instead of a fixed connector. Without it, the laptop becomes
primary. The configuration applies when the greeter's X server starts.

SDDM retains its X11 greeter; the selected Hyprland desktop still runs on Wayland.
X11 calls the HDMI connector `HDMI-1`, while Hyprland calls it `HDMI-A-1`.
[SDDM settings](../system/linux/sddm/sddm.conf) set the Qt scale for each output.

## Preview

After installation, preview with SDDM's test mode. Login and power actions have
no effect; the preview closes after twenty seconds:

```sh
timeout 20s sddm-greeter-qt6 --test-mode --theme /usr/local/share/sddm/themes/canopy
```
