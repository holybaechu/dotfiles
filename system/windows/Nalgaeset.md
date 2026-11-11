# Nalgaeset

Windows package setup installs [Nalgaeset 11.01](https://smlooking4u.mycafe24.com/ngs_download.htm).
The preferences module keeps Korean with Nalgaeset as the current user's only
input method and selects it as the default, removing Microsoft IME and US.
Its native configuration is managed in `home/AppData/Roaming/YmSoft/NgsLib/imeconf.dat`.
Restart apps after applying changed input settings.

| Shortcut | Action |
| --- | --- |
| Hangul key or left Shift+Space | Switch Korean two-set and Gallium Colstag |
| Right Shift+Space or Shift+Hangul | Select the required QWERTY pass-through mode |

Gallium uses the Colstag arrangement with Y, P, F down the right index column.
It changes text input handled by Nalgaeset; application shortcuts, password
fields and IME-off input use the underlying Windows keyboard layout.

`Gallium-Colstag.xml` beside `imeconf.dat` is the readable settings export.
To change the configuration, edit that XML and import it using **Nalgaeset
Control Panel > Import**. Click **OK**, then run
`chezmoi add "$env:APPDATA\YmSoft\NgsLib\imeconf.dat"` to retain the native file.
Keep the XML export and native file together when updating the settings.

Applying the dotfiles removes the old EPKL folder and startup shortcut.
To restore another input method, add it under **Settings > Time & language >
Language & region > Language options > Keyboards**. Reapplying the preferences
module removes other input methods again.
