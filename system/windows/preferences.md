# Windows preferences and verification

[Windows guide](README.md) · [Recovery](recovery.md)

Commands below run from the repository root.

## Privacy module

`privacy` configures user advertising, recommendations, welcome/setup prompts, Widgets
visibility, and recording settings, plus machine diagnostic-data level, update sharing, and
supported Recall policies. It does not depend on the Enterprise-only
`DisableWindowsConsumerFeatures` policy. Diagnostics use the minimum supported level: off
(`AllowTelemetry=0`) on Enterprise/Education and required data (`1`) on Pro/Home. This is not a
claim of zero telemetry. Delivery Optimization uses mode `0` and retains the update services.

Windows Pro also lacks support for the broad `DisableConsumerAccountStateContent` policy. The
helper reports this limitation; user suggestion settings are applied, but removal of every
Microsoft 365 card in Settings Home is not guaranteed. Game Bar's controller launch is disabled
without replacing its URL handlers with unrelated programs.

User personalization uses the normal-user preference instead of writing the administrator-owned
HKCU policy key. Widgets use the taskbar preference and the selected package removals: the
inspected Windows build rejected `AllowNewsAndInterests` writes even with elevation, so
bootstrap does not require or force that policy. Registry permissions and ownership are not
changed. Individual privacy failures are collected after attempting the other settings and
report the exact paths.

## Desktop and privacy preferences

The selected preference resources are part of `preferences.winget`, so both bootstrap and
`Configure.ps1 -Module preferences` include them automatically.

### Desktop and input

`SelectedPreferences.ps1 -Context User` opens Explorer at This PC, hides Home/Gallery, uses dark
mode and windows-only Alt+Tab, hides taskbar Search/Task View/Chat, and disables Snap
Assist/flyouts. Native window arranging and the Sticky Keys shortcut use the Windows preference
APIs, preserving unrelated Sticky Keys flags and ordinary keyboard/IME support. Recent/frequent
files, compact view, folder templates, context menus, End Task and scrollbars are not changed by
this group. Explorer/UI applications that cache preferences can need a sign-out or reopening;
Explorer is not force-restarted.

### Search and user-policy elevation

Current-user suggestions, promoted installs, account prompts, web/cloud-search preferences,
online speech and typing/inking data collection are configured separately from the existing
privacy values. `-Context UserPolicy` manages `DisableSearchBoxSuggestions` in an elevated
resource because the user policy key can be administrator-owned. Approve elevation **as the same
Windows account**; do not use another account's administrator credentials for that resource.
Policy ownership and permissions are never changed. Windows Search indexing and Bing Search app
removal remain under their existing configuration.

### Machine settings

`-Context Machine` stops/disables only DiagTrack, disables location **and Find My Device**,
prevents device companion-app downloads without excluding drivers, stops activity
publication/upload while retaining the activity feed for clipboard history, disables online
speech by policy, enables Win32 long paths, and configures AI-app policies. Long paths still
require application support and can require a restart for existing processes. The Notepad policy
requires a version that implements AI controls; see [Microsoft's Notepad
guidance](https://learn.microsoft.com/windows/client-management/manage-notepad).

### Notepad and Paint AI controls

Paint uses the documented `DisableCocreator`, `DisableGenerativeFill` and `DisableImageCreator`
policies on supported Pro/Enterprise-family editions/builds (22H2/23H2 with build revision
4870+, or 24H2 revision 3360+, or newer builds). [Microsoft's WindowsAI policy
map](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-windowsai) and the
inspected Windows ADMX do not verify policies for generative erase/background removal.
Get/Test/Set report that limitation instead of treating invented values as proof that every AI
feature is disabled. Paint UI behavior remains a post-apply check. Existing supported Recall
controls and exact standalone Microsoft Copilot removal are retained; GitHub Copilot in Neovim
is unaffected.

### Tool telemetry

PowerShell and .NET CLI telemetry opt-outs are saved as user environment variables. Restart
already running tools, or sign out and back in, so they receive them. The WinGet chezmoi
modifier merges `telemetry.disable=true` into the native JSONC settings, retaining unrelated
settings. Apply that file through `chezmoi apply`; the system preference module handles the
environment variables.

### Recovery limits

The selected preferences do **not** write rollback journals or create restore points. Earlier
privacy, graphics, visual, and component journals are documented in [Recovery](recovery.md).
These preferences add no DNS, update/restart, Fast Startup, Sandbox, SmartScreen, or LSA
configuration.

## Defender protection

`DefenderProtection.ps1` enables PUA blocking and network protection, checks actual preferences
after changing them, and skips matching values on reruns. It requires active Microsoft Defender
Antivirus rather than replacing another antivirus.

Network protection additionally requires a supported edition, real-time protection, behavior
monitoring and cloud-delivered protection; unmet prerequisites and policy/tamper rejection are
reported, not bypassed. Unsupported editions report that network protection is unavailable while
allowing the separate PUA setting.

The resource does not alter those prerequisite settings, add exclusions or weaken tamper
protection. [Microsoft's network-protection
guidance](https://learn.microsoft.com/defender-endpoint/enable-network-protection) describes
requirements and potential app blocking. Enablement/readback is configuration verification, not
a live enforcement test. Recheck your browser, development downloads and WSL connectivity after
applying.

## Graphics

Windowed-game optimization requires Windows 11 22H2 or later. Only `SwapEffectUpgradeEnable` is
changed; HDR, VRR, and per-app preferences remain intact.

GPU scheduling is checked against fresh DxDiag `HardwareSchedulingAttributes`.
Unknown/unsupported capabilities fail without a setting change. `Enabled` means the driver
reports active scheduling. `RestartPending` means enablement was requested but is not yet
observed active. Test accepts an already-requested change to avoid repeated writes and emits a
restart warning; it does not prove activation. Recheck after restarting:

```powershell
.\system\windows\scripts\Graphics.ps1 -Operation Get -Context Machine
```

Configuration checks do not establish an FPS improvement.

## Appearance

The `preferences` module disables only the Windows minimize/restore animation preference using
[SPI_SETANIMATION and
ANIMATIONINFO](https://learn.microsoft.com/windows/win32/api/winuser/ns-winuser-animationinfo).
The journal retains its original `MinimizeMaximize` name. Transparency is explicitly enabled.
Client-area, taskbar, menu, combo-box, list-box scrolling, selection-fade, and tooltip
preferences are otherwise unmanaged. Komorebi's own movement animations remain disabled in its
existing configuration. App opening/closing behavior has not been verified; this setting is not
a promise to suppress every app's transitions.

When upgrading from the earlier broad animation preset, Set first restores those other
preferences from `visual-effects-user.json` and removes only the consumed rollback entries. Test
reports false while that migration is pending, even if window animations and transparency
already match. Fresh setups without those records leave other animation choices untouched. Font
smoothing, hover highlighting, and the existing shadow preferences are retained.

The helper persists and broadcasts these preferences, then reads them back. Applications that
cache appearance settings may need reopening or a sign-out; it does not restart Explorer
automatically. Apply or inspect only this setting from normal PowerShell 7:

```powershell
.\system\windows\scripts\VisualEffects.ps1 -Operation Set
.\system\windows\scripts\VisualEffects.ps1 -Operation Get
```

For the journal location and restoration command, see [Restore
appearance](recovery.md#restore-appearance).
