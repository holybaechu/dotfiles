# Recovery and manual checks

[Windows guide](README.md) · [Preferences](preferences.md) · [App removal](debloat.md)

Commands run from the repository root. The selected desktop/privacy preferences have no new
rollback journals; the journals below belong to the earlier helpers.

## Restore privacy and graphics

Privacy and graphics save each touched registry value before its first change and preserve that
snapshot across reruns:

- User journals: `%LOCALAPPDATA%\dotfiles\rollback\privacy-user.json` and `graphics-user.json`.
- Machine journals: `%ProgramData%\dotfiles\rollback\privacy-machine.json` and `graphics-machine.json`.

Run user restoration in normal PowerShell 7 and machine restoration in administrator PowerShell
7:

```powershell
.\system\windows\scripts\Privacy.ps1 -Operation Restore -Context User
.\system\windows\scripts\Privacy.ps1 -Operation Restore -Context Machine
```

`Graphics.ps1` supports the same operations. Its user restore changes only the windowed-game
token, preserving later VRR/HDR changes. Restart after restoring machine graphics settings.
Change the desired configuration before applying again, or bootstrap will reapply it.

## Restore optional components and apps

The first optional-component inventory before removal is saved to
`%ProgramData%\dotfiles\rollback\components.json`.

Reinstall recorded capabilities with `Add-WindowsCapability -Online -Name <exact-name>` and
features with `Enable-WindowsOptionalFeature -Online -FeatureName <exact-name> -All`, using the
original state to choose what to restore.

Windows Update or installation media may be needed. Reinstall Store apps from their original
Store listings. Registry restoration does not reinstall software, and these helpers do not back
up app data or Recall snapshots.

The original Recall enablement policy is recorded separately in `components-registry.json` in
that directory. Restore or remove `AllowRecallEnablement` according to that recorded state
before attempting to reinstall Recall; restore the snapshot policy with the privacy helper as
well. Existing journal entries are preserved when newly installed components are discovered on
later runs.

## Restore appearance

Run from the repository root in normal PowerShell 7:

```powershell
.\system\windows\scripts\VisualEffects.ps1 -Operation Restore
```

The journal is `%LOCALAPPDATA%\dotfiles\rollback\visual-effects-user.json`. Restore includes any
unconsumed records from the older broad animation preset. Change bootstrap's desired
configuration before applying again to retain the restored choices; see
[Appearance](preferences.md#appearance) for migration details.

## Audit startup

`AuditStartup.ps1` collects startup entries, non-Microsoft-path scheduled tasks, automatic
services, and a short CPU sample without changing them:

```powershell
.\system\windows\AuditStartup.ps1 | ConvertTo-Json -Depth 7 | Set-Content startup-audit.json
```

Reports contain local paths and account information; do not commit them. A task author is not
signature verification, and a short CPU sample cannot establish sustained cost. Investigate
dependencies before proposing changes. Samsung controls, phone integration, and desktop tools
stay intact.

## Compare Samsung power modes

No supported unattended Samsung mode-setting interface was identified. Mode selection remains
manual in Samsung Settings under Battery and performance. The comparison helper records repeated
runs without changing settings:

1. While plugged in, record the original Samsung and Windows modes and choose a repeatable workload.
2. Run `MeasurePowerMode.ps1 -ModeLabel Baseline -Workload { <your workload> }`.
3. Select Samsung performance mode manually and repeat the identical workload with `-ModeLabel Performance`.
4. Compare medians and spread; record fan/heat behavior separately. Restore the original Samsung mode before returning to battery.

The helper checks AC power before and after every run. Its mode label is supplied by the
operator, not independently verified. A live comparison remains outstanding; the helper and
procedure do not establish a performance benefit. Driver/firmware work, project moves, Dev
Drive, scanning exclusions/antivirus performance tuning, WSL limits, VRR enablement, and Process
Lasso remain excluded. See [Preferences](preferences.md) for Explorer and Defender controls.
