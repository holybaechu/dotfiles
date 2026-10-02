# Windows preferences

[Windows guide](README.md) · [Recovery](recovery.md)

## Desktop and privacy

| Group | Settings |
| --- | --- |
| Explorer | Open This PC; hide Home/Gallery and desktop icons; show hidden files and extensions |
| Desktop | Dark mode, transparency, taskbar auto-hide, windows-only Alt+Tab; hide Search/Task View/Chat |
| Input | Disable native snapping, Sticky Keys shortcut, and mouse acceleration |
| Appearance | Disable window shadows and minimize/restore animation |
| Search | Disable Windows Search indexing, web/cloud suggestions, and search highlights |
| Promotions | Disable selected ads, suggested installs, and setup/account prompts |
| Privacy | Disable DiagTrack, location **and Find My Device**, online speech, typing/inking collection, and activity uploads |
| Development | Enable Win32 long paths; opt out of PowerShell, .NET CLI, and WinGet telemetry |

Diagnostic data is set to the minimum supported level: `0` on Enterprise/Education,
`1` on Pro/Home. Delivery Optimization uses mode `0`.
Widgets use taskbar settings and package removal; some Settings promotions remain on Pro.

Approve elevated user-policy changes **as the same Windows account**.
Long paths still require application support. Reopen affected apps or sign out after UI changes;
restart running tools to load telemetry environment variables.
WinGet telemetry configuration is applied through `chezmoi apply`.

Selected desktop/privacy preferences have no rollback journal or restore point.
Earlier privacy and appearance helpers retain [recovery journals](recovery.md).

## Windows AI

Notepad and Paint use supported AI policies. Paint covers Cocreator, generative fill,
and Image Creator on supported editions/builds; generative erase/background-removal
policies are unverified. Check the app UI after applying.
See [Notepad policy support](https://learn.microsoft.com/windows/client-management/manage-notepad)
and [Windows AI policies](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-windowsai).

Recall and standalone Microsoft Copilot removal are covered in [App removal](debloat.md).

## Defender

Enables PUA blocking and network protection when prerequisites are met.
Network protection requires a supported edition and active Defender with real-time,
behavior, and cloud-delivered protection. Policy/tamper rejection is reported.

Recheck browser downloads, development tools, and WSL connectivity after applying.
See [network protection requirements](https://learn.microsoft.com/defender-endpoint/enable-network-protection).

## Graphics

Enables windowed-game optimization on Windows 11 22H2+ and supported GPU scheduling.
HDR, VRR, and per-app preferences are preserved.
`RestartPending` means scheduling was requested but is not yet observed active.
After restarting, check from the repository root:

```powershell
.\system\windows\scripts\Graphics.ps1 -Operation Get -Context Machine
```

## Appearance

Disables Windows minimize/restore animation and enables transparency.
Other animation preferences remain unmanaged. Upgrading from the old broad animation
preset restores its other settings from the journal.

The preferences module also sets the manual Windows accent to the
[desktop palette](../../docs/desktop.md#colors), including its light/dark shades.
Automatic wallpaper accent selection is disabled. To apply only the accent,
run from the repository root in normal PowerShell 7:

```powershell
.\system\windows\scripts\AccentColor.ps1 -Operation Set
.\system\windows\scripts\AccentColor.ps1 -Operation Test
```

`Test` returns `True` when Windows retains every value. Reopen affected apps or sign out
if they still show the old accent. This helper has no rollback journal; choose another
color in Settings → Personalization → Colors to replace it.

Run from the repository root in normal PowerShell 7:

```powershell
.\system\windows\scripts\VisualEffects.ps1 -Operation Set
.\system\windows\scripts\VisualEffects.ps1 -Operation Get
```

Apps may need reopening or a sign-out. See [Restore appearance](recovery.md#restore-appearance).
