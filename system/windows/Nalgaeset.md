# Nalgaeset

Windows package setup installs [Nalgaeset 11.01](https://smlooking4u.mycafe24.com/ngs_download.htm).
The preferences module enables it as the current user's default input method.
Its native configuration is managed in `home/AppData/Roaming/YmSoft/NgsLib/imeconf.dat`.
Restart apps after applying changed input settings.

| Shortcut | Action |
| --- | --- |
| Hangul key or left Shift+Space | Switch Korean two-set and Gallium Colstag |
| Right Shift+Space or Shift+Hangul | Select the required QWERTY pass-through mode |
| Win+Space | Switch Windows input methods |

Gallium uses the Colstag arrangement with Y, P, F down the right index column.
It changes text input handled by Nalgaeset; application shortcuts, password
fields and IME-off input use the underlying Windows keyboard layout.

`Gallium-Colstag.xml` beside `imeconf.dat` is the readable settings export.
To change the configuration, edit that XML and import it using **Nalgaeset
Control Panel > Import**. Click **OK**, then run
`chezmoi add "$env:APPDATA\YmSoft\NgsLib\imeconf.dat"` to retain the native file.
Keep the XML export and native file together when updating the settings.

Applying the dotfiles removes the old EPKL folder and startup shortcut.
The Microsoft IME and US keyboard remain available through Win+Space for recovery.
