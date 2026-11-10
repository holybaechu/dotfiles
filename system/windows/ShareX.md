# ShareX

Windows package setup installs ShareX. Its native global hotkeys are managed in
`home/Documents/ShareX/modify_HotkeysConfig.json`.

| Shortcut | Action |
| --- | --- |
| Ctrl+Shift+X | Rectangle selection |
| Ctrl+Shift+S | Upload clipboard contents |

Ctrl+Shift+X avoids the Fn key on keyboards with a secondary Print Screen key.
Win+Shift+S opens Windows' Snipping Tool.

Quit ShareX before applying its configuration, then reopen it. Uploader
credentials and destinations remain in the local ShareX configuration.

When migrating from the old AutoHotkey setup, exit its ShareX script from the
system tray and uninstall AutoHotkey. Applying the dotfiles removes the old
`ShareX.ahk` startup script.
