# EPKL

Applying the dotfiles downloads [EPKL v1.4.2](https://github.com/DreymaR/BigBagKbdTrixPKL/releases/tag/EPKL_1-4-2)
to `%LOCALAPPDATA%\EPKL` and creates a startup shortcut for the current user.
Run `%LOCALAPPDATA%\EPKL\EPKL.exe` to start it immediately.

`home/AppData/Local/EPKL/EPKL_Layouts_Override.ini` selects Gallium Colstag,
using EPKL's `Gal-eD_ANS_Ortho` variant with its AltGr character layers.
Keep the underlying Windows English keyboard set to US QWERTY.

`home/AppData/Local/EPKL/EPKL_Settings_Override.ini` sets `suspendingLIDs = 0412`
so EPKL suspends while Microsoft Korean IME is selected and resumes when you
select English (US). This also suspends Gallium in the Korean IME's English
mode; the setting detects the selected input layout, not the Hangul toggle.

If Windows only has Korean configured, add English (United States) with the
US keyboard under **Settings > Time & language > Language & region**. Use
Win+Space to switch between Gallium English and the unchanged Korean IME.

| Shortcut | Action |
| --- | --- |
| Ctrl+Shift+3 | Suspend or resume remapping |
| Ctrl+Shift+4 | Quit EPKL |
| Ctrl+Shift+5 | Reload configuration |
| Ctrl+Shift+6 | Open layout and settings |

After applying configuration changes, reload EPKL. Settings changed through
EPKL's interface may be overwritten by the next dotfiles apply.
