# App and component removal

[Windows guide](README.md) · [Recovery](recovery.md)

## App removals

Bootstrap installs PotPlayer, then applies the [debloat module](debloat.winget). The removal
list is explicit:

- Microsoft Family, Bing, Clipchamp, Edge, OneDrive, Teams, To Do, and Outlook for Windows.
- Power Automate, Start Experiences App, Windows Sound Recorder, Xbox and Xbox Live components (including Game Bar), Weather, and News.
- Media Player (replaced with PotPlayer), Quick Assist, Sticky Notes (Sticker Memo), and Feedback Hub.
- Solitaire, Dev Home, Get Help, Windows Web Experience, Widgets Platform Runtime, standalone Copilot, and Microsoft 365 Office Hub. Phone Link and Cross Device remain installed.
- Get Started, legacy Mail and Calendar, Maps, Skype, and 3D Viewer.

For privacy, appearance, graphics, and Defender settings, see [Preferences and
verification](preferences.md).

## Scope and reruns

Store apps are removed for all users and deprovisioned for new accounts in an elevated resource.
A separate resource runs WinGet in the normal user session to remove standalone OneDrive,
classic Teams, Power Automate, and Edge installations visible to that user or installed
machine-wide; individual machine-wide uninstallers can request elevation. This separation is
required because WinGet rejects user-scope uninstalls from an administrator session. Other
users' per-user desktop installations are outside this scope. Classic Outlook bundled with
Microsoft Office is not removed. Phone Link, Cross Device, Defender, WSL, Start Menu, Microsoft
Store, WinGet, shared frameworks/codecs, and Edge WebView2 remain available.

Missing apps are skipped on reruns. Inventory errors, blocked uninstalls, and apps still present
after removal fail the module; the other removals are attempted before reporting failures.
[Windows can restrict Edge removal by device and
region](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-update-policies#uninstall).
Setup uses its registered uninstaller and does not delete browser files or change protected
Windows policies. If removal requires a restart, restart and rerun setup; debloating never
restarts Windows automatically.

## Data and reinstallation

Removing an app can remove its local app data. OneDrive's synced folders are not deleted by this
script. Reinstall an app through Microsoft Store or its original installer if needed, and remove
its identity from the removal list before running bootstrap again. Choose PotPlayer's file
associations in **Settings → Apps → Default apps**; setup does not overwrite existing
associations.

## Check or apply app removal

Run commands from the repository root. To check or apply only this module, use a **normal,
non-administrator PowerShell 7 window**. Windows requests elevation for the Store-app resource:

```powershell
.\system\windows\Configure.ps1 -Module debloat
.\system\windows\Configure.ps1 -Action Apply -Module packages  # Includes PotPlayer
.\system\windows\Configure.ps1 -Action Apply -Module debloat
```

### Troubleshooting privileges

For troubleshooting, the helper requires an explicit `-AppType Store` or `-AppType Desktop`.
Store operations require administrator Windows PowerShell 5.1; desktop operations run in a
normal PowerShell session. Prefer the configuration commands above to run both with the correct
privileges.

## Windows 11 Outlook behavior

The existing Outlook uninstall/deprovisioning is the supported Windows 11 path. [Microsoft's
installation
guidance](https://learn.microsoft.com/microsoft-365-apps/outlook/get-started/control-install#block-new-outlook-preinstallation-on-windows)
says updated 23H2 respects deprovisioning; the `BlockedOobeUpdaters` workaround is documented
for Windows 10 and is not added to this Windows 11 configuration. Legacy Mail/Calendar removal
also removes its migration path.

## Optional Windows components

Optional servicing targets Recall, legacy Windows Media Player, Windows Fax and Scan, and
installed `Language.Handwriting` capabilities. It preserves language basics, keyboard input,
printing services, and the WIA scanning platform. Removing the Fax capability also removes the
legacy Fax and Scan application. PotPlayer must be detected before removing an installed legacy
Media Player.

The helper distinguishes `DisabledWithPayloadRemoved`, `NotPresent`, and pending states. A
disabled-only feature is not counted as removed: Windows client servicing can retain payloads,
which is reported in `Unsupported` instead of retried indefinitely. Changes never reboot Windows
automatically. Restart when warned, then rerun the check. Supported items can converge while
unsupported items remain; inspect the `Unsupported` list as well as the feature/capability
states.

**Click to Do removal is unsupported on the inspected build.** Its protected
`MicrosoftWindows.Client.CoreAI` package is retained. A standalone `ClickToDo` optional feature
can be serviced if Windows exposes that exact feature; otherwise the helper warns explicitly. It
does not substitute disabling or patch the Appx database.

For detailed component state, use Windows PowerShell 5.1 as administrator:

```powershell
.\system\windows\scripts\RemoveOptionalComponents.ps1 -Operation Get
```

Recall policies are limited to Windows 11 24H2 with KB5055627 or later. The component helper
records original state before setting `AllowRecallEnablement=0` and requesting removal through
servicing. It still reports disabled-only or restart-pending states rather than assuming the
payload disappeared. Recall changes can delete snapshots; re-enabling the component does not
recover them. Unsupported Click to Do policies and other AI frameworks are not changed.
