# Desktop and Canopy

[Hyprland configuration](../home/dot_config/hypr/hyprland.lua) supplies tiling,
global shortcuts, and Super-drag movement. Workspaces 1–8 are global across monitors;
Canopy renders one bar per output and highlights that output's active workspace.
Launcher and panel shortcuts open on the focused monitor; bar clicks open on the
clicked monitor.

The Acer XV272U W2 runs at 2560×1440, 144 Hz, and 100% scaling to the left of the
laptop, with their top edges aligned. Its monitor rule matches the model so the
layout follows it when switching ports.

Hyprland exports `XDG_SESSION_TYPE=wayland` to apps and the D-Bus/systemd user
environment so current Chromium and Electron builds can select native Wayland.
Apps that override backend selection need their own launch flag; ChatGPT uses
[chatgpt-flags.conf](../home/dot_config/chatgpt-flags.conf). Fully quit and reopen
an app after changing its backend. Log out and back in after applying session
environment changes.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `Super+Space` | Toggle app launcher |
| `Super+Ctrl+Space` | Open filename search |
| `Super+S` | Toggle quick settings |
| `Super+Enter` | Kitty |
| `Super+E` | Yazi in Kitty |
| `Super+B` | Helium |
| `Super+Q` | Close window |
| `Super+H/J/K/L` | Focus left/down/up/right |
| `Super+Shift+H/J/K/L` | Move window left/down/up/right |
| `Super+Shift+Enter` | Promote window in the tiling layout |
| `Super+←/↓/↑/→` | Group with the window in that direction |
| `Super+;` | Remove window from group |
| `Super+[` / `Super+]` | Previous/next grouped window |
| `Super+Shift+[` / `Super+Shift+]` | Previous/next window |
| `Super+=` / `Super+-` | Increase/decrease width |
| `Super+Shift+=` / `Super+Shift+-` | Increase/decrease height |
| `Super+T` | Toggle floating |
| `Super+Shift+F` / `Super+F` | Maximize / fullscreen |
| `Super+M` / `Super+Shift+M` | Park window / show parked windows |
| `Super+X` / `Super+Y` | Swap split sides / toggle split direction |
| `Super+1…8` | Focus workspace |
| `Super+Shift+1…8` | Move window to workspace |
| `Super+left/right mouse drag` | Move/resize floating window |
| `Super+Shift+O` | Reload Hyprland |
| `Super+Ctrl+L` | Lock session |
| `Print` / `Shift+Print` | Copy screen / selected region to clipboard |

Media, volume, and microphone keys use playerctl and wpctl. Brightness keys adjust
the focused display through [screen-brightness](../home/private_dot_local/bin/executable_screen-brightness).
Hyprland uses a special workspace for parked windows. Windows-only elevation,
shortcut/tiling pause, and retile commands have no binding.

## Korean input

The package list includes Fcitx5, its Hangul engine, GTK/Qt integration, the
configuration tool, and Noto CJK fonts. After installing packages and applying
dotfiles, log out and back into Hyprland to start Fcitx5 with the session settings.

[Fcitx5 settings](../home/dot_config/fcitx5/) provide English (US) and Korean
Dubeolsik (두벌식), starting in English. Right Alt sends `Hangul` and toggles
English/Korean; `Ctrl+Space` also toggles. In Korean mode, `F9` opens Hanja
conversion. Left Alt keeps its usual behavior.

The language popup and candidate list use the [Canopy Fcitx5 theme](../home/private_dot_local/private_share/fcitx5/themes/canopy/)
with rounded dark surfaces, green highlights, and Inter text. The tray language
label uses the same green accent. After applying theme changes, reload Fcitx5
with `fcitx5-remote -r`.

GTK apps use native Wayland input, with the Fcitx module configured for XWayland;
Qt apps use the Fcitx module. This follows the
[Fcitx Wayland setup](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland).
The managed Helium and ChatGPT flags enable Wayland input with text-input-v3.
Fully quit and reopen these apps after applying changes.

Open `fcitx5-configtool` to inspect input methods, or `fcitx5-diagnose` to
troubleshoot an app that cannot type Korean. Chezmoi creates the input profile
only when missing; Fcitx5 owns later profile updates and its generated Hangul
settings. Change these in `fcitx5-configtool`. Hotkeys and theme preferences remain
managed in `home/dot_config/fcitx5/`.
To check input, open Kitty or a browser text field, press Right Alt, type
`gksrmf` (한글), then press Right Alt again to return to English.

## Canopy

The [Quickshell configuration](../home/dot_config/quickshell/canopy/shell.qml)
provides app launching, filename search, workspace buttons, system tray, media,
calendar, notifications, and quick settings. The three notched islands, expanding
panels, SVG icons, squircles, spacing, and colors follow the original Windows Canopy.
The media panel expands from the center; other panels expand from the right island.
Panels use the original per-frame spring, delayed blur-and-fade reveal, and collapse
before switching islands. Bar controls reappear after the collapse completes.
Hyprland layer animations are disabled for Canopy so they do not alter this motion.

