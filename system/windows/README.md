# Windows setup and recovery

Run commands from the repository root in a normal PowerShell 7 window. WinGet requests elevation
for machine resources. For an elevated user-policy resource, approve as the same Windows
account.

## Check or apply settings

```powershell
.\system\windows\Configure.ps1                              # Check all modules
.\system\windows\Configure.ps1 -Module preferences          # Check one module
.\system\windows\Configure.ps1 -Action Apply -Module preferences
```

The default action is `Test`; add `-Action Apply` to change the machine. Applying all modules
installs packages first and removes apps last. Bootstrap also runs these modules.

| Module | Purpose |
| --- | --- |
| `packages` | Install Windows apps and development tools |
| `preferences` | Desktop, Explorer, input, selected privacy, and Defender settings |
| `startup` | Start desktop tools at sign-in |
| `privacy` | Promotions, diagnostic data, recording, and update sharing |
| `graphics` | Windowed-game optimization and supported GPU scheduling |
| `debloat` | Remove selected apps and optional components |

## Details by task

| I want to… | Read |
| --- | --- |
| Understand settings and verify their effect | [Preferences and verification](preferences.md) |
| Review removed apps, component limits, or restart handling | [App and component removal](debloat.md) |
| Restore earlier settings or run manual audits | [Recovery and manual checks](recovery.md) |

Some appearance changes need an app restart or sign-out. GPU scheduling and component servicing
can need a Windows restart. Check the helper's output and rerun the check afterward; setup does
not restart Windows automatically.

## Focused checks


```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\Debloat.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\OptionalComponents.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\system\windows\tests\FastfetchWsl.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\PrivacyGraphics.Tests.ps1
pwsh.exe -NoProfile -File .\system\windows\tests\SelectedPreferences.Tests.ps1
```

Fixtures isolate system mutations and use temporary files. They do not uninstall apps, write
real registry settings, or start real WSL distributions. The Fastfetch fixture requires
Fastfetch to be installed.
