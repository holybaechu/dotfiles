# Recovery and manual checks

[Windows guide](README.md) · [Preferences](preferences.md) · [App removal](debloat.md)

Run commands from the repository root. Change the desired configuration before applying
again, or setup will reapply it. Selected desktop/privacy preferences have no rollback journal.

## Privacy and graphics

Original registry values are saved before the first change:

| Scope | Journal directory | Files |
| --- | --- | --- |
| User | `%LOCALAPPDATA%\dotfiles\rollback` | `privacy-user.json`, `graphics-user.json` |
| Machine | `%ProgramData%\dotfiles\rollback` | `privacy-machine.json`, `graphics-machine.json` |

Run user restoration in normal PowerShell 7 and machine restoration as administrator:

```powershell
.\system\windows\scripts\Privacy.ps1 -Operation Restore -Context User
.\system\windows\scripts\Privacy.ps1 -Operation Restore -Context Machine
```

Use `Graphics.ps1` for the same operations. Restart after restoring machine graphics settings.

## Components and apps

Original component states are in `%ProgramData%\dotfiles\rollback\components.json`.
Restore only recorded components that were previously installed, as administrator:

```powershell
Add-WindowsCapability -Online -Name <exact-name>
Enable-WindowsOptionalFeature -Online -FeatureName <exact-name> -All
```

Windows Update or installation media may be needed. Before reinstalling Recall, restore
`AllowRecallEnablement` from `components-registry.json` and its snapshot policy with the
privacy helper. Reinstall apps through Store or their original installers.
Journals do not back up app data or Recall snapshots.

## Restore appearance

Run in normal PowerShell 7:

```powershell
.\system\windows\scripts\VisualEffects.ps1 -Operation Restore
```

Journal: `%LOCALAPPDATA%\dotfiles\rollback\visual-effects-user.json`.
Restoration includes remaining records from the older broad animation preset.

## Audit startup

Collect startup entries, tasks, services, and a short CPU sample without changing settings:

```powershell
.\system\windows\AuditStartup.ps1 | ConvertTo-Json -Depth 7 | Set-Content startup-audit.json
```

Reports contain account information and local paths; keep them out of Git.
A short CPU sample does not establish sustained cost.

## Samsung power comparison

Mode selection is manual in **Samsung Settings → Battery and performance**.

1. Plug in, record the original modes, and choose a repeatable workload.
2. Run `MeasurePowerMode.ps1 -ModeLabel Baseline -Workload { <your workload> }`.
3. Select Samsung performance mode and repeat with `-ModeLabel Performance`.
4. Compare medians and spread; note heat/fan behavior. Restore the original mode before using battery.

The helper checks AC power but does not verify the mode label.