The launcher combines apps, settings, and home files. Use arrows or Page Up/Down
to select and Enter to open; Escape or clicking outside closes it. Type
`file <name>` (at least two characters) to search only files and folders. Searches
respect ignore files and skip `.git`, `.cache`, `node_modules`, and `.venv`; results
are capped at 24. `Ctrl+R` retries the search. Linux uses a bounded `fd` search of
your home directory instead of Everything's indexed search.

The launcher remembers application use to put recent apps first. Remove
`$XDG_CACHE_HOME/canopy/launcher-history.json` (normally
`~/.cache/canopy/launcher-history.json`) to reset this ranking. It does not save
search queries or filename history.

Quick settings controls Wi-Fi, Bluetooth, audio, microphone mute, display
brightness, and power profiles. Network connections open in `nmtui`. Brightness
lists every connected display from left to right (then top to bottom), in the same
order wherever the panel opens. Each slider controls its named display: laptop
panels use brightnessctl; external monitors use ddcutil over the connector's
DDC/I²C channel. Enable DDC/CI
in the monitor's on-screen menu. On Arch, after installing ddcutil, initialize its
kernel interface and access rules once (later boots load it automatically):

```sh
sudo modprobe i2c-dev
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=i2c-dev --action=add
```

Read or set a specific display without relying on focus:

```sh
screen-brightness --output HDMI-A-1 get
screen-brightness --output HDMI-A-1 set 40
```

Use connector names from `hyprctl monitors`. Failures appear in the panel; an
unsupported external monitor never falls back to changing the laptop panel.
Media controls use MPRIS; mpv's integration is supplied by mpv-mpris. Power actions require a second click;
failed command actions show an error and keep the panel open. Hardware support
and service permissions determine which controls are available.

Canopy starts its tray host with the shell so apps can register before the tray
panel opens. Only apps that publish tray icons appear in the grid; network,
sound, and power controls are in quick settings.

The bell opens notifications and turns green when notifications are present.
The tray chevron opens a four-column icon grid; right-click for app menus. The
calendar starts on Monday and supports arrow keys, Page Up/Down, and Home/End for
the beginning/end of a week. Click the month heading to return to today.
Inter and JetBrains Mono replace the Windows display and utility fonts. The
Windows taskbar toggle is replaced by microphone mute; Linux has no Explorer
taskbar to control.

Canopy owns the notification service. Notifications are limited to the current
shell session and are not a persistent history. Do not start Mako, Dunst, or another
notification daemon concurrently.

Start or inspect the shell inside Hyprland:

```sh
QML_DISABLE_DISK_CACHE=1 quickshell --no-duplicate --config canopy
quickshell --config canopy ipc call launcher toggle
quickshell --config canopy ipc call launcher files
quickshell --config canopy ipc call panel toggle
quickshell --config canopy ipc call -- panel show calendar
quickshell --config canopy kill
```

For a windowed preview with sample data and no system-setting changes:

```sh
QML_DISABLE_DISK_CACHE=1 CANOPY_PREVIEW=1 quickshell --path ~/.config/quickshell/canopy/preview.qml
```

Click the preview's islands to check opening, closing, and switching animations;
Space toggles quick controls and Escape closes the popup. The preview uses the
same panel motion as the desktop.

## Appearance

[Theme.qml](../home/dot_config/quickshell/canopy/Theme.qml) owns Canopy's palette.
[Kitty](../home/dot_config/kitty/kitty.conf),
[Fish](../home/dot_config/fish/conf.d/chezmoi.fish),
[Starship](../home/dot_config/starship.toml),
[Yazi](../home/dot_config/yazi/theme.toml), and
[Neovim](../home/dot_config/nvim/colors/canopy.lua) carry matching colors.
GTK 3 uses adw-gtk3-dark with the [Canopy colors](../home/dot_config/gtk-3.0/gtk.css).
GTK 4 and libadwaita use the matching [CSS palette](../home/dot_config/gtk-4.0/gtk.css).
Qt 6 uses qt6ct, Fusion, and the [Canopy palette](../home/dot_config/qt6ct/colors/Canopy.conf).
The [SDDM login screen](sddm.md) has a matching theme and display layout.
The desktop preference is dark with a green accent; GTK and Qt use Inter 11.
Chezmoi applies these preferences through its desktop-appearance script.
Restart open applications to pick up the theme. Apps with their own theme
settings may need dark mode selected in the app.

Hyprland blurs transparent app backgrounds, Canopy's app launcher, and compatible
popups and input methods. Kitty uses 88% background opacity. Canopy's islands,
panels, and notifications have opaque backgrounds. Text and controls stay sharp,
and ordinary app windows keep their original opacity.
The original wallpaper is downloaded by [chezmoi externals](../home/.chezmoiexternal.toml).

| Role | Color |
| --- | --- |
| Bar | `#000000` |
| Surface | `#11160f` |
| Raised surface | `#293522` |
| Selection | `#3c502b` |
| Accent | `#7cab3d` |
| Text | `#f0f3e7` |
| Muted text | `#aab69e` |
