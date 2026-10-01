# App and component removal

[Windows guide](README.md) · [Recovery](recovery.md)

## Apps

The [removal list](scripts/Debloat.ps1) includes:

- Microsoft Family, Bing, Clipchamp, Edge, OneDrive, Teams, To Do, and Outlook for Windows.
- Power Automate, Start Experiences App, Windows Sound Recorder, Xbox and Xbox Live components (including Game Bar), Weather, and News.
- Media Player (replaced with PotPlayer), Quick Assist, Sticky Notes (Sticker Memo), and Feedback Hub.
- Solitaire, Dev Home, Get Help, Windows Web Experience, Widgets Platform Runtime, standalone Copilot, and Microsoft 365 Office Hub. Phone Link and Cross Device remain installed.
- Get Started, legacy Mail and Calendar, Maps, Skype, and 3D Viewer.

Store apps are removed for all users and deprovisioned for new accounts.
Desktop removals cover the current user and visible machine-wide installations.
Classic Office Outlook, Phone Link, Cross Device, Store, WebView2, and shared codecs remain.

Missing apps are skipped; failed inventories, blocked uninstalls, and remaining targets
are reported. Edge uses its registered uninstaller and may be restricted by device or region.
If a restart is requested, restart and rerun.

**App removal can delete local app data.** OneDrive's synced folders are retained.
To keep an app, remove its identity from the list before rerunning bootstrap.
Reinstall through Store or the original installer. Choose file associations in
**Settings → Apps → Default apps**.

## Check or apply

Run from the repository root in **normal PowerShell 7**. WinGet requests elevation
for Store removals; desktop removals must remain unelevated.
Setup installs PotPlayer and replacement browsers before removing their predecessors.

```powershell
.\system\windows\Configure.ps1 -Module debloat
.\system\windows\Configure.ps1 -Action Apply -Module packages  # Includes PotPlayer
.\system\windows\Configure.ps1 -Action Apply -Module debloat
```

For direct helper use, `-AppType Store` requires administrator Windows PowerShell 5.1;
`-AppType Desktop` requires a normal session.

## Optional components

Targets Recall, legacy Media Player, Fax and Scan, and installed handwriting capabilities.
PotPlayer must be installed before legacy Media Player removal.

Check from the repository root in administrator Windows PowerShell 5.1:

```powershell
.\system\windows\scripts\RemoveOptionalComponents.ps1 -Operation Get
```

Inspect `Unsupported` and pending states: disabled-only features can retain payloads.
Click to Do is removed only if Windows exposes its standalone optional feature;
the protected CoreAI package remains.

Recall policy requires Windows 11 24H2 with KB5055627 or later.
Removal can delete snapshots; reinstalling Recall does not recover them.
