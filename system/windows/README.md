# Windows setup and recovery

Run `Configure.ps1` from a normal PowerShell 7 window. WinGet requests elevation for machine resources; user-scope desktop removals remain unelevated.

## Modules

The existing `packages`, `preferences`, and `startup` modules are followed by `privacy`, `graphics`, and `debloat` during bootstrap. Applying all modules installs packages first and removes apps last. Use `-Module privacy`, `-Module graphics`, or `-Module debloat` for a check; add `-Action Apply` to change the machine.

`privacy` configures user advertising, recommendations, welcome/setup prompts and recording settings, plus machine diagnostic-data level, Widgets, update sharing, and supported Recall policies. It does not depend on the Enterprise-only `DisableWindowsConsumerFeatures` policy. Diagnostics use required data (`AllowTelemetry=1`), not a claim of zero telemetry. Delivery Optimization uses mode `0` and retains the update services.

Windows Pro also lacks support for the broad `DisableConsumerAccountStateContent` policy. The helper reports this limitation; user suggestion settings are applied, but removal of every Microsoft 365 card in Settings Home is not guaranteed. Game Bar's controller launch is disabled without replacing its URL handlers with unrelated programs.

## App and component removal

Additional exact app identities cover Solitaire, Dev Home, Get Help, Windows Web Experience, Widgets Platform Runtime, standalone Copilot, and Microsoft 365 Office Hub. Phone Link, Cross Device, actual Office applications, animations, transparency, Defender, WSL, and shared codecs are not targeted.

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

The helper checks AC power before and after every run. Its mode label is supplied by the operator, not independently verified. A live comparison remains outstanding; the helper and procedure do not establish a performance benefit. Driver/firmware work, project moves, Dev Drive, Defender tuning, WSL limits, Explorer-folder tweaks, VRR enablement, and Process Lasso remain excluded.

## Focused checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\Debloat.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\OptionalComponents.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\FastfetchWsl.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\PrivacyGraphics.Tests.ps1
```

Fixtures isolate system mutations and use temporary files. They do not uninstall apps, write real registry settings, or start real WSL distributions. The Fastfetch fixture requires Fastfetch to be installed.
