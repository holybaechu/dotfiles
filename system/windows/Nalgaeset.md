# Nalgaeset

Windows package setup installs [Nalgaeset 11.01](https://smlooking4u.mycafe24.com/ngs_download.htm).
The preferences module keeps Nalgaeset as the default and Microsoft IME available
under Korean, removing the separate US keyboard.
Its native configuration is managed in `home/AppData/Roaming/YmSoft/NgsLib/imeconf.dat`.
Restart apps after applying changed input settings.

| Shortcut | Action |
| --- | --- |
| Hangul key or left Shift+Space | Switch Korean two-set and Gallium Colstag |
| Right Shift+Space or Shift+Hangul | Select the required QWERTY pass-through mode |
| Win+Space | Switch between Nalgaeset and Microsoft IME |

Gallium uses the Colstag arrangement with Y, P, F down the right index column.
It changes text input handled by Nalgaeset; application shortcuts, password
fields and IME-off input use the underlying Windows keyboard layout.

The preferences module disables the [`Alt+=` full-width shortcut](http://moogi.new21.org/tc/1197) using **System
layer > Keyboard driver correction > Recognize Alt+= as-is**
(`HKCU\Software\YMSoft\NgsEdit\Settings\KbdDriverModifier=3`).
This blocks the shortcut, not the full-width feature itself. If an existing app
is already in full-width mode, select half-width from the IME's width menu.

`Gallium-Colstag.xml` beside `imeconf.dat` is the readable settings export.
To change the configuration, edit that XML and import it using **Nalgaeset
Control Panel > Import**. Click **OK**, then run
`chezmoi add "$env:APPDATA\YmSoft\NgsLib\imeconf.dat"` to retain the native file.
Keep the XML export and native file together when updating the settings.

Applying the dotfiles removes the old EPKL folder and startup shortcut.
Reapplying the preferences module keeps only Nalgaeset and Microsoft IME.
