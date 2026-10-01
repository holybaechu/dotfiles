# Windows setup and recovery

Run `Configure.ps1` from a normal PowerShell 7 window. WinGet requests elevation for machine resources; user-scope desktop removals remain unelevated.

## Modules

The existing `packages`, `preferences`, and `startup` modules are followed by `privacy`, `graphics`, and `debloat` during bootstrap. Applying all modules installs packages first and removes apps last. Use `-Module privacy`, `-Module graphics`, or `-Module debloat` for a check; add `-Action Apply` to change the machine.

`privacy` configures user advertising, recommendations, welcome/setup prompts, Widgets visibility, and recording settings, plus machine diagnostic-data level, update sharing, and supported Recall policies. It does not depend on the Enterprise-only `DisableWindowsConsumerFeatures` policy. Diagnostics use the minimum supported level: off (`AllowTelemetry=0`) on Enterprise/Education and required data (`1`) on Pro/Home. This is not a claim of zero telemetry. Delivery Optimization uses mode `0` and retains the update services.

Windows Pro also lacks support for the broad `DisableConsumerAccountStateContent` policy. The helper reports this limitation; user suggestion settings are applied, but removal of every Microsoft 365 card in Settings Home is not guaranteed. Game Bar's controller launch is disabled without replacing its URL handlers with unrelated programs.

User personalization uses the normal-user preference instead of writing the administrator-owned HKCU policy key. Widgets use the taskbar preference and the selected package removals: the inspected Windows build rejected `AllowNewsAndInterests` writes even with elevation, so bootstrap does not require or force that policy. Registry permissions and ownership are not changed. Individual privacy failures are collected after attempting the other settings and report the exact paths.

## App and component removal

Additional exact app identities cover Solitaire, Dev Home, Get Help, Windows Web Experience, Widgets Platform Runtime, standalone Copilot, Microsoft 365 Office Hub, Get Started, legacy Mail/Calendar, Maps, Skype, and 3D Viewer. Phone Link, Cross Device, actual Office applications, Defender, WSL, and shared codecs are not targeted.

