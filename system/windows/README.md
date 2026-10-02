# Windows setup

Run from the repository root in normal PowerShell 7. WinGet requests elevation
for machine resources; approve user-policy elevation as the same Windows account.

```powershell
.\system\windows\Configure.ps1                              # Check all modules
.\system\windows\Configure.ps1 -Module preferences          # Check one module
.\system\windows\Configure.ps1 -Action Apply -Module preferences
```

Bootstrap runs these modules, installing packages before removing apps.
After applying dotfiles, bootstrap installs Bun, Node, and uv through mise;
see [runtime maintenance](../../docs/maintenance.md#updates).

| Module | Purpose |
| --- | --- |
| `packages` | Install Windows apps and development tools |
| `preferences` | Desktop, Explorer, input, selected privacy, and Defender settings |
| `startup` | Start desktop tools at sign-in |
| `privacy` | Promotions, diagnostic data, recording, and update sharing |
| `graphics` | Windowed-game optimization and supported GPU scheduling |
| `debloat` | Remove selected apps and optional components |

## Guides

- [Preferences](preferences.md)
- [App removal](debloat.md)
- [Recovery and manual checks](recovery.md)

## Focused checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\Debloat.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\OptionalComponents.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\FastfetchWsl.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\PrivacyGraphics.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\SelectedPreferences.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\AsideBrowser.Tests.ps1
```

Fixtures isolate system changes; they do not uninstall apps, write real registry settings,
or start real WSL distributions.