The existing Outlook uninstall/deprovisioning is the supported Windows 11 path. [Microsoft's installation guidance](https://learn.microsoft.com/microsoft-365-apps/outlook/get-started/control-install#block-new-outlook-preinstallation-on-windows) says updated 23H2 respects deprovisioning; the `BlockedOobeUpdaters` workaround is documented for Windows 10 and is not added to this Windows 11 configuration. Legacy Mail/Calendar removal also removes its migration path.

## Selected desktop and privacy preferences

The [decision record](OPTIMIZATION-PLAN.md) maps the selected questionnaire answers to the implementation. The new resources are part of `preferences.winget`, so both bootstrap and `Configure.ps1 -Module preferences` include them automatically.

`SelectedPreferences.ps1 -Context User` opens Explorer at This PC, hides Home/Gallery, uses dark mode and windows-only Alt+Tab, hides taskbar Search/Task View/Chat, and disables Snap Assist/flyouts. Native window arranging and the Sticky Keys shortcut use the Windows preference APIs, preserving unrelated Sticky Keys flags and ordinary keyboard/IME support. Recent/frequent files, compact view, folder templates, context menus, End Task and scrollbars are not changed by this group. Explorer/UI applications that cache preferences can need a sign-out or reopening; Explorer is not force-restarted.

Current-user suggestions, promoted installs, account prompts, web/cloud-search preferences, online speech and typing/inking data collection are configured separately from the existing privacy values. `-Context UserPolicy` manages `DisableSearchBoxSuggestions` in an elevated resource because the user policy key can be administrator-owned. Approve elevation **as the same Windows account**; do not use another account's administrator credentials for that resource. Policy ownership and permissions are never changed. Windows Search indexing and Bing Search app removal remain under their existing configuration.

`-Context Machine` stops/disables only DiagTrack, disables location **and Find My Device**, prevents device companion-app downloads without excluding drivers, stops activity publication/upload while retaining the activity feed for clipboard history, disables online speech by policy, enables Win32 long paths, and configures AI-app policies. Long paths still require application support and can require a restart for existing processes. The Notepad policy requires a version that implements AI controls; see [Microsoft's Notepad guidance](https://learn.microsoft.com/windows/client-management/manage-notepad).

Paint uses the documented `DisableCocreator`, `DisableGenerativeFill` and `DisableImageCreator` policies on supported Pro/Enterprise-family editions/builds (22H2/23H2 with build revision 4870+, or 24H2 revision 3360+, or newer builds). [Microsoft's WindowsAI policy map](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-windowsai) and the inspected Windows ADMX do not verify policies for generative erase/background removal. Get/Test/Set report that limitation instead of treating invented values as proof that every AI feature is disabled. Paint UI behavior remains a post-apply check. Existing supported Recall controls and exact standalone Microsoft Copilot removal are retained; GitHub Copilot in Neovim is unaffected.

PowerShell and .NET CLI telemetry opt-outs are saved as user environment variables. Restart already running tools, or sign out and back in, so they receive them. The WinGet chezmoi modifier merges `telemetry.disable=true` into the native JSONC settings, retaining unrelated settings. Apply that file through `chezmoi apply`; the system preference module handles the environment variables.

New selected preferences do **not** write rollback journals, create restore points, or add diagnostics/repair commands. Existing privacy/graphics/visual/component journals and previously available tools remain part of the earlier setup and are described below. This change adds no DNS, update/restart, Fast Startup, Sandbox, SmartScreen or LSA configuration.

## Defender protection

`DefenderProtection.ps1` enables PUA blocking and network protection, checks actual preferences after changing them, and skips matching values on reruns. It requires active Microsoft Defender Antivirus rather than replacing another antivirus. Network protection additionally requires a supported edition, real-time protection, behavior monitoring and cloud-delivered protection; unmet prerequisites and policy/tamper rejection are reported, not bypassed. Unsupported editions report that network protection is unavailable while allowing the separate PUA setting.

The resource does not alter those prerequisite settings, add exclusions or weaken tamper protection. [Microsoft's network-protection guidance](https://learn.microsoft.com/defender-endpoint/enable-network-protection) describes requirements and potential app blocking. Enablement/readback is configuration verification, not a live enforcement test. Recheck your browser, development downloads and WSL connectivity after applying.

Optional servicing targets Recall, legacy Windows Media Player, Windows Fax and Scan, and installed `Language.Handwriting` capabilities. It preserves language basics, keyboard input, printing services, and the WIA scanning platform. Removing the Fax capability also removes the legacy Fax and Scan application. PotPlayer must be detected before removing an installed legacy Media Player.

The helper distinguishes `DisabledWithPayloadRemoved`, `NotPresent`, and pending states. A disabled-only feature is not counted as removed: Windows client servicing can retain payloads, which is reported in `Unsupported` instead of retried indefinitely. Changes never reboot Windows automatically. Restart when warned, then rerun the check. Supported items can converge while unsupported items remain; inspect the `Unsupported` list as well as the feature/capability states.

**Click to Do removal is unsupported on the inspected build.** Its protected `MicrosoftWindows.Client.CoreAI` package is retained. A standalone `ClickToDo` optional feature can be serviced if Windows exposes that exact feature; otherwise the helper warns explicitly. It does not substitute disabling or patch the Appx database.

For detailed component state, use Windows PowerShell 5.1 as administrator:

```powershell
.\system\windows\scripts\RemoveOptionalComponents.ps1 -Operation Get
```

Recall policies are limited to Windows 11 24H2 with KB5055627 or later. The component helper records original state before setting `AllowRecallEnablement=0` and requesting removal through servicing. It still reports disabled-only or restart-pending states rather than assuming the payload disappeared. Recall changes can delete snapshots; re-enabling the component does not recover them. Unsupported Click to Do policies and other AI frameworks are not changed.

## Restoration

Privacy and graphics save each touched registry value before its first change and preserve that snapshot across reruns:

- User journals: `%LOCALAPPDATA%\dotfiles\rollback\privacy-user.json` and `graphics-user.json`.
- Machine journals: `%ProgramData%\dotfiles\rollback\privacy-machine.json` and `graphics-machine.json`.

Run user restoration in normal PowerShell 7 and machine restoration in administrator PowerShell 7:

```powershell
.\system\windows\scripts\Privacy.ps1 -Operation Restore -Context User
.\system\windows\scripts\Privacy.ps1 -Operation Restore -Context Machine
```

`Graphics.ps1` supports the same operations. Its user restore changes only the windowed-game token, preserving later VRR/HDR changes. Restart after restoring machine graphics settings. Change the desired configuration before applying again, or bootstrap will reapply it.

The first optional-component inventory before removal is saved to `%ProgramData%\dotfiles\rollback\components.json`. Reinstall recorded capabilities with `Add-WindowsCapability -Online -Name <exact-name>` and features with `Enable-WindowsOptionalFeature -Online -FeatureName <exact-name> -All`, using the original state to choose what to restore. Windows Update or installation media may be needed. Reinstall Store apps from their original Store listings. Registry restoration does not reinstall software, and these helpers do not back up app data or Recall snapshots.

The original Recall enablement policy is recorded separately in `components-registry.json` in that directory. Restore or remove `AllowRecallEnablement` according to that recorded state before attempting to reinstall Recall; restore the snapshot policy with the privacy helper as well. Existing journal entries are preserved when newly installed components are discovered on later runs.

## Graphics verification

Windowed-game optimization requires Windows 11 22H2 or later. Only `SwapEffectUpgradeEnable` is changed; HDR, VRR, and per-app preferences remain intact.

GPU scheduling is checked against fresh DxDiag `HardwareSchedulingAttributes`. Unknown/unsupported capabilities fail without a setting change. `Enabled` means the driver reports active scheduling. `RestartPending` means enablement was requested but is not yet observed active. Test accepts an already-requested change to avoid repeated writes and emits a restart warning; it does not prove activation. Recheck after restarting:

```powershell
.\system\windows\scripts\Graphics.ps1 -Operation Get -Context Machine
```

The inspected Arc B390 driver already reports active scheduling. No FPS improvement is claimed.

## Visual preferences

The `preferences` module disables only the Windows minimize/restore animation preference using [SPI_SETANIMATION and ANIMATIONINFO](https://learn.microsoft.com/windows/win32/api/winuser/ns-winuser-animationinfo). The journal retains its original `MinimizeMaximize` name. Transparency is explicitly enabled. Client-area, taskbar, menu, combo-box, list-box scrolling, selection-fade, and tooltip preferences are otherwise unmanaged. Komorebi's own movement animations remain disabled in its existing configuration. App opening/closing behavior has not been verified; this setting is not a promise to suppress every app's transitions.

When upgrading from the earlier broad animation preset, Set first restores those other preferences from `visual-effects-user.json` and removes only the consumed rollback entries. Test reports false while that migration is pending, even if window animations and transparency already match. Fresh setups without those records leave other animation choices untouched. Font smoothing, hover highlighting, and the existing shadow preferences are retained.

The helper persists and broadcasts these preferences, then reads them back. Applications that cache appearance settings may need reopening or a sign-out; it does not restart Explorer automatically. Apply or inspect only this setting from normal PowerShell 7:

```powershell
.\system\windows\scripts\VisualEffects.ps1 -Operation Set
.\system\windows\scripts\VisualEffects.ps1 -Operation Get
```

Original window-animation and touched transparency values are saved before their first change in `%LOCALAPPDATA%\dotfiles\rollback\visual-effects-user.json`. Restore them with `VisualEffects.ps1 -Operation Restore`, which also restores any unconsumed records from the older broad preset. Change bootstrap's desired configuration before applying again if you want to retain the restored choices.

## Startup audit

`AuditStartup.ps1` collects startup entries, non-Microsoft-path scheduled tasks, automatic services, and a short CPU sample without changing them:

```powershell
.\system\windows\AuditStartup.ps1 | ConvertTo-Json -Depth 7 | Set-Content startup-audit.json
```

Reports contain local paths and account information; do not commit them. A task author is not signature verification, and a short CPU sample cannot establish sustained cost. Investigate dependencies before proposing changes. Samsung controls, phone integration, and desktop tools stay intact.

## Samsung power comparison

No supported unattended Samsung mode-setting interface was identified. Mode selection remains manual in Samsung Settings under Battery and performance. The comparison helper records repeated runs without changing settings:

1. While plugged in, record the original Samsung and Windows modes and choose a repeatable workload.
2. Run `MeasurePowerMode.ps1 -ModeLabel Baseline -Workload { <your workload> }`.
3. Select Samsung performance mode manually and repeat the identical workload with `-ModeLabel Performance`.
4. Compare medians and spread; record fan/heat behavior separately. Restore the original Samsung mode before returning to battery.

The helper checks AC power before and after every run. Its mode label is supplied by the operator, not independently verified. A live comparison remains outstanding; the helper and procedure do not establish a performance benefit. Driver/firmware work, project moves, Dev Drive, scanning exclusions/antivirus performance tuning, WSL limits, VRR enablement, and Process Lasso remain excluded. Selected Explorer preferences and Defender protection controls are described above.

## Focused checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\Debloat.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\OptionalComponents.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\FastfetchWsl.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\PrivacyGraphics.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\SelectedPreferences.Tests.ps1
```

Fixtures isolate system mutations and use temporary files. They do not uninstall apps, write real registry settings, or start real WSL distributions. The Fastfetch fixture requires Fastfetch to be installed.
