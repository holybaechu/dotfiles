# Windows debloating and optimization suggestions for these dotfiles

Researched **2026-10-01 (Asia/Seoul)**. This is a source-based research document, not an applied configuration. No third-party optimization scripts were executed and no Windows settings were changed.

Read: [prioritized additions](#prioritized-additions) · [optional choices](#optional-choices-with-defaults-left-alone-until-selected) · [exclusions](#changes-to-exclude-from-these-dotfiles) · [implementation](#how-to-implement-the-selected-suggestions-later) · [complete inventories](#complete-configuration-and-public-feature-inventories).

## Recommended direction

Extend the existing explicit app-removal and DSC preferences with a small set of independently testable settings. The most useful additions are Windows promotion controls, local-only search, selected Windows AI controls, long-path support, and Windows snapping controls that fit komorebi. Keep operating-system security, servicing, WSL networking, input, and laptop power management intact.

Use **Win11Debloat for focused registry references**, **WinUtil for its broader feature catalogue**, **Sophia Script for selective function and recovery ideas**, and **ReviOS as a source of individual ideas and dependency lessons**. A complete WinUtil preset or ReviOS playbook is a poor fit for this repository's deliberately small, readable provisioning modules. These judgments are recommendations based on the source and your configuration, not measured performance results.

## Scope and reproducibility

The research used local shallow checkouts of the actual upstream repositories. It inventoried configuration entries and public functions, inspected the implementation of relevant settings and side effects, and followed ReviOS's dependency chain into Revision Tool and the separate component-package repository. It did not rely on website feature summaries.

| Project | Examined commit | Commit timestamp (upstream offset) |
| --- | --- | --- |
| Windows Utility | [9c87c02fdb9e](https://github.com/ChrisTitusTech/winutil/commit/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f) | 2026-09-30T10:37:17-05:00 |
| ReviOS playbook | [b6c1cd400f24](https://github.com/meetrevision/playbook/commit/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30) | 2026-09-21T08:26:10+04:00 |
| Revision Tool | [a0254925ce1a](https://github.com/meetrevision/revision-tool/commit/a0254925ce1afe9a4e18e3a1880f420d02f65e4d) | 2026-09-25T17:59:29+04:00 |
| ReviOS component packages | [3c2231a16c5e](https://github.com/meetrevision/packages/commit/3c2231a16c5e7df18a70bffbc5702c5d077cab12) | 2026-09-24T14:34:14+04:00 |
| Win11Debloat | [32024662f3c6](https://github.com/Raphire/Win11Debloat/commit/32024662f3c602442e7af82bbf52c89143b31aeb) | 2026-09-10T17:48:43+02:00 |
| Sophia Script | [4a89b522eab3](https://github.com/farag2/Sophia-Script-for-Windows/commit/4a89b522eab3ad0b106003fe5b791530c8d1f3a1) | 2026-09-29T23:15:47+03:00 |


These are default-branch snapshots, which can be newer than published stable releases. Links below pin the examined commits. ReviOS downloads Revision Tool and component packages from **latest releases**, so a pinned playbook alone does not pin the resulting installation. Source definitions establish intended behavior; they do not prove every action works on every Windows build, edition, or hardware configuration.

Inventory coverage:

- **WinUtil:** all 67 entries in `config/tweaks.json`, all 33 entries in `config/feature.json`, 34 AppX catalogue entries, four presets, eight DNS providers, and the operations implemented outside those catalogues. Its 236 application entries are an installation catalogue, not 236 optimization features.
- **ReviOS:** the option manifest, orchestration, every task YAML file, executable helpers, Revision Tool's five tweak service families and additional Store/CAB features, and all ten AMD64/ARM64 component-package manifests. Active changes, selectable options, commented-out examples, upgrade reversions, and helper files are distinguished.
- **Win11Debloat:** all 103 feature definitions, their registry-file mappings and build gates, app definitions/presets, user targeting, state detection, backup/restore, and execution helpers.
- **Sophia Script:** all 120 public functions in the Windows 11 PowerShell 7 module, with selected implementations and the preset inspected. Windows 10, LTSC, ARM, and Windows PowerShell variants exist; this report inventories the Windows 11 PowerShell 7 branch relevant to your setup rather than treating those variants as identical.

This is a comprehensive inventory of those exposed configuration/function surfaces, not an exhaustive line-by-line audit of all UI, tests, build tooling, or third-party binaries. The inventories at the end are reference material; presence in them is not a recommendation to enable an item.

## What your dotfiles already cover

The baseline is `holybaechu/dotfiles` at `9057e77895cdeb5b6699feefe372ce521d39ea4f`, with a clean working tree at the start of research.

| Existing behavior | Repository evidence | Implication |
| --- | --- | --- |
| Explicit removals of Family, Bing Search, Clipchamp, Teams, To Do, new Outlook, Power Automate, Start Experiences, recorder, Xbox components, Weather, News, Media Player, Quick Assist, Sticky Notes, Feedback Hub; desktop OneDrive/classic Teams/Power Automate/Edge | [system/windows/scripts/Debloat.ps1](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/scripts/Debloat.ps1); [system/windows/debloat.winget](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/debloat.winget) | Do not introduce a second overlapping removal engine. Your exact identities, deprovisioning, re-inventory, failure reporting, and privilege split are already valuable. |
| Store, frameworks/codecs, Start Menu, WebView2 and Edge updater retained; PotPlayer and browsers installed before removals | [README.md](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/README.md); [system/windows/Configure.ps1](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/Configure.ps1) | Keep these dependencies and replacement checks. Uninstalling an app and disabling its surrounding policies are separate tasks. |
| Windows Search service disabled; Everything supplies file search | [system/windows/preferences.winget](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/preferences.winget) | Already covers indexing overhead. Web search/highlights can still be addressed separately. Avoid importing indexing tweaks that undo this choice. |
| File extensions/hidden files shown, desktop icons hidden, mouse acceleration/window shadows disabled, taskbar auto-hide enabled | [system/windows/preferences.winget](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/preferences.winget) | Existing coverage; no need to duplicate upstream settings. |
| komorebi animation disabled; AltSnap integrates with komorebi; Canopy handles desktop status and controls | [home/dot_config/komorebi/komorebi.json](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/home/dot_config/komorebi/komorebi.json); [home/AppData/Roaming/AltSnap/AltSnap.ini](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/home/AppData/Roaming/AltSnap/AltSnap.ini); [apps/yasb/canopy/backend.py](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/apps/yasb/canopy/backend.py) | Prefer reducing Windows snapping interference over stripping out shell, audio, brightness, network or Bluetooth support. |
| Arch WSL2, PowerShell 7, Windows Terminal, Neovim/LLVM, uv, GitHub CLI, 1Password SSH integration, YubiKey tools | [README.md](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/README.md); [system/windows/packages.winget](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/packages.winget); [system/wsl/Setup.ps1](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/wsl/Setup.ps1) | Development, virtual networking, signing/authentication and input compatibility outweigh lower process counts. Windows `ssh-agent` is intentionally disabled because 1Password owns its pipe. |
| `.chezmoiroot` is `home`; system provisioning is separate from `chezmoi apply` | [.chezmoiroot](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/.chezmoiroot); [system/windows/Configure.ps1](https://github.com/holybaechu/dotfiles/blob/9057e77895cdeb5b6699feefe372ce521d39ea4f/system/windows/Configure.ps1) | Put machine settings in `system/windows`, leaving application-native configuration in `home`. |

## Prioritized additions

**P1** means a strong candidate for the next small change; **P2** means useful after verifying the stated behavior. These are proposed defaults for this repository, not guarantees of speed or universal compatibility.

| Priority | Suggestion and concrete scope | Why it fits / caveat | Where to implement | Source evidence |
| --- | --- | --- | --- | --- |
| P1 | Disable welcome/tip/finish-setup prompts, suggested app installs, Explorer sync-provider promotions and account-related promotional notifications | Complements app removal without disabling ordinary application notifications. Prefer narrowly scoped per-user settings; validate consumer-feature policies by edition. | Extend `preferences.winget` through a small `scripts/WindowsPromotions.ps1` Get/Test/Set helper. | [Regfiles/Disable_Windows_Suggestions.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Windows_Suggestions.reg); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`WindowsTips`, `AppsSilentInstalling`, `WindowsWelcomeExperience`, `StartAccountNotifications`); [src/Configuration/Tasks/registry/privacy/cdm.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/cdm.yml) |
| P1 | Disable Bing/web search, cloud suggestions and search highlights | Canopy + Everything already serve local search. Removing `Microsoft.BingSearch` does not itself configure every search policy. Preserve local shell/search components. | A focused per-user search resource in `preferences.winget`. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFToggleBingSearch`); [Regfiles/Disable_Bing_Cortana_In_Search.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Bing_Cortana_In_Search.reg); [src/Configuration/Tasks/registry/explorer/search.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/search.yml) |
| P1 | Disable Windows Widgets policy and hide taskbar Search/Task View/remaining Chat surfaces | Fits Canopy and taskbar auto-hide. Start with policies/UI values; remove Web Experience packages only as a later explicit choice. Existing Teams removal handles much of Chat. | `preferences.winget`; separate AppX identities in `Debloat.ps1` only if removal is selected. | [Scripts/Features/Invoke-Changes.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Invoke-Changes.ps1); [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksWidget`, taskbar toggles); [src/Configuration/Tasks/registry/explorer/taskbar.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/taskbar.yml) |
| P1 | Disable native Snap Assist, maximize-button/top-edge Snap Layout suggestions and optionally Windows dragging-to-snap | Reduces overlap with komorebi + AltSnap. Verify floating windows and Win+arrow behavior before deciding whether to disable snapping entirely. | Extend `preferences.winget` with separate values rather than one blanket “performance” switch. | [Regfiles/Disable_Snap_Assist.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Snap_Assist.reg); [Regfiles/Disable_Snap_Layouts.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Snap_Layouts.reg); [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFToggleWindowSnapping`); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`SnapAssist`) |
| P1 | Enable Win32 long paths (`LongPathsEnabled=1`) | Useful for deeply nested repositories and development tooling. Applications still need long-path support; the policy alone does not make all Explorer/app paths unlimited. | Elevated resource in `preferences.winget`. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFToggleLongPaths`); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`Win32LongPathsSupport`); [Microsoft requirements](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation) |
| P1 | Stop Windows activity publication/upload and disable advertising ID/tailored experiences | Add narrowly scoped privacy controls. WinUtil intentionally leaves `EnableActivityFeed=1` while setting publish/upload to zero; preserve clipboard history and verify Win+V. Treat diagnostic-data settings separately. | Small privacy helper referenced from `preferences.winget`, or a separate `privacy.winget` if the group grows. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksActivity`, `WPFTweaksTelemetry`); [Regfiles/Disable_Telemetry.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Telemetry.reg) |
| P1 | Offer granular Windows AI controls: disable Recall recording/enablement where supported, remove the standalone Microsoft Copilot app by exact identity if unwanted, and disable Notepad/Paint AI separately | Your repo uses **GitHub Copilot in Neovim**, which should remain a separate decision. Avoid WinUtil's wildcard `*Copilot*` removal and CoreAI EndOfLife edits. Read edition/build gates; the old `TurnOffWindowsCopilot` policy does not cover the new standalone experience. | Exact optional entries in `Debloat.ps1` plus supported policy resources in `preferences.winget`. | [Regfiles/Disable_AI_Recall.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_AI_Recall.reg); [Regfiles/Disable_Notepad_AI_Features.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Notepad_AI_Features.reg); [Regfiles/Disable_Paint_AI_Features.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Paint_AI_Features.reg); [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksWindowsAI` implementation); [Microsoft WindowsAI policies](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai) |
| P2 | Prevent automatic device companion-app downloads using `PreventDeviceMetadataFromNetwork` | Blocks an unwanted software-install path while preserving driver installation. Hardware vendor configuration utilities may need manual installation. Do not conflate it with blocking all Windows Update drivers. | Elevated resource in `preferences.winget`. | [Regfiles/Disable_Device_Auto_App_Download.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Device_Auto_App_Download.reg); [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksPreventDeviceMetadataFromNetwork`) |
| P2 | Set `POWERSHELL_TELEMETRY_OPTOUT=1` and, if you use .NET CLI, `DOTNET_CLI_TELEMETRY_OPTOUT=1` | Small, tool-specific opt-outs observed in ReviOS. Save user environment variables, refresh the process environment, and document that already running tools need restarting. | Environment-variable resources following the existing `KomorebiConfigHome` pattern. | [src/Configuration/Tasks/final.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/final.yml) |
| P2 | Disable WinGet telemetry through its native `telemetry.disable` setting | ReviOS ships this setting too. Merge that field into the intended user's existing settings; do not overwrite unrelated sources or installer preferences. | A native partial-file configuration under `home`, using the repository's existing template conventions. | [src/Executables/settings.json](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/settings.json); [src/Executables/STARTMENU.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/STARTMENU.cmd) |
| P2 | Disable Game DVR/background capture after Xbox/Game Bar removal | Makes the retained policy match your explicit removal choice. Keep Windows Game Mode and graphics optimizations at their defaults unless separately tested. | Elevated/user recording-policy resources in `preferences.winget`. | [Regfiles/Disable_DVR.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_DVR.reg); [Regfiles/Disable_Game_Bar_Integration.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Game_Bar_Integration.reg); [src/Configuration/Tasks/packages/appx.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/appx.yml) |
| P2 | Disable the Sticky Keys **shortcut** if it interrupts repeated Shift use | Fits keyboard-heavy workflows. Do not remove accessibility registry trees or disable features someone relies on; preserve the ability to turn the feature on manually. | Per-user preference; inspect flags and current state. | [Regfiles/Disable_Sticky_Keys_Shortcut.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Sticky_Keys_Shortcut.reg); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`StickyShift`) |
| P2 | Add targeted original-state backup before new privacy/policy groups | Win11Debloat records pre-change registry state, offering a stronger model than “undo to presumed Windows defaults.” Record value presence, type and data, with the intended user SID. | A small explicit backup operation only for changed keys; keep snapshots outside Git. | [Scripts/Features/Backup-RegistryState.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Backup-RegistryState.ps1); [Scripts/Features/Backup-RegistrySnapshotCapture.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Backup-RegistrySnapshotCapture.ps1); [Scripts/Features/Restore-RegistryBackup.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Restore-RegistryBackup.ps1) |

## Optional choices, with defaults left alone until selected

| Candidate | Recommended treatment | Evidence |
| --- | --- | --- |
| Explorer opens to This PC; hide Home/Gallery; compact view; reduce recent/frequent files | Personal preference. Useful with Everything, but changes convenience rather than CPU performance. Scope changes to current user and preserve saved views. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [src/Configuration/Tasks/registry/explorer/explorer.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/explorer.yml); [Config/Features.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Features.json) |
| Disable automatic folder-type discovery | Use only for demonstrably slow large folders. WinUtil deletes `Bags` and `BagMRU`, resetting saved views; its undo also resets them. Do not do that on every provisioning rerun. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksDisableExplorerAutoDiscovery`) |
| Disable selected Windows animations/transparency | Your komorebi animation and window-shadow preferences already cover part of this. Use individual UI preferences and keep font smoothing/readability. Measure whether additional settings help. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksDisplay`); [Regfiles/Disable_Animations.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Animations.reg) |
| Classic context menu, taskbar End Task, Alt+Tab windows only, always-visible scrollbars, dark mode | Small independent preference candidates. End Task is less central with the taskbar hidden; document its unsaved-work consequence. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [Config/Features.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Features.json) |
| Remove Dev Home, Office Hub, Solitaire, Get Started, legacy Mail/Calendar, old Maps/Skype/3D Viewer | Expand exact removal identities only after checking actual inventory and usage. Keep Calculator, Camera, Photos, Notepad, Paint, Phone Link/CrossDevice until an explicit preference and replacement exist. | [config/appx.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/appx.json); [src/Configuration/Tasks/packages/appx.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/appx.yml); [Config/Apps.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Apps.json) |
| Prevent unwanted new Outlook return paths | Your deprovisioning is already the main supported Windows 11 approach. Microsoft says updated 23H2 respects it; `BlockedOobeUpdaters` is documented for Windows 10, so do not import that ReviOS value indiscriminately on Windows 11. Removing legacy Mail/Calendar, if present and unused, also closes its migration path. | [src/Configuration/Tasks/registry/updates/updates.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/updates/updates.yml); [Microsoft installation controls](https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/control-install#block-new-outlook-preinstallation-on-windows) |
| Reduce optional diagnostic data / disable DiagTrack | Privacy choice, separate from security and logging. Use edition-aware settings; diagnostic data off is supported only on Enterprise/Education/Server, so `AllowTelemetry=0` is not a universal zero-telemetry guarantee. Retain crash dumps and local event logs. | [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`DiagnosticDataLevel`); [Microsoft supported behavior](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system#allowtelemetry) |
| Disable internet peer-to-peer update uploads | Prefer a supported HTTP-only Delivery Optimization download mode, retaining Windows Update/Store servicing. Do not disable BITS or the Delivery Optimization service as a substitute. | [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json) (`WPFTweaksDeliveryOptimization`); [Regfiles/Disable_Delivery_Optimization.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Delivery_Optimization.reg) |
| Update active hours/restart notifications; avoid preview updates; optional driver exclusion | Sensible maintenance preferences after build/edition verification. Keep quality/security updates enabled. Driver exclusion needs an alternative maintenance plan; skip WinUtil's bundled 365-day feature/4-day quality deferrals unless deliberately chosen. | [functions/public/Invoke-WPFUpdatessecurity.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFUpdatessecurity.ps1); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`ActiveHours`, `RestartNotification`, `WindowsLatestUpdate`); [Config/Features.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Features.json) |
| Disable Fast Startup, keep hibernation available | Potential troubleshooting preference. WSL is not Linux dual boot, so the usual dual-boot argument does not establish a need here. Evaluate boot/wake behavior on this hardware. | [src/lib/features/tweaks/utilities/utilities_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/utilities/utilities_service.dart); [Regfiles/Disable_Fast_Startup.reg](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles/Disable_Fast_Startup.reg) |
| Location / Find My Device / online speech / typing personalization | Separate opt-in privacy decisions with functional costs. Find My Device can be useful on a laptop; preserve text input/IME. | [Config/Features.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Features.json); [src/lib/features/tweaks/personalization/personalization_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/personalization/personalization_service.dart) |
| DNS over HTTPS or a selected filtering resolver | Optional network preference. Scope to selected physical adapters, retain DHCP/previous configuration for rollback, and test VPN/local DNS and WSL. WinUtil's “Fastest” measures TCP connection latency to port 53, not real DNS/DoH query performance. | [config/dns.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/dns.json); [functions/private/Get-WinUtilDNSBenchmark.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Get-WinUtilDNSBenchmark.ps1); [functions/private/Set-WinUtilDNS.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Set-WinUtilDNS.ps1); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`DNSoverHTTPS`) |
| Windows Sandbox | Useful optional development/testing feature on a supported edition. Keep WSL's existing provisioning authoritative rather than importing another WSL installer. | [config/feature.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/feature.json); [Scripts/Features/Windows-OptionalFeatures.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Windows-OptionalFeatures.ps1) |
| Restore point / targeted backup / environment report / troubleshooting entry points | Run explicitly before a risky change or during a problem. A restore point is not a complete backup of removed apps or their data. Environment reports need a privacy review before sharing. Repair/update/network resets should not run automatically during every bootstrap. | [functions/public/Invoke-WPFExportEnvironmentReport.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFExportEnvironmentReport.ps1); [functions/public/Invoke-WPFSystemRepair.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFSystemRepair.ps1); [Scripts/Features/Invoke-SystemRestorePoint.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Invoke-SystemRestorePoint.ps1) |
| Defender PUA protection, network protection, SmartScreen/LSA hardening | Consider as a separate security configuration, not a debloat/performance preset. Sophia exposes useful controls; verify compatibility and support before enabling additional protection. | [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1) (`PUAppsDetection`, `NetworkProtection`, `AppsSmartScreen`, `LocalSecurityAuthority`) |

## Changes to exclude from these dotfiles

| Exclude | Source-level reason and implication |
| --- | --- |
| WinUtil `WPFTweaksServices` wholesale, including its Minimal preset | The five service entries include `SharedAccess=Disabled`, not just “manual.” Microsoft identifies ICS/SharedAccess as a WSL2 dependency and recommends its default Manual (Trigger Start). The preset also sets `SvcHostSplitThresholdInKB` to installed RAM. Lower process count is not evidence of faster work. [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [config/preset.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/preset.json); [Microsoft WSL troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#wsl-2-errors-when-ics-is-disabled) |
| ReviOS's full service list/grouping | It disables DAM, GPU energy driver, NetBT, diagnostic/compatibility services and UCPD, and changes other startup modes. Keep existing WSearch/ssh-agent exceptions, but do not generalize them to a generic services preset. ReviOS's upgrade rollback itself documents grouping and driver regressions. [src/Configuration/Tasks/services.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/services.yml); [src/Configuration/Tasks/revert.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/revert.yml) |
| Disabling Defender, UAC, SmartScreen, VBS/HVCI or CPU vulnerability mitigations as a default | ReviOS's option manifest defaults to disabling Defender; security services expose mitigation, UAC, VBS and memory-integrity controls. This changes the protection model. A development workstation with browsers, plugins and signing/authentication tools should preserve those protections by default. [src/playbook.conf](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/playbook.conf); [src/Configuration/Tasks/registry/security/security.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/security/security.yml); [src/lib/features/tweaks/security/security_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/security/security_service.dart) |
| Disabling BitLocker or automatic encryption | WinUtil's live tweak calls `Disable-BitLocker` on the system drive; this is actual decryption, not just suppression of future auto-encryption. Its ISO helper and ReviOS ISO options also suppress automatic encryption. Preserve encryption and recovery access. [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [functions/private/Invoke-WinUtilISOScript.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Invoke-WinUtilISOScript.ps1); [src/playbook.conf](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/playbook.conf) |
| ReviOS update pause / disabling update services | `final.yml` calls `tweaks patches`; that implementation disables driver updates and enables a pause through **2038-01-19**. WinUtil also has an explicit disable-updates action. Do not reproduce these policies. [src/Configuration/Tasks/final.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/final.yml); [src/lib/features/tweaks/tweaks_command.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/tweaks_command.dart); [src/lib/features/tweaks/updates/updates_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/updates/updates_service.dart); [functions/public/Invoke-WPFUpdatesdisable.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFUpdatesdisable.ps1) |
| Importing WinUtil's Windows 11 Creator post-install script | This path applies fixed changes beyond the ordinary selected tweaks: it suppresses auto-encryption, bypasses hardware checks, changes app/privacy policy, disables update services and deletes task definitions. Keep media preparation separate from normal dotfiles provisioning. [functions/private/Invoke-WinUtilISOScript.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Invoke-WinUtilISOScript.ps1); [tools/autounattend.xml](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/tools/autounattend.xml) |
| ReviOS custom WinSxS removal CABs / protected AppX workarounds | The system-components package includes compatibility appraiser, telemetry/error-reporting, setup/OOBE, demo/legacy media and shell components. The AppX helper can alter NonRemovable policy and EndOfLife/InboxApplications registry state. Your removal script intentionally respects NonRemovable apps. Maintain that boundary. [systemPackages-removal-amd64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/systemPackages-removal-amd64.yaml); [src/Executables/APPX-REMOVER.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/APPX-REMOVER.ps1) |
| Forced Edge removal, WebView2 removal, broad Microsoft-app wildcards | Keep your supported registered-uninstaller approach. WinUtil uses a dummy legacy Edge executable to unlock removal; ReviOS and Win11Debloat contain more forceful methods. Their existence does not establish compatibility for your machine. [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [src/Executables/EDGE.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/EDGE.ps1); [Scripts/AppRemoval/Invoke-ForceRemoveEdge.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/AppRemoval/Invoke-ForceRemoveEdge.ps1) |
| Disable memory compression/SysMain, enable TSX, change NTFS 8.3/last-access/memory allocation | ReviOS actively disables memory compression and 8.3 creation/last-access updates, and enables TSX. These are workload/hardware choices, not demonstrated improvements for WSL + desktop development. Leave defaults; investigate a specific measured bottleneck first. [src/Configuration/Tasks/final.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/final.yml); [src/Configuration/Tasks/registry/system/kernel.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/kernel.yml); [src/lib/features/tweaks/performance/performance_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/performance/performance_service.dart) |
| Ultimate/custom performance plans, CPU C6 changes, forcing S3/Modern Standby off, disabling hibernation universally | Canopy includes battery and power controls; the repo should not assume every installation is a permanently plugged-in desktop. Sleep state support is hardware-dependent, and hibernation is useful on laptops. Keep Balanced/default power behavior unless the user chooses otherwise. [functions/public/Invoke-WPFUltimatePerformance.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFUltimatePerformance.ps1); [src/lib/features/tweaks/performance/performance_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/performance/performance_service.dart); [src/Configuration/Tasks/registry/system/power.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/power.yml) |
| Disable IPv6/Teredo or reset all network adapters automatically | No demonstrated need from the dotfiles. Preserve WSL virtual networking, VPNs, local discovery and existing DNS. Keep network repair as a manual troubleshooting action. [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [functions/public/Invoke-WPFFixesNetwork.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFFixesNetwork.ps1) |
| Disable ctfmon/input services; blanket background-app/notification suppression | Risks text/IME input and useful background features. ReviOS's own rollback re-enables background apps because Game Bar's Known Game List update relies on them. Promotional notification controls are a better fit. [src/lib/features/tweaks/performance/performance_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/performance/performance_service.dart); [src/Configuration/Tasks/revert.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/revert.yml) |
| Clear event logs/dumps, disable crash recovery/automatic disk checks, shorten forced-shutdown timeouts, turn off reserved storage/system restore | Weakens troubleshooting and recovery. ReviOS Cleaner clears event logs, selects dump/driver/update cleanup and disables reserved storage; other tasks alter crash/boot/restore settings. These are not routine preferences. [src/Executables/CLEANER.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/CLEANER.ps1); [src/Configuration/Tasks/registry/system/boot.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/boot.yml); [src/Configuration/Tasks/registry/system/crash-control.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/crash-control.yml); [src/Configuration/Tasks/registry/misc/disable-system-restore-pre-defined-config.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/disable-system-restore-pre-defined-config.yml) |
| Wholesale hosts replacement, Adobe activation-domain blocks, vendor binary/ACL blocks, autologon, install CTT's PowerShell profile | Would override local networking or unrelated application/security choices. Your browsers, shell profile, Starship and startup configuration already have owners. ReviOS copies its entire hosts file; it even comments out a telemetry domain because blocking it breaks a Visual Studio download page. [src/Configuration/Tasks/start.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/start.yml); [src/Executables/hosts](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/hosts); [config/tweaks.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json); [config/feature.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/feature.json) |

## How to implement the selected suggestions later

1. **Keep the current architecture.** Reuse `Configure.ps1` module discovery and the existing PowerShell Get/Test/Set convention. Start by extending `preferences.winget`; add `privacy.winget` only if the settings form a substantial independent group. Do not add a third-party preset runner or a new general framework for this list.
2. **Separate user and machine scope.** HKCU changes run as the intended user; HKLM/service/optional-feature changes use an elevated DSC resource. Keep AppX operations in Windows PowerShell 5.1 and user-scope desktop uninstalls in the normal user session, as the repo already does. Do not write every user's hive or the Default profile without a separate requirement.
3. **Make applicability explicit.** Check Windows build, edition and feature/service presence. A missing unsupported feature should be reported as not applicable, not created as a fictitious service or counted as “optimized.” Win11Debloat's `MinVersion`/`MaxVersion` fields and ReviOS's build/option gates are useful patterns; upstream labels are not evidence that a policy is supported locally.
4. **Make reruns harmless.** Compare effective state, change only what differs, preserve unrelated `SettingsPageVisibility` entries, and use `CurrentControlSet` for live service settings. Avoid recurring deletion of Explorer views, caches, logs, tasks or app data. Keep application and Windows updates as distinct maintenance actions.
5. **Provide real rollback.** For a new registry group, save prior presence/type/value. Restore absence by removing the value instead of inserting an assumed default. Upstream `OriginalValue`/undo functions are useful references but are not snapshots of this user's prior state. App removals require reinstalling apps and may not recover local data.
6. **Use focused verification.** Run the existing configuration Test action, review the rendered diff, then manually check the changed UI and affected workflow. Documentation-only research needs a diff/content review; implementing a routine registry preference does not justify a broad new test suite.

Suggested first implementation batch: promotions + local search + Widgets/taskbar surfaces + long paths. Second batch: snapping and granular AI/privacy choices. Keep optional hardware/performance experiments separate, with before/after evidence and an exact rollback.

Verification for an implemented batch should cover: a second apply with no changes; intended-user HKCU state; local launcher/Everything search; komorebi/AltSnap floating and tiled behavior; Win+V; text input/IME; WSL startup, DNS and localhost networking; Store/WinGet and WebView2; 1Password/YubiKey; Canopy audio/brightness/network/battery controls; Windows Update and Defender; sleep/wake only when power settings changed. A reboot/sign-out should be reported when required rather than forced during provisioning.

## Source findings beyond website feature lists

### Windows Utility

The repository is modular PowerShell plus JSON and WPF XAML, compiled by `Compile.ps1`. `tweaks.json` mixes registry changes, services, arbitrary apply/undo scripts and UI actions; `feature.json` mixes optional features, repairs and Control Panel links. Import/export and `-Preset`/`-Config` automation exist, but they bring upstream ownership/versioning with them. The Standard and even Minimal presets include service changes, making them unsuitable shortcuts here. [Compile.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/Compile.ps1); [functions/private/Invoke-WinUtilTweaks.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Invoke-WinUtilTweaks.ps1); [functions/public/Invoke-WPFImpex.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public/Invoke-WPFImpex.ps1); [config/preset.json](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/preset.json)

Beyond the tweak catalogue, source implements package install/upgrade/uninstall and installed-app detection; AppX removal/reinstall and deprovisioning; Windows Update default/recommended/disabled policies; DNS/DoH selection; Ultimate Performance plan creation/removal; O&O ShutUp10++ launch; Windows Update/network/WinGet/system-file repair; NTP replacement; autologon; OpenSSH server installation; environment/log reports; PowerShell profile installation/removal; and Windows 11 ISO/USB creation with edition selection, optional current-system driver injection and setup customization. These are distinct operations, not all desirable bootstrap defaults. [functions/public](https://github.com/ChrisTitusTech/winutil/tree/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/public); [functions/private/Set-WinUtilDNS.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Set-WinUtilDNS.ps1); [functions/private/Invoke-WinUtilISO.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Invoke-WinUtilISO.ps1); [functions/private/Invoke-WinUtilISOUSB.ps1](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/functions/private/Invoke-WinUtilISOUSB.ps1)

### ReviOS and Revision Tool

`playbook.conf` defines user-selectable options and defaults, while `Configuration/main.yml` orchestrates package removal, software, services, registry changes, upgrade rollback and finalization. Many tasks run as TrustedInstaller. The source option manifest is a more reliable build-support reference than an old README: this snapshot includes build numbers 19044, 19045, 22631, 26100, 26200, 28000 and 26300. `optional-features.yml` exists but is **not referenced by the examined task graph**, so its DISM helper is listed as available source rather than an always-applied change. [src/playbook.conf](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/playbook.conf); [src/Configuration/main.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/main.yml); [src/Configuration/Tasks/packages/optional-features.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/optional-features.yml)

The footprint is broader than removing apps: exact and wildcard AppX removals; Edge/OneDrive/Teams uninstall helpers; custom WinSxS CAB packages; VCRedist/browser/Revision Tool installation; privacy policies/tasks/firewall/hosts; shell/search/start/taskbar/context-menu changes; scheduling, CPU/memory/NTFS and power changes; security controls; update/driver/Store settings; default associations and legacy Photo Viewer; wallpaper/theme/branding; NGen; log/cache cleanup; and upgrade rollback. `revert.yml` is migration repair, not a universal “undo ReviOS” button. It records reverted changes for broken WebSockets, controller services, Efficiency Mode, Game Bar, Phone Link and other regressions. [src/Configuration/Tasks/revert.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/revert.yml); [src/Configuration/Tasks/registry.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry.yml); [src/Configuration/Tasks/start.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/start.yml); [src/Configuration/Tasks/final.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/final.yml)

Revision Tool is a Dart/Flutter GUI plus generated CLI, with separate service implementations for performance, security, personalization, updates and utilities. It also searches/downloads/installs Microsoft Store apps and dependencies, manages five WinSxS removal-package types, hides/unhides Settings pages, applies patches and updates itself. Its README restricts use to ReviOS; study individual settings, do not run it as a stock-Windows dotfiles dependency. [README.md](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/README.md); [src/lib/main_cli.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/main_cli.dart); [src/lib/features/ms_store/domain/services/store_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/ms_store/domain/services/store_service.dart); [src/lib/features/winsxs/domain/win_package_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/winsxs/domain/win_package_service.dart)

The separately maintained `meetrevision/packages` manifests explain the actual targets of “system-components-removal,” “ai-removal,” “defender-removal,” “onedrive-removal,” and “xbox-removal.” AMD64 and ARM64 lists differ. Definition counts below are unique target-component names, not installed components on this machine. The downloaded release CABs and their resulting removals were not executed or binary-audited. [schema.json](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/schema.json); [src/lib/core/network/network_endpoints.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/core/network/network_endpoints.dart); [src/lib/features/winsxs/domain/entities/win_package.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/winsxs/domain/entities/win_package.dart)

Executable helpers add behavior not obvious from registry task titles. `FINALIZE.cmd` removes Update Health Tools/PC Health Check/Installation Assistant, disables diagnostic and update scan tasks, changes boot-menu settings and password expiry, restores Teredo defaults, and disables error reporting. `STARTMENU.cmd` replaces layouts for default/existing profiles and removes pin/cache state, also copying WinGet settings. `FILEASSOC.cmd` assigns legacy Photo Viewer types after Photos removal. `CLEANER.ps1` removes servicing/update/log/temp files as well as running Disk Cleanup. None is a general-purpose dotfiles preference to run wholesale. [src/Executables/FINALIZE.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/FINALIZE.cmd); [src/Executables/STARTMENU.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/STARTMENU.cmd); [src/Executables/FILEASSOC.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/FILEASSOC.cmd); [src/Executables/CLEANER.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/CLEANER.ps1)

### Win11Debloat and Sophia Script

Win11Debloat's `Config/Features.json` is paired with real `.reg` files and execution helpers. It exposes AI, promotions, search, taskbar, Explorer, multitasking, update, gaming and optional-feature settings, plus CLI/GUI, saved configurations, user/default-profile targeting, registry-state backup/restore and preview handling. That makes it a good reference for narrow changes. Its defaults still include choices such as Modern Standby networking and AI-service behavior that should not be imported automatically. [Config/Features.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Features.json); [Config/DefaultSettings.json](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/DefaultSettings.json); [Win11Debloat.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Win11Debloat.ps1); [Scripts/Features/Get-CurrentTweakState.ps1](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features/Get-CurrentTweakState.ps1)

Sophia separates an editable `Sophia.ps1` preset, module functions and private helpers. Its Windows 11 PowerShell 7 snapshot declares Windows 11 **25H2+** and PowerShell **7.6**, so it is a reference to adapt, not a script compatible merely because this repo requires PowerShell 7.0+. It covers privacy, shell/preferences, servicing/update/restart policy, apps/features/capabilities, power/storage, associations, maintenance tasks, security hardening and context-menu tools. Several functions remove existing policies as part of their implementation; copying entire functions could fight your own DSC policy ownership. [src/Sophia_Script_for_Windows_11_PowerShell_7/Sophia.ps1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Sophia.ps1); [src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1)

## Complete configuration and public-feature inventories

Identifiers are retained so each feature can be found directly in upstream source. Catalogue entries include action buttons, toggles and mutually exclusive alternatives; the counts are not counts of recommended optimizations. Detailed inventories are collapsed for easier reading.

<details>
<summary>A. Windows Utility: every tweak, feature, preset, DNS provider, AppX entry and application name</summary>

### WinUtil tweak entries (67)

[Pinned tweak definitions](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/tweaks.json)

| Identifier | Feature | Upstream category | Implementation |
| --- | --- | --- | --- |
| WPFTweaksActivity | Activity History - Disable | Essential Tweaks | 3 registry entries |
| WPFTweaksHiber | Hibernation - Disable | Essential Tweaks | 2 registry entries; apply script; undo script |
| WPFTweaksWidget | Widgets - Remove | Essential Tweaks | apply script |
| WPFTweaksRevertStartMenu | Start Menu Previous Layout - Enable | Essential Tweaks | 1 registry entries |
| WPFTweaksDisableStoreSearch | Microsoft Store Recommended Search Results - Disable | Essential Tweaks | apply script; undo script |
| WPFTweaksLocation | Location Tracking - Disable | Essential Tweaks | 3 registry entries; 1 service entries |
| WPFTweaksServices | Services - Set to Manual | Essential Tweaks | 5 service entries; apply script |
| WPFTweaksBraveDebloat | Brave Browser - Debloat | z__Advanced Tweaks - CAUTION | 12 registry entries |
| WPFTweaksDisableWarningForUnsignedRdp | RDP Unsigned File Warnings - Disable | z__Advanced Tweaks - CAUTION | 2 registry entries |
| WPFTweaksEdgeDebloat | Microsoft Edge - Debloat | z__Advanced Tweaks - CAUTION | 17 registry entries |
| WPFTweaksConsumerFeatures | ConsumerFeatures - Disable | Essential Tweaks | 1 registry entries |
| WPFTweaksTelemetry | Telemetry - Disable | Essential Tweaks | 12 registry entries; apply script; undo script |
| WPFTweaksDeliveryOptimization | Delivery Optimization - Disable | Essential Tweaks | 1 registry entries |
| WPFTweaksRemoveEdge | Microsoft Edge - Remove | z__Advanced Tweaks - CAUTION | apply script; undo script |
| WPFTweaksDisableBitLocker | BitLocker - Disable | Essential Tweaks | apply script; undo script |
| WPFTweaksUTC | Date & Time - Set Time to UTC | z__Advanced Tweaks - CAUTION | 1 registry entries |
| WPFTweaksRemoveOneDrive | Microsoft OneDrive - Remove | z__Advanced Tweaks - CAUTION | apply script; undo script |
| WPFTweaksRemoveHomeAndGallery | File Explorer Home and Gallery - Disable | z__Advanced Tweaks - CAUTION | 3 registry entries |
| WPFTweaksDisplay | Visual Effects - Set to Best Performance | z__Advanced Tweaks - CAUTION | 12 registry entries; apply script; undo script |
| WPFTweaksReservedStorage | Disable Reserved Storage | z__Advanced Tweaks - CAUTION | apply script; undo script |
| WPFTweaksRestorePoint | Restore Point - Create | Essential Tweaks | 1 registry entries; apply script |
| WPFTweaksEndTaskOnTaskbar | End Task With Right Click - Enable | Essential Tweaks | 1 registry entries |
| WPFTweaksStorage | Storage Sense - Disable | z__Advanced Tweaks - CAUTION | 1 registry entries |
| WPFTweaksWindowsAI | Windows AI - Disable And Remove | z__Advanced Tweaks - CAUTION | 2 registry entries; apply script |
| WPFTweaksWPBT | Windows Platform Binary Table (WPBT) - Disable | Essential Tweaks | 1 registry entries |
| WPFTweaksPreventDeviceMetadataFromNetwork | Prevent Device Companion Apps | Essential Tweaks | 1 registry entries |
| WPFTweaksRazerBlock | Razer Software Auto-Install - Disable | z__Advanced Tweaks - CAUTION | 2 registry entries; apply script; undo script |
| WPFTweaksLogiBlock | Logitech Download Assistant Auto-Install - Disable | z__Advanced Tweaks - CAUTION | apply script; undo script |
| WPFTweaksDisableNotifications | System Tray Notifications & Calendar - Disable | z__Advanced Tweaks - CAUTION | 2 registry entries |
| WPFTweaksBlockAdobeNet | Adobe URL Block List - Enable | z__Advanced Tweaks - CAUTION | apply script; undo script |
| WPFTweaksRightClickMenu | Right-Click Menu Previous Layout - Enable | z__Advanced Tweaks - CAUTION | apply script; undo script |
| WPFTweaksDiskCleanup | Disk Cleanup - Run | Essential Tweaks | apply script |
| WPFTweaksDeleteTempFiles | Temporary Files - Remove | Essential Tweaks | apply script |
| WPFTweaksIPv46 | IPv6 - Set IPv4 as Preferred | z__Advanced Tweaks - CAUTION | 1 registry entries |
| WPFTweaksTeredo | Teredo - Disable | z__Advanced Tweaks - CAUTION | 1 registry entries; apply script; undo script |
| WPFTweaksDisableIPv6 | IPv6 - Disable | z__Advanced Tweaks - CAUTION | 1 registry entries; apply script; undo script |
| WPFTweaksDisableBGapps | Background Apps - Disable | z__Advanced Tweaks - CAUTION | 1 registry entries |
| WPFTweaksDisableExplorerAutoDiscovery | File Explorer Automatic Folder Discovery - Disable | Essential Tweaks | apply script; undo script |
| WPFToggleDetailedBSoD | BSoD Verbose Mode | Customize Preferences | 2 registry entries |
| WPFToggleBatteryPercentage | System Tray Battery Percentage | Customize Preferences | 1 registry entries |
| WPFToggleDarkMode | Dark Theme for Windows | Customize Preferences | 2 registry entries; apply script; undo script |
| WPFToggleShowExt | File Explorer File Extensions | Customize Preferences | 1 registry entries; apply script; undo script |
| WPFToggleHiddenFiles | File Explorer Hidden Files | Customize Preferences | 1 registry entries; apply script; undo script |
| WPFToggleVerboseLogon | Logon Verbose Mode | Customize Preferences | 1 registry entries |
| WPFToggleNewOutlook | Microsoft Outlook New Version | Customize Preferences | 4 registry entries |
| WPFToggleScrollbars | Scrollbars Always Visible | Customize Preferences | 1 registry entries |
| WPFMultiplaneOverlay | Multiplane Overlay | Customize Preferences | 2 registry entries |
| WPFToggleMouseAcceleration | Mouse Acceleration | Customize Preferences | 3 registry entries |
| WPFToggleNumLock | Num Lock on Startup | Customize Preferences | 2 registry entries |
| WPFToggleWindowSnapping | Window Snapping | Customize Preferences | 1 registry entries |
| WPFToggleStandbyFix | S0 Sleep Network Connectivity | Customize Preferences | 1 registry entries |
| WPFToggleS3Sleep | S3 Sleep | Customize Preferences | 1 registry entries |
| WPFToggleHideSettingsHome | Settings Home Page | Customize Preferences | 1 registry entries |
| WPFToggleBingSearch | Start Menu Bing Search | Customize Preferences | 1 registry entries |
| WPFToggleLoginBlur | Logon Screen Acrylic Blur | Customize Preferences | 1 registry entries |
| WPFToggleDisableLockscreen | Lock Screen - Disable | Customize Preferences | 1 registry entries |
| WPFToggleStartMenuRecommendations | Start Menu Recommendations | Customize Preferences | 3 registry entries; apply script; undo script |
| WPFToggleStickyKeys | Sticky Keys | Customize Preferences | 1 registry entries |
| WPFToggleTaskbarAlignment | Taskbar Centered Icons | Customize Preferences | 1 registry entries; apply script; undo script |
| WPFToggleTaskbarSearch | Taskbar Search Icon | Customize Preferences | 1 registry entries |
| WPFToggleTaskView | Taskbar Task View Icon | Customize Preferences | 1 registry entries |
| WPFToggleGameMode | Game Mode | Customize Preferences | 2 registry entries |
| WPFToggleLongPaths | Enable Long Paths | Customize Preferences | 1 registry entries |
| WPFOOSUbutton | O&O ShutUp10++ - Run | z__Advanced Tweaks - CAUTION | UI action / delegated handler |
| WPFchangedns | DNS - Set to: | z__Advanced Tweaks - CAUTION | UI action / delegated handler |
| WPFAddUltPerf | Ultimate Performance Profile - Enable | Performance Plans - NOT FOR LAPTOPS | UI action / delegated handler |
| WPFRemoveUltPerf | Ultimate Performance Profile - Disable | Performance Plans - NOT FOR LAPTOPS | UI action / delegated handler |

### Optional features, repairs and settings links (33)

[Pinned feature definitions](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/feature.json)

| Identifier | Feature/action |
| --- | --- |
| WPFFeaturesdotnet | .NET Framework (Versions 2, 3, 4) - Enable |
| WPFFixesNTPPool | NTP Server - Enable |
| WPFFeatureshyperv | Hyper-V - Enable |
| WPFFeatureslegacymedia | Legacy Media Components (WMP, DirectPlay) - Enable |
| WPFFeaturewsl | Windows Subsystem for Linux (WSL) - Enable |
| WPFFeaturenfs | Network File System (NFS) - Enable |
| WPFFeatureRegBackup | Registry Backup (Daily Task 12:30am) - Enable |
| WPFFeatureEnableLegacyRecovery | Legacy F8 Boot Recovery - Enable |
| WPFFeatureDisableLegacyRecovery | Legacy F8 Boot Recovery - Disable |
| WPFFeaturesSandbox | Windows Sandbox - Enable |
| WPFFeatureInstall | Install Features |
| WPFPanelAutologin | AutoLogon - Run |
| WPFFixesUpdate | Windows Update - Reset |
| WPFFixesNetwork | Network - Reset |
| WPFPanelDISM | System Corruption Scan - Run |
| WPFFixesWinget | WinGet - Reinstall |
| WPFPanelComputer | Computer Management |
| WPFPanelControl | Control Panel |
| WPFPanelMouse | Mouse Properties |
| WPFPanelNetwork | Network Connections |
| WPFPanelPower | Power Panel |
| WPFPanelPrinter | Printer Panel |
| WPFPanelPrograms | Programs and Features |
| WPFPanelRegion | Region |
| WPFPanelSecurity | Security and Maintenance |
| WPFPanelSound | Sound Settings |
| WPFPanelSystem | System Properties |
| WPFPanelTimedate | Time and Date |
| WPFPanelFirewall | Windows Defender Firewall |
| WPFPanelRestore | Windows Restore |
| WPFWinUtilInstallPSProfile | CTT PowerShell Profile - Install |
| WPFWinUtilUninstallPSProfile | CTT PowerShell Profile - Remove |
| WPFWinUtilSSHServer | OpenSSH Server - Enable |

### Presets (four)

[Pinned preset memberships](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/preset.json)

| Preset | Exact selections |
| --- | --- |
| Standard | `WPFTweaksActivity`, `WPFTweaksConsumerFeatures`, `WPFTweaksDisableExplorerAutoDiscovery`, `WPFTweaksWPBT`, `WPFTweaksLocation`, `WPFTweaksServices`, `WPFTweaksTelemetry`, `WPFTweaksDeliveryOptimization`, `WPFTweaksDiskCleanup`, `WPFTweaksDeleteTempFiles`, `WPFTweaksEndTaskOnTaskbar`, `WPFTweaksRestorePoint` |
| Minimal | `WPFTweaksConsumerFeatures`, `WPFTweaksWPBT`, `WPFTweaksServices`, `WPFTweaksTelemetry` |
| Advanced | `WPFTweaksRestorePoint`, `WPFTweaksActivity`, `WPFTweaksConsumerFeatures`, `WPFTweaksDisableExplorerAutoDiscovery`, `WPFTweaksWPBT`, `WPFTweaksLocation`, `WPFTweaksServices`, `WPFTweaksTelemetry`, `WPFTweaksDeliveryOptimization`, `WPFTweaksDeleteTempFiles`, `WPFTweaksEndTaskOnTaskbar`, `WPFTweaksDisableStoreSearch`, `WPFTweaksRevertStartMenu`, `WPFTweaksWidget`, `WPFTweaksRemoveOneDrive`, `WPFTweaksWindowsAI`, `WPFTweaksRightClickMenu` |
| AppxDefault | `WPFAppxMicrosoft_WindowsFeedbackHub`, `WPFAppxMicrosoft_GetHelp`, `WPFAppxMicrosoft_MicrosoftOfficeHub`, `WPFAppxMicrosoft_WindowsCalculator`, `WPFAppxClipchamp_Clipchamp`, `WPFAppxMicrosoft_WindowsAlarms`, `WPFAppxMicrosoftCorporationII_QuickAssist`, `WPFAppxMicrosoft_WindowsSoundRecorder`, `WPFAppxMicrosoft_MicrosoftStickyNotes`, `WPFAppxMicrosoft_Todos`, `WPFAppxMicrosoft_MicrosoftSolitaireCollection`, `WPFAppxMicrosoft_PowerAutomateDesktop`, `WPFAppxMicrosoft_WindowsDevHome`, `WPFAppxMicrosoft_BingWeather`, `WPFAppxMicrosoft_StartExperiencesApp`, `WPFAppxMicrosoft_BingNews`, `WPFAppxMicrosoft_Copilot`, `WPFAppxMicrosoft_BingSearch` |

### DNS (eight providers)

[Pinned DNS definitions](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/dns.json)

| Provider | IPv4 pair | IPv6 pair | DoH template | Eligible for Fastest |
| --- | --- | --- | --- | --- |
| Google | 8.8.8.8, 8.8.4.4 | 2001:4860:4860::8888, 2001:4860:4860::8844 | https://dns.google/dns-query | Yes |
| Cloudflare | 1.1.1.1, 1.0.0.1 | 2606:4700:4700::1111, 2606:4700:4700::1001 | https://cloudflare-dns.com/dns-query | Yes |
| Cloudflare_Malware | 1.1.1.2, 1.0.0.2 | 2606:4700:4700::1112, 2606:4700:4700::1002 | https://security.cloudflare-dns.com/dns-query | No |
| Cloudflare_Malware_Adult | 1.1.1.3, 1.0.0.3 | 2606:4700:4700::1113, 2606:4700:4700::1003 | https://family.cloudflare-dns.com/dns-query | No |
| Open_DNS | 208.67.222.222, 208.67.220.220 | 2620:119:35::35, 2620:119:53::53 | https://doh.opendns.com/dns-query | No |
| Quad9 | 9.9.9.9, 149.112.112.112 | 2620:fe::fe, 2620:fe::9 | https://dns.quad9.net/dns-query | No |
| AdGuard_Ads_Trackers | 94.140.14.14, 94.140.15.15 | 2a10:50c0::ad1:ff, 2a10:50c0::ad2:ff | https://dns.adguard-dns.com/dns-query | No |
| AdGuard_Ads_Trackers_Malware_Adult | 94.140.14.15, 94.140.15.16 | 2a10:50c0::bad1:ff, 2a10:50c0::bad2:ff | https://family.adguard-dns.com/dns-query | No |

### AppX catalogue (34 entries)

[Pinned AppX definitions](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/appx.json)

| Identifier | Name | Package identity |
| --- | --- | --- |
| WPFAppxMicrosoft_WindowsFeedbackHub | Feedback Hub | Microsoft.WindowsFeedbackHub |
| WPFAppxMicrosoft_GetHelp | Get Help | Microsoft.GetHelp |
| WPFAppxMicrosoft_OutlookForWindows | Outlook for Windows | Microsoft.OutlookForWindows |
| WPFAppxMSTeams | Microsoft Teams | MSTeams |
| WPFAppxClipchamp_Clipchamp | Clipchamp | Clipchamp.Clipchamp |
| WPFAppxMicrosoft_MicrosoftOfficeHub | Microsoft 365 | Microsoft.MicrosoftOfficeHub |
| WPFAppxMicrosoft_ZuneMusic | Media Player | Microsoft.ZuneMusic |
| WPFAppxMicrosoft_BingSearch | Bing Search | Microsoft.BingSearch |
| WPFAppxMicrosoftCorporationII_QuickAssist | Quick Assist | MicrosoftCorporationII.QuickAssist |
| WPFAppxMicrosoft_WindowsDevHome | Dev Home | Microsoft.Windows.DevHome |
| WPFAppxMicrosoft_WindowsCrossDevice | Mobile Devices | MicrosoftWindows.CrossDevice |
| WPFAppxMicrosoft_Todos | To Do | Microsoft.Todos |
| WPFAppxMicrosoft_PowerAutomateDesktop | Power Automate | Microsoft.PowerAutomateDesktop |
| WPFAppxMicrosoft_YourPhone | Phone Link | Microsoft.YourPhone |
| WPFAppxMicrosoft_MicrosoftStickyNotes | Sticky Notes | Microsoft.MicrosoftStickyNotes |
| WPFAppxMicrosoft_WindowsSoundRecorder | Sound Recorder | Microsoft.WindowsSoundRecorder |
| WPFAppxMicrosoft_WindowsAlarms | Clock | Microsoft.WindowsAlarms |
| WPFAppxMicrosoft_Paint | Paint | Microsoft.Paint |
| WPFAppxMicrosoft_WindowsNotepad | Notepad | Microsoft.WindowsNotepad |
| WPFAppxMicrosoft_ScreenSketch | Snipping Tool | Microsoft.ScreenSketch |
| WPFAppxMicrosoft_Copilot | Copilot | Microsoft.Copilot |
| WPFAppxMicrosoft_WindowsCalculator | Calculator | Microsoft.WindowsCalculator |
| WPFAppxMicrosoft_WindowsCamera | Camera | Microsoft.WindowsCamera |
| WPFAppxMicrosoft_WindowsPhotos | Photos | Microsoft.Windows.Photos |
| WPFAppxMicrosoft_BingNews | News | Microsoft.BingNews |
| WPFAppxMicrosoft_BingWeather | Weather | Microsoft.BingWeather |
| WPFAppxMicrosoft_GamingApp | Xbox App | Microsoft.GamingApp |
| WPFAppxMicrosoft_XboxGamingOverlay | Xbox Game Bar | Microsoft.XboxGamingOverlay |
| WPFAppxMicrosoft_XboxIdentityProvider | Xbox Identity Provider | Microsoft.XboxIdentityProvider |
| WPFAppxMicrosoft_XboxSpeechToTextOverlay | Xbox Speech To Text Overlay | Microsoft.XboxSpeechToTextOverlay |
| WPFAppxMicrosoft_Xbox_TCUI | Xbox TCUI | Microsoft.Xbox.TCUI |
| WPFAppxMicrosoft_StartExperiencesApp | Start Experiences App | Microsoft.StartExperiencesApp |
| WPFAppxMicrosoft_MicrosoftSolitaireCollection | Solitaire Collection | Microsoft.MicrosoftSolitaireCollection |
| WPFAppxMicrosoft_ZuneVideo | Movies & TV | Microsoft.ZuneVideo |

### Installation catalogue (236 entries)

Application names are included for completeness; installation is already handled by your `packages.winget`. Package-manager IDs and metadata remain in [the pinned catalogue](https://github.com/ChrisTitusTech/winutil/blob/9c87c02fdb9e057f41dd3aea051af4df6f41cf5f/config/applications.json).

| Category | Installable applications |
| --- | --- |
| Browsers | Brave, Chrome, Chromium, Edge, Firefox, Firefox ESR, Floorp, Helium, LibreWolf, Mullvad Browser, Tor Browser, Ungoogled Chromium, Vivaldi, Waterfox, Zen Browser |
| Communications | Chatterino, Discord, Dorion, Element, Proton Mail, QTox, Signal, Slack, Teams, TeamSpeak 3, TeamSpeak 6, Telegram, Thunderbird, Betterbird, Vesktop, Viber, WhatsApp Desktop, Zoom |
| Development | Bruno, ChatGPT Desktop, Claude Desktop, Claude Code, CMake, Codex, Cursor, Docker Desktop, Fast Node Manager, Git, Git Extensions, GitHub CLI, GitHub Desktop, Go, Amazon Corretto 8 (LTS), Amazon Corretto 21 (LTS), Amazon Corretto 25 (LTS), Jetbrains Toolbox, Lazygit, Neovim, NodeJS, NodeJS LTS, pnpm, Oh My Posh (Prompt), Postman, Python3, Rust, System Informer, Starship (Shell Prompt), Sublime Text, Unity Game Engine, Vagrant, Visual Studio 2022, Visual Studio 2026, VS Code, VS Codium, Yarn, uv, Zed, Ruby, Lua |
| Document | Adobe Acrobat Reader, Foxit PDF Reader, Joplin, LibreOffice, NAPS2 (Scanner), Obsidian, Okular, ONLYOFFICE Desktop, PDF-XChange Editor, PDF24 Creator, PDFgear, PDFsam Basic, QOwnNotes, Simplenote, Sumatra PDF, Xournal++, Zotero |
| Games | Battle.net, Cemu, EA App, EmulationStation Desktop Edition, Epic Games Launcher, GeForce NOW, GOG Galaxy, Heroic Games Launcher, Itch.io, Modrinth App, Playnite, Prism Launcher, Steam, Roblox, Ubisoft Connect, Virtual Desktop Streamer, CurseForge |
| Microsoft Tools | Autoruns, RDCMan, DISMTools, NTLite, .NET Desktop Runtime 6, .NET Desktop Runtime 8, .NET Desktop Runtime 9, .NET Desktop Runtime 10, NuGet, OneDrive, Process Explorer, PowerShell, PowerToys, Process Monitor, TCPView, Windows Terminal, Visual C++ 2015-2022 32-bit, Visual C++ 2015-2022 64-bit |
| Multimedia Tools | AIMP (Music Player), Audacity, Blender (3D Graphics), Calibre, EarTrumpet (Audio), File Converter, foobar2000 (Music Player), GIMP (Image Editor), HandBrake, ImageGlass (Image Viewer), IrfanView, iTunes, K-Lite Codec Standard, mpc-qt, mpv, Media Player Classic - Home Cinema, nomacs, Notepad++, OBS Studio, Paint.NET, ShareX (Screenshots), VLC (Video Player) |
| Pro Tools | Advanced IP Scanner, Angry IP Scanner, Cinebench R23, CPU-Z, Display Driver Uninstaller, GPU-Z, gsudo, HWiNFO, HWMonitor, Mullvad VPN, Nmap, OpenVPN Connect, Proton VPN, PuTTY, Simplewall, Ventoy, WinSCP, WireGuard, Wireshark |
| Selfhosted Tools | Jellyfin Media Player, Jellyfin Server, Kodi Media Center, LocalSend, Moonlight/GameStream Client, NetBird, Nextcloud Desktop, Plex Media Server, Plex Desktop, Sunshine/GameStream Server, SyncTrayzor, Syncthing (CLI / Web UI) |
| Utilities | 1Password, 7-Zip, AB Download Manager, AnyDesk, AutoHotkey, Bitwarden, Bulk Crap Uninstaller, BlurAutoClicker, Crystal Disk Info, Crystal Disk Mark, Dropbox, Ente Auth, Files, F.lux, Google Drive, Hugo, Internet Download Manager, JPEG View, KeePassXC, MiniTool Partition Wizard, MSEdgeRedirect, MSI Afterburner, NanaZip, Tailscale, NVCleanstall, OPAutoClicker, OpenRGB, Oracle VirtualBox, Policy Plus, Parsec, PeaZip, Process Lasso, Proton Authenticator, Proton Drive, Proton Pass, qBittorrent, Revo Uninstaller, Wise Program Uninstaller (WiseCleaner), Rufus Imager, Snappy Driver Installer Origin, Nilesoft Shell, SignalRGB, StartAllBack, TeamViewer, Total Commander, TreeSize Free, TranslucentTB, Everything, UniGetUI, WinRAR, WizTree, HxD Hex Editor, TightVNC, GlazeWM, OFGB (Oh Frick Go Back), Deskflow, Cloudflare WARP |


</details>

<details>
<summary>B. ReviOS playbook: defaults, every task, active services, configured registry value names and helper assets</summary>

### Selectable playbook options and defaults

[Pinned option manifest](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/playbook.conf)

| Option | Feature | Default |
| --- | --- | --- |
| none | No browser | Unselected |
| browser-brave | Brave | Selected |
| browser-firefox | Firefox | Unselected |
| disable-defender | Disable Defender (Default) | Selected |
| enable-defender | Enable Defender | Unselected |
| disable-hibernate | Disable Hibernate (Default) | Selected |
| enable-hibernate | Enable Hibernate | Unselected |
| remove-edge | Remove Microsoft Edge | Checked |
| remove-onedrive | Remove OneDrive | Checked |
| remove-winsxs-ai | Remove AI (Recall & Copilot) | Checked |
| remove-teams | Remove Microsoft Teams | Checked |
| remove-appx-photos | Remove MS Photos | Checked |
| remove-appx-devhome | Remove Dev Home | Checked |
| remove-appx-xbox | Remove Xbox apps | Unchecked |
| remove-appx-yourphone | Remove 'Your Phone' | Checked |
| configure-wallpaper | Apply Revision wallpaper | Checked |
| configure-darkmode | Enable Dark Mode | Checked |
| configure-lcm | Enable Legacy Context Menu | Checked |
| configure-te | Disable Transparency Effects | Checked |
| remove-pinned-items-startmenu | Remove pinned items in Start Menu | Checked |
| disable-automatic-maintenance | Disable Automatic Maintenance | Unchecked |

ISO-specific manifest flags additionally disable BitLocker and bypass hardware requirements. Their scope is ISO setup, not necessarily a live apply.

### Task files and concrete configured values

51 YAML files are reachable from `main.yml`, including the entry point. Reachable means the task can be dispatched; individual actions remain conditional on options, builds, OOBE or upgrade status. `revert.yml` is upgrade-only. Commented-out service examples are excluded from active action counts.

#### [main.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/main.yml)

Custom — Reachable task.

**Active action kinds:** task: 11, taskKill: 8.

#### [Tasks/final.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/final.yml)

Configuration — Reachable task.

**Active action kinds:** appx: 4, cmd: 3, powerShell: 10, registryValue: 7, run: 9, writeStatus: 3.

**Action option conditions:** `!configure-darkmode`, `!configure-wallpaper`, `configure-darkmode`, `configure-wallpaper`, `remove-appx-photos`, `remove-pinned-items-startmenu`.

**Registry value names configured/deleted:** `AppsUseLightTheme`, `GameDVR_FSEBehaviorMode`, `RegisterWithAU`, `RevisionWallpaperStartup`, `SystemUsesLightTheme`.

**Revision Tool commands:** `tweaks performance ntfs-last-access disable`, `tweaks performance ntfs-8dot3-naming disable`, `tweaks performance service-grouping set recommended`, `tweaks patches`.

#### [Tasks/packages/app-win32.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/app-win32.yml)

Remove Win32 apps — Reachable task.

**Active action kinds:** file: 2, powerShell: 5, registryValue: 1, run: 2, taskKill: 10, writeStatus: 3.

**Action option conditions:** `remove-edge`, `remove-onedrive`, `remove-teams`, `remove-winsxs-ai`.

**Registry value names configured/deleted:** `ConfigureChatAutoInstall`.

#### [Tasks/packages/appx.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/appx.yml)

APPX — Reachable task.

**Active action kinds:** powerShell: 5, registryKey: 1, registryValue: 4, run: 1, writeStatus: 6.

**Action option conditions:** `remove-appx-devhome`, `remove-appx-photos`, `remove-appx-xbox`, `remove-appx-yourphone`.

**Registry value names configured/deleted:** ``, `ShowStartupPanel`, `URL Protocol`.

**Revision Tool commands:** `msstore-apps --id 9NBLGGH3FRZM,9NBLGGH4RV3K -r RP" # 9NBLGGH3FRZM - Desktop; 9NBLGGH4RV3K - UWPDesktop.`.

#### [Tasks/packages/optional-features.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/optional-features.yml)

Optional Features — Not reached from main.yml.

**Active action kinds:** powerShell: 1, writeStatus: 1.

#### [Tasks/packages/win-sxs.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/packages/win-sxs.yml)

Packages — Reachable task.

**Active action kinds:** run: 5, writeStatus: 5.

**Action option conditions:** `disable-defender`, `enable-defender`, `remove-onedrive`, `remove-winsxs-ai`.

**Revision Tool commands:** `winpackage --install system-components-removal`, `tweaks security defender disable --force`, `tweaks security defender enable`, `winpackage --install ai-removal`, `winpackage --install onedrive-removal`.

#### [Tasks/registry/explorer/context-menu.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/context-menu.yml)

Configure Explorer -> Context Menu — Reachable task.

**Active action kinds:** registryKey: 4, registryValue: 23.

**Action option conditions:** `configure-lcm`.

**Registry value names configured/deleted:** ``, `AppliesTo`, `HasLUAShield`, `IsolatedCommand`, `NoWorkingDirectory`, `Position`.

#### [Tasks/registry/explorer/control-panel.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/control-panel.yml)

Configure Control Panel — Reachable task.

**Active action kinds:** registryKey: 27, registryValue: 57.

**Registry value names configured/deleted:** `ActiveWndTrkTimeout`, `AllowOnlineTips`, `AutoEndTasks`, `Beep`, `Flags`, `HungAppTimeout`, `JPEGImportQuality`, `LowLevelHooksTimeout`, `MaximumSpeed`, `MenuShowDelay`, `MouseSpeed`, `MouseThreshold1`, `MouseThreshold2`, `TimeToMaximumSpeed`, `WaitToKillAppTimeout`.

#### [Tasks/registry/explorer/explorer.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/explorer.yml)

Configure Explorer — Reachable task.

**Active action kinds:** powerShell: 2, registryValue: 38.

**Action option conditions:** `!configure-explorer-taskbar-animations`, `configure-explorer-taskbar-animations`.

**Registry value names configured/deleted:** `AllowSuggestedAppsInWindowsInkWorkspace`, `AllowWindowsInkWorkspace`, `C:\Windows\explorer.exe`, `DisableAutoplay`, `DisableGraphRecentItems`, `EnthusiastMode`, `FolderType`, `LaunchTo`, `LinkResolveIgnoreLinkInfo`, `MultipleInvokePromptMinimum`, `NoDriveTypeAutoRun`, `NoLowDiskSpaceChecks`, `ShowInfoTip`, `Start_AccountNotifications`, `Start_IrisRecommendations`, `TaskbarAnimations`, `TaskbarEndTask`, `WaitToKillServiceTimeout`, `link`, `pageContextMenuSelectionLimit`, `{2cc5ca98-6485-489a-920e-b3e88a6ccce3}`.

#### [Tasks/registry/explorer/notifications.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/notifications.yml)

Configure Explorer -> Notifications — Reachable task.

**Active action kinds:** registryValue: 10.

**Registry value names configured/deleted:** `NoAutoTrayNotify`, `NoBalloonFeatureAdvertisements`, `NoCloudApplicationNotification`, `ScoobeCheckCompleted`, `ScoobeSystemSettingEnabled`, `UpdateNotificationLevel`.

#### [Tasks/registry/explorer/search.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/search.yml)

Configure Explorer -> Search — Reachable task.

**Active action kinds:** registryValue: 22.

**Registry value names configured/deleted:** `1694661260`, `ActivationType`, `AllowCloudSearch`, `AllowCortana`, `AllowCortanaAboveLock`, `AllowCortanaInAAD`, `AllowCortanaInAADPathOOBE`, `AllowSearchToUseLocation`, `BingSearchEnabled`, `ConnectedSearchPrivacy`, `ConnectedSearchUseWeb`, `ConnectedSearchUseWebOverMeteredConnections`, `CortanaConsent`, `DisableSearchBoxSuggestions`, `DisableWebSearch`, `PreventIndexOnBattery`, `RespectPowerModes`, `Server`, `VoiceActivationEnableAboveLockscreen`.

#### [Tasks/registry/explorer/start-menu.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/start-menu.yml)

Configure Explorer -> Start Menu  — Reachable task.

**Active action kinds:** registryValue: 23.

**Action option conditions:** `remove-pinned-items-startmenu`.

**Registry value names configured/deleted:** `AllowPinnedFolderDocuments`, `AllowPinnedFolderDocuments_ProviderSet`, `AllowPinnedFolderDownloads`, `AllowPinnedFolderDownloads_ProviderSet`, `AllowPinnedFolderFileExplorer`, `AllowPinnedFolderFileExplorer_ProviderSet`, `AllowPinnedFolderHomeGroup`, `AllowPinnedFolderHomeGroup_ProviderSet`, `AllowPinnedFolderMusic`, `AllowPinnedFolderMusic_ProviderSet`, `AllowPinnedFolderNetwork`, `AllowPinnedFolderNetwork_ProviderSet`, `AllowPinnedFolderPersonalFolder`, `AllowPinnedFolderPersonalFolder_ProviderSet`, `AllowPinnedFolderPictures`, `AllowPinnedFolderPictures_ProviderSet`, `AllowPinnedFolderSettings`, `AllowPinnedFolderSettings_ProviderSet`, `AllowPinnedFolderVideos`, `AllowPinnedFolderVideos_ProviderSet`, `ConfigureStartPins`, `NoResolveSearch`.

#### [Tasks/registry/explorer/taskbar.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/taskbar.yml)

Configure Explorer -> Taskbar — Reachable task.

**Active action kinds:** registryValue: 18.

**Registry value names configured/deleted:** `AllowNewsAndInterests`, `ChatIcon`, `EnableFeeds`, `HidePeopleBar`, `HideSCAMeetNow`, `SearchboxTaskbarMode`, `ShellFeedsTaskbarViewMode`, `ShowTaskViewButton`, `TaskbarDa`, `TaskbarMn`.

#### [Tasks/registry/explorer/view.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/view.yml)

Configure Explorer View  — Reachable task.

**Active action kinds:** registryValue: 6.

**Registry value names configured/deleted:** `FullPath`, `HideFileExt`, `ShowSyncProviderNotifications`.

#### [Tasks/registry/explorer/win-settings.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/explorer/win-settings.yml)

Configure Windows Settings — Reachable task.

**Active action kinds:** registryValue: 141, run: 3.

**Action option conditions:** `configure-te`, `remove-appx-xbox`, `remove-appx-yourphone`.

**Registry value names configured/deleted:** `1387020943`, `ActivationType`, `AllowClipboardHistory`, `AllowCrossDeviceClipboard`, `AllowLinguisticDataCollection`, `AppCaptureEnabled`, `AutoConnectAllowedOEM`, `AutoUpdateEnabled`, `Color`, `ConvertibleSlateModePromptPreference`, `DefaultValue`, `DisableAIDataAnalysis`, `DisableApplicationSettingSync`, `DisableApplicationSettingSyncUserOverride`, `DisableAutoplay`, `DisableCredentialsSettingSync`, `DisableCredentialsSettingSyncUserOverride`, `DisableDesktopThemeSettingSync`, `DisableDesktopThemeSettingSyncUserOverride`, `DisablePersonalizationSettingSync`, `DisablePersonalizationSettingSyncUserOverride`, `DisableSettingSync`, `DisableSettingSyncUserOverride`, `DisableStartLayoutSettingSync`, `DisableStartLayoutSettingSyncUserOverride`, `DisableSyncOnPaidNetwork`, `DisableWebBrowserSettingSync`, `DisableWebBrowserSettingSyncUserOverride`, `DisableWindowsSettingSync`, `DisableWindowsSettingSyncUserOverride`, `DisabledByGroupPolicy`, `EnableAccountNotifications`, `EnableActivityFeed`, `EnableAutocorrection`, `EnableClipboardHistory`, `EnableDoubleTapSpace`, `EnableEventTranscript`, `EnableHwkbAutocorrection`, `EnableHwkbTextPrediction`, `EnablePredictionSpaceInsertion`, `EnableSpellchecking`, `EnableTextPrediction`, `EnableTransparency`, `Enabled`, `GameDVR_Enabled`, `HasAccepted`, `HideInsiderPage`, `HttpAcceptLanguageOptOut`, `Id`, `InsightsEnabled`, `IsResumeAllowed`, `MinAnimate`, `MultilingualEnabled`, `NumberOfSIUFInPeriod`, `PaidWifi`, `PeriodInNanoSeconds`, `PublishUserActivities`, `Server`, `SignInMode`, `SubscribedContent-338388Enabled`, `SubscribedContent-353698Enabled`, `SystemPaneSuggestionsEnabled`, `TabletMode`, `TailoredExperiencesWithDiagnosticDataEnabled`, `TaskbarAppsVisibleInTabletMode`, `TaskbarAutoHideInTabletMode`, `TrayIconVisibility`, `UpdateOnlyOnWifi`, `UploadUserActivities`, `Value`, `WiFiSenseOpen`, `value`.

**Revision Tool commands:** `tweaks personalization input-personalization disable`.

#### [Tasks/registry/misc/classic-photo-viewer.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/classic-photo-viewer.yml)

Restore classic Windows Photo Viewer — Reachable task.

**Active action kinds:** registryValue: 84.

**Action option conditions:** `remove-appx-photos`.

**Registry value names configured/deleted:** ``, `.bmp`, `.cr2`, `.dib`, `.gif`, `.jfif`, `.jpe`, `.jpeg`, `.jpg`, `.jxr`, `.png`, `.tif`, `.tiff`, `.wdp`, `ApplicationDescription`, `ApplicationName`, `Clsid`, `EditFlags`, `FriendlyTypeName`, `ImageOptionFlags`, `MuiVerb`, `NeverDefault`, `{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}`.

#### [Tasks/registry/misc/deprovisioned-apps.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/deprovisioned-apps.yml)

Configure Deprovisioned Apps — Reachable task.

**Active action kinds:** registryKey: 54, registryValue: 1.

**Registry value names configured/deleted:** `DoNotUpdateToEdgeWithChromium`.

#### [Tasks/registry/misc/disable-logging.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/disable-logging.yml)

disable-logging — Reachable task.

**Active action kinds:** registryValue: 3.

**Registry value names configured/deleted:** `DisableLogManagement`, `RSoPLogging`, `TimerInterval`.

#### [Tasks/registry/misc/disable-system-restore-pre-defined-config.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/disable-system-restore-pre-defined-config.yml)

disable-system-restore-pre-defined-config — Reachable task.

**Active action kinds:** registryKey: 1, registryValue: 2.

**Registry value names configured/deleted:** `DiskPercent`, `RPSessionInterval`.

#### [Tasks/registry/misc/enable-audio-communications-do-nothing.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/enable-audio-communications-do-nothing.yml)

enable-audio-communications-do-nothing — Reachable task.

**Active action kinds:** registryValue: 2.

**Registry value names configured/deleted:** `UserDuckingPreference`.

#### [Tasks/registry/misc/fixes.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/fixes.yml)

fixes — Reachable task.

**Active action kinds:** registryKey: 1, registryValue: 13.

**Registry value names configured/deleted:** `DisableWpbtExecution`, `DoNotUpdateToEdgeWithChromium`, `EAFModules`, `EnableLinkedConnections`, `InstallDefault`, `Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}`, `Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}`, `MitigationAuditOptions`, `MitigationOptions`, `RealTimeIsUniversal`.

#### [Tasks/registry/misc/msi-installer-in-safe-mode.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/misc/msi-installer-in-safe-mode.yml)

Make MSI installer work in safe mode — Reachable task.

**Active action kinds:** registryValue: 2.

**Registry value names configured/deleted:** ``.

#### [Tasks/registry/os-info/edition.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/os-info/edition.yml)

revision-static-edition — Reachable task.

**Active action kinds:** registryValue: 3.

**Registry value names configured/deleted:** `EditionSubManufacturer`, `EditionSubVersion`, `EditionSubstring`.

#### [Tasks/registry/os-info/oem-info.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/os-info/oem-info.yml)

OEM Information — Reachable task.

**Active action kinds:** registryValue: 5.

**Registry value names configured/deleted:** `HelpCustomized`, `Manufacturer`, `SupportAppURL`, `SupportProvider`, `SupportURL`.

#### [Tasks/registry/privacy/app-compat.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/app-compat.yml)

Configure Privacy -> Application Compatibility — Reachable task.

**Active action kinds:** registryValue: 6.

**Registry value names configured/deleted:** `AITEnable`, `DisableEngine`, `DisableInventory`, `DisablePCA`, `DisableUAR`, `SbEnable`.

#### [Tasks/registry/privacy/cdm.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/cdm.yml)

Configure Privacy -> Content Delivery Manager — Reachable task.

**Active action kinds:** registryKey: 4, registryValue: 40.

**Registry value names configured/deleted:** `ContentDeliveryAllowed`, `FeatureManagementEnabled`, `OemPreInstalledAppsEnabled`, `PreInstalledAppsEnabled`, `PreInstalledAppsEverEnabled`, `RemediationRequired`, `RotatingLockScreenEnabled`, `RotatingLockScreenOverlayEnabled`, `SilentInstalledAppsEnabled`, `SoftLandingEnabled`, `SubscribedContent-202914Enabled`, `SubscribedContent-280810Enabled`, `SubscribedContent-280811Enabled`, `SubscribedContent-280815Enabled`, `SubscribedContent-310093Enabled`, `SubscribedContent-314559Enabled`, `SubscribedContent-314563Enabled`, `SubscribedContent-338387Enabled`, `SubscribedContent-338389Enabled`, `SubscribedContentEnabled`.

#### [Tasks/registry/privacy/ceip.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/ceip.yml)

Configure Privacy -> Customer Experience Improvement Program (CEIP) — Reachable task.

**Active action kinds:** registryValue: 5.

**Registry value names configured/deleted:** `CEIP`, `CEIPEnable`, `CEIPEnabled`, `DisableCustomerImprovementProgram`.

#### [Tasks/registry/privacy/cloud-content.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/cloud-content.yml)

Configure Privacy -> Cloud Content — Reachable task.

**Active action kinds:** registryValue: 18.

**Registry value names configured/deleted:** `ConfigureWindowsSpotlight`, `DisableCloudOptimizedContent`, `DisableSoftLanding`, `DisableTailoredExperiencesWithDiagnosticData`, `DisableThirdPartySuggestions`, `DisableWindowsSpotlightFeatures`, `DisableWindowsSpotlightOnActionCenter`, `DisableWindowsSpotlightOnSettings`, `DisableWindowsSpotlightWindowsWelcomeExperience`, `IncludeEnterpriseSpotlight`.

#### [Tasks/registry/privacy/privacy.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/privacy.yml)

configure-privacy — Reachable task.

**Active action kinds:** registryValue: 47.

**Registry value names configured/deleted:** `ActivationType`, `AllowMessageSync`, `Block-Unified-Telemetry-Client`, `Block-Windows-Error-Reporting`, `CodecDownload`, `DisableContentFileUpdates`, `DisableHTTPPrinting`, `DisableHelpSticker`, `DisableMFUTracking`, `DisableWebPnPDownload`, `Disabled`, `DoReport`, `ExitOnMSICW`, `Headlines`, `MSAOptional`, `MicrosoftEventVwrDisableLinks`, `MicrosoftKBSearch`, `NoExplicitFeedback`, `NoGenTicket`, `NoImplicitFeedback`, `NoInternetOpenWith`, `NoOnlineAssist`, `NoOnlinePrintsWizard`, `NoPublishingWizard`, `NoRegistration`, `NoWebServices`, `OptInOrOutPreference`, `PreventHandwritingDataSharing`, `PreventHandwritingErrorReports`, `Server`, `WebHelp`, `WebPublish`.

#### [Tasks/registry/privacy/telemetry.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/telemetry.yml)

Configure Privacy -> Data Collection — Reachable task.

**Active action kinds:** registryValue: 23.

**Registry value names configured/deleted:** `AllowBuildPreview`, `AllowCommercialDataPipeline`, `AllowDeviceNameInTelemetry`, `AllowExperimentation`, `AllowTelemetry`, `DefaultValue`, `DisableEnterpriseAuthProxy`, `DisableTelemetryOptInChangeNotification`, `DisableTelemetryOptInSettingsUx`, `DoNotShowFeedbackNotifications`, `EnableConfigFlighting`, `LimitDiagnosticLogCollection`, `LimitDumpCollection`, `LimitEnhancedDiagnosticDataWindowsAnalytics`, `MicrosoftEdgeDataOptIn`, `Start`, `Value`, `value`.

#### [Tasks/registry/privacy/wer.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/privacy/wer.yml)

Configure Privacy -> Windows Error Reporting — Reachable task.

**Active action kinds:** registryValue: 9.

**Registry value names configured/deleted:** `0`, `AutoApproveOSDumps`, `DefaultConsent`, `DefaultOverrideBehavior`, `Disabled`, `DontSendAdditionalData`, `DontShowUI`, `LoggingDisabled`.

#### [Tasks/registry/security/bitlocker.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/security/bitlocker.yml)

Configure Security -> BitLocker — Not reached from main.yml.

**Active action kinds:** registryValue: 1.

**Registry value names configured/deleted:** `PreventDeviceEncryption`.

#### [Tasks/registry/security/security.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/security/security.yml)

Configure Security — Reachable task.

**Active action kinds:** registryValue: 11.

**Registry value names configured/deleted:** `AccountProtection_MicrosoftAccount_Disconnected`, `ConfigureAppInstallControl`, `ConfigureAppInstallControlEnabled`, `DisableGenericRePorts`, `DisableScheduledSignatureUpdateOnBattery`, `EnableWebContentEvaluation`, `EnabledV9`, `HideSystray`, `SecurityHealth`, `SubmitSamplesConsent`.

#### [Tasks/registry/security/vbs.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/security/vbs.yml)

Configure Security -> Virtualization Based Security — Reachable task.

**Active action kinds:** run: 1.

**Revision Tool commands:** `tweaks security vbs disable" # automatically disables Memory Integrity (HVCI) as well`.

#### [Tasks/registry/system/boot.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/boot.yml)

Configure boot — Reachable task.

**Active action kinds:** registryValue: 1.

**Registry value names configured/deleted:** `BootExecute`.

#### [Tasks/registry/system/bypass-requirements.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/bypass-requirements.yml)

Bypass requirements — Reachable task.

**Active action kinds:** registryValue: 11.

**Registry value names configured/deleted:** `AllowUpgradesWithUnsupportedTPMOrCPU`, `BypassCPUCheck`, `BypassNRO`, `BypassRAMCheck`, `BypassSecureBootCheck`, `BypassStorageCheck`, `BypassTPMCheck`, `SV1`, `SV2`.

#### [Tasks/registry/system/crash-control.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/crash-control.yml)

Configure Crash Control — Reachable task.

**Active action kinds:** registryValue: 2.

**Registry value names configured/deleted:** `AutoReboot`, `CrashDumpEnabled`.

#### [Tasks/registry/system/disable-automatic-maintenance.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/disable-automatic-maintenance.yml)

disable-automatic-maintenance — Reachable task.

**Active action kinds:** registryValue: 2.

**Registry value names configured/deleted:** `EnabledExecution`, `MaintenanceDisabled`.

#### [Tasks/registry/system/ifeo.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/ifeo.yml)

configure-ifeo — Reachable task.

**Active action kinds:** registryValue: 14.

**Registry value names configured/deleted:** `CpuPriorityClass`, `Debugger`, `IoPriority`.

#### [Tasks/registry/system/kernel.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/kernel.yml)

configure-kernel — Reachable task.

**Active action kinds:** run: 1.

**Revision Tool commands:** `tweaks performance intel-tsx enable`.

#### [Tasks/registry/system/logon.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/logon.yml)

Configure System -> Logon — Reachable task.

**Active action kinds:** registryValue: 2.

**Registry value names configured/deleted:** `DisableStartupSound`, `EnableFirstLogonAnimation`.

#### [Tasks/registry/system/multimedia.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/multimedia.yml)

configure-multimedia — Reachable task.

**Active action kinds:** registryValue: 1.

**Registry value names configured/deleted:** `NetworkThrottlingIndex`.

#### [Tasks/registry/system/oobe.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/oobe.yml)

configure-oobe — Reachable task.

**Active action kinds:** registryValue: 25.

**Registry value names configured/deleted:** `DisablePrivacyExperience`, `DisableVoice`, `EnableCortanaVoice`, `HideEULAPage`, `HideLocalAccountScreen`, `HideOEMRegistrationScreen`, `HideOnlineAccountScreens`, `HideWirelessSetupInOOBE`, `NetworkLocation`, `ProtectYourPC`, `SkipMachineOOBE`, `SkipUserOOBE`, `Skype-UserConsentAccepted`.

#### [Tasks/registry/system/power.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/power.yml)

configure-power-control — Reachable task.

**Active action kinds:** registryValue: 2, run: 4.

**Registry value names configured/deleted:** `ShowSleepOption`, `ShutdownWithoutLogon`.

**Revision Tool commands:** `tweaks utilities hibernation disable`, `tweaks utilities fast-startup disable`, `tweaks utilities hibernation enable`, `tweaks utilities fast-startup enable`.

#### [Tasks/registry/system/win32ps.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/system/win32ps.yml)

Configure System -> Win32PrioritySeparation — Reachable task.

**Active action kinds:** registryValue: 1.

**Registry value names configured/deleted:** `Win32PrioritySeparation`.

#### [Tasks/registry/updates/drivers.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/updates/drivers.yml)

Configure Updates -> Drivers — Reachable task.

**Active action kinds:** run: 1.

**Revision Tool commands:** `tweaks updates wu-drivers disable`.

#### [Tasks/registry/updates/ms-store.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/updates/ms-store.yml)

Configure Updates -> Microsoft Store — Reachable task.

**Active action kinds:** registryValue: 2.

**Registry value names configured/deleted:** `AutoDownload`, `DisableOSUpgrade`.

#### [Tasks/registry/updates/updates.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry/updates/updates.yml)

Configure general updates settings — Reachable task.

**Active action kinds:** registryKey: 2, registryValue: 11, run: 1.

**Registry value names configured/deleted:** `AllowBuildPreview`, `BlockedOobeUpdaters`, `DODownloadMode`, `DisableAutoUpdate`, `DontReportInfectionInformation`, `HideMCTLink`, `RestartNotificationsAllowed2`, `ShippedWithReserves`, `UpgradeAvailable`, `workCompleted`.

**Revision Tool commands:** `tweaks updates wu-pause-updates enable`.

#### [Tasks/registry.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/registry.yml)

Registry — Reachable task.

**Active action kinds:** task: 41, writeStatus: 7.

#### [Tasks/revert.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/revert.yml)

Rollback Tweaks — Reachable task; upgrade-only.

**Active action kinds:** appx: 1, registryKey: 9, registryValue: 36, run: 3, service: 5, writeStatus: 1.

**Action option conditions:** `!disable-automatic-maintenance`, `!remove-appx-xbox`.

**Registry value names configured/deleted:** `AllowInputPersonalization`, `AllowWindowsEntitlementReactivation`, `AppCaptureEnabled`, `CheckExeSignatures`, `ClearBrowsingHistoryOnExit`, `ConnectedSearchSafeSearch`, `DisableAutomaticRestartSignOn`, `DisableFileSyncNGSC`, `DisableFixSecuritySettings`, `DisableRootAutoUpdate`, `DisableScheduledSignatureUpdateOnBattery`, `DisableSecuritySettingsCheck`, `DisableWindowsConsumerFeatures`, `Enable`, `EnableAutoLayout`, `EnableAutoTray`, `EnabledExecution`, `FeatureSettings`, `FeatureSettingsOverride`, `FeatureSettingsOverrideMask`, `HeapDeCommitFreeBlockThreshold`, `IsModernRCEnabled`, `MaintenanceDisabled`, `ModelDownloadAllowed`, `MouseHoverTime`, `RegisteredOrganisation`, `RepairContentServerSource`, `RestrictCommunication`, `SvcHostSplitThresholdInKB`, `VulnerableDriverBlocklistEnable`.

**Active service operations:** `name: 'bam', operation: change, startup: 1`; `name: 'Beep', operation: change, startup: 1} `; `name: 'GraphicsPerfSvc', operation: change, startup: 3`; `name: 'Ndu', operation: change, startup: 2`; `name: 'DPS', operation: change, startup: 2`.

**Revision Tool commands:** `tweaks performance superfetch enable`, `tweaks performance background-apps enable`.

#### [Tasks/services.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/services.yml)

Services — Reachable task.

**Active action kinds:** powerShell: 1, service: 16, writeStatus: 1.

**Active service operations:** `name: 'dam', operation: change, startup: 4`; `name: 'GpuEnergyDrv', operation: change, startup: 4`; `name: 'NetBT', operation: change, startup: 4`; `name: 'Telemetry', operation: change, startup: 4`; `name: 'diagnosticshub.standardcollector.service', operation: change, startup: 4`; `name: 'WerSvc', operation: change, startup: 4`; `name: 'DiagTrack', operation: change, startup: 4`; `name: 'wisvc', operation: change, startup: 4`; `name: 'PcaSvc', operation: change, startup: 4`; `name: 'WdiServiceHost', operation: change, startup: 4`; `name: 'WdiSystemHost', operation: change, startup: 4`; `name: 'tcpipreg', operation: change, startup: 4`; `name: 'edgeupdate', operation: change, startup: 3`; `name: 'Wecsvc', operation: change, startup: 4} `; `name: 'UCPD', operation: change, startup: 4`; `name: 'condrv', operation: change, startup: 2} `.

#### [Tasks/software.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/software.yml)

Software — Reachable task.

**Active action kinds:** cmd: 1, download: 2, run: 2, software: 1, status: 3.

**Action option conditions:** `browser-brave`, `browser-firefox`.

#### [Tasks/start.yml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Configuration/Tasks/start.yml)

Initialization — Reachable task.

**Active action kinds:** cmd: 3, download: 2, registryValue: 1, run: 4, writeStatus: 5.

**Registry value names configured/deleted:** `Enabled`.

**Revision Tool commands:** `tweaks performance powerplan enable`.

### Executable helpers and configuration assets

| Source file | Role |
| --- | --- |
| [Executables/APPX-REMOVER.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/APPX-REMOVER.ps1) | Protected/non-removable AppX removal, EndOfLife/deprovisioning edits |
| [Executables/assoc.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/assoc.ps1) | Association helper |
| [Executables/CLEANER.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/CLEANER.ps1) | Cleanup, event log clearing, reserved storage changes |
| [Executables/DefaultLayouts.xml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/DefaultLayouts.xml) | Layout defaults |
| [Executables/DISM-FEATURES.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/DISM-FEATURES.ps1) | Optional features; associated task is not reached by main.yml |
| [Executables/EDGE.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/EDGE.ps1) | Edge removal helper |
| [Executables/FILEASSOC.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/FILEASSOC.cmd) | Association setup after Photos removal |
| [Executables/FINALIZE.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/FINALIZE.cmd) | Deployment finalization |
| [Executables/LayoutModification.json](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/LayoutModification.json) | Start pins |
| [Executables/LayoutModification.xml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/LayoutModification.xml) | Start/taskbar layout |
| [Executables/ngen.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/ngen.ps1) | Native image generation for PowerShell/.NET |
| [Executables/OEMDefaultAssociations.xml](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/OEMDefaultAssociations.xml) | Default associations |
| [Executables/ONED.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/ONED.cmd) | OneDrive removal helper |
| [Executables/Set-Theme.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/Set-Theme.ps1) | Theme selection/creation |
| [Executables/settings.json](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/settings.json) | Settings data |
| [Executables/STARTMENU.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/STARTMENU.cmd) | Start pins/layout |
| [Executables/UPDATE-APPX.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/UPDATE-APPX.ps1) | AppX update helper |
| [Executables/WALLPAPER.ps1](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/WALLPAPER.ps1) | Desktop/lockscreen wallpaper |
| [Executables/WallpaperStartup.cmd](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/WallpaperStartup.cmd) | Wallpaper startup |


Also inspected: [hosts replacement/blocklist](https://github.com/meetrevision/playbook/blob/b6c1cd400f245e827d9d8a91b0f1ecdc965b1d30/src/Executables/hosts). Wallpaper/browser image binaries are assets, not separate tweaks. The DISM helper lists DirectPlay/LegacyComponents enablement and disabling PowerShell v2, MSRDC infrastructure, printing foundation/internet printing and Work Folders; this is an available helper inventory, not a claim those actions run from main.yml.

</details>

<details>
<summary>C. Revision Tool: all 38 tweak controls and additional Store, CAB, registry and tool operations</summary>

### All declared tweak CLI controls

The five service interfaces define 38 controls: 15 performance, eight personalization, five security, five updates and five utilities. A toggle supports status/enable/disable; enum/value controls provide selections. Mitigation selections include Meltdown/Spectre and Downfall. Notification modes are on/minimal off/full off. Service grouping modes are forced/recommended/disabled.

#### performance

[Pinned service implementation](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/performance/performance_service.dart)

| Control | Kind |
| --- | --- |
| powerplan | Toggle |
| powerplan-states-c6 | Toggle |
| superfetch | Toggle |
| memory-compression | Toggle |
| intel-tsx | Toggle |
| swapchain-fso | Toggle |
| swapchain-wo | Toggle |
| swapchain-mpo | Toggle |
| background-apps | Toggle |
| ctfmon-input | Toggle |
| ntfs-last-access | Toggle |
| ntfs-8dot3-naming | Toggle |
| ntfs-memory-usage | Toggle |
| service-grouping | EnumSubCommand |
| background-window-message-rate-limit | Value |

#### personalization

[Pinned service implementation](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/personalization/personalization_service.dart)

| Control | Kind |
| --- | --- |
| notification | EnumSubCommand |
| legacy-balloon | Toggle |
| screen-edge-swipe | Toggle |
| new-context-menu | Toggle |
| input-personalization | Toggle |
| caps-lock | Toggle |
| explorer-home | Toggle |
| explorer-gallery | Toggle |

#### security

[Pinned service implementation](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/security/security_service.dart)

| Control | Kind |
| --- | --- |
| defender | Toggle |
| uac | Toggle |
| mitigation | EnumSubCommand |
| vbs | Toggle |
| memory-integrity | Toggle |

#### updates

[Pinned service implementation](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/updates/updates_service.dart)

| Control | Kind |
| --- | --- |
| certificates | Action |
| kgl | Action |
| wu-pause-updates | Toggle |
| wu-visibility | Toggle |
| wu-drivers | Toggle |

#### utilities

[Pinned service implementation](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/utilities/utilities_service.dart)

| Control | Kind |
| --- | --- |
| hibernation | Toggle |
| fast-startup | Toggle |
| modern-standby | Toggle |
| tm-monitoring | Toggle |
| usage-reporting | Toggle |

### Other exposed operations

| Operation | Evidence |
| --- | --- |
| Patch deployment: disable update drivers and enable long update pause | [src/lib/features/tweaks/tweaks_command.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/tweaks/tweaks_command.dart) |
| Hide/unhide a Settings page | [src/lib/core/services/win_registry_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/core/services/win_registry_service.dart) |
| Microsoft Store product search/details, package/dependency download and installation | [src/lib/features/ms_store/domain/services/store_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/ms_store/domain/services/store_service.dart) |
| Install, uninstall and manage CAB removal-package types: system components, Defender, AI, OneDrive, Xbox | [src/lib/features/winsxs/domain/entities/win_package.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/winsxs/domain/entities/win_package.dart); [src/lib/features/winsxs/presentation/win_package_command.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/features/winsxs/presentation/win_package_command.dart) |
| Tool self-update, language/theme and GUI settings | [src/lib/core/settings/tool_update_service.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/core/settings/tool_update_service.dart); [src/lib/core/settings/settings_page.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/core/settings/settings_page.dart) |
| CLI entry point and command routing | [src/lib/main_cli.dart](https://github.com/meetrevision/revision-tool/blob/a0254925ce1afe9a4e18e3a1880f420d02f65e4d/src/lib/main_cli.dart) |


</details>

<details>
<summary>D. ReviOS component packages: every active target in all ten AMD64/ARM64 manifests</summary>

### Manifest coverage

All active `target_component` entries were extracted, with duplicate architecture/resource entries deduplicated by exact component name. Commented-out removals are excluded. These are **package definitions**, not a report of installed/removable components on your machine. `xbox-removal` is exposed by Revision Tool; the examined playbook primarily removes Xbox AppX packages conditionally rather than calling that CAB directly.

| Manifest | Unique active target names |
| --- | --- |
| [ai-removal-amd64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/ai-removal-amd64.yaml) | 16 |
| [ai-removal-arm64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/ai-removal-arm64.yaml) | 16 |
| [defender-removal-amd64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/defender-removal-amd64.yaml) | 109 |
| [defender-removal-arm64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/defender-removal-arm64.yaml) | 103 |
| [onedrive-removal-amd64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/onedrive-removal-amd64.yaml) | 8 |
| [onedrive-removal-arm64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/onedrive-removal-arm64.yaml) | 8 |
| [systemPackages-removal-amd64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/systemPackages-removal-amd64.yaml) | 135 |
| [systemPackages-removal-arm64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/systemPackages-removal-arm64.yaml) | 129 |
| [xbox-removal-amd64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/xbox-removal-amd64.yaml) | 33 |
| [xbox-removal-arm64.yaml](https://github.com/meetrevision/packages/blob/3c2231a16c5e7df18a70bffbc5702c5d077cab12/xbox-removal-arm64.yaml) | 33 |

### systemPackages removal — 135 names across architectures

| Target component | AMD64 | ARM64 |
| --- | --- | --- |
| Adobe-Flash-For-Windows | Yes | Yes |
| Microsoft-OneCore-SystemSettings-InputCloudStore | Yes | Yes |
| Microsoft-OneCoreUAP-Feedback-StringFeedbackEngine | Yes | Yes |
| Microsoft-Windows-AdvertisingId | Yes | Yes |
| Microsoft-Windows-Application-Experience-AIT-Static | Yes | Yes |
| Microsoft-Windows-Application-Experience-AppInv | Yes | Yes |
| Microsoft-Windows-Application-Experience-Core-Inventory-Service | Yes | Yes |
| Microsoft-Windows-Application-Experience-Inventory-Data-Sources | Yes | Yes |
| Microsoft-Windows-Application-Experience-Mitigations-C8 | Yes | Yes |
| Microsoft-Windows-Application-Experience-Program-Data | Yes | Yes |
| Microsoft-Windows-Application-Experience-Program-Data.Resources | Yes | Yes |
| Microsoft-Windows-BingSearch | Yes | Yes |
| Microsoft-Windows-Bubbles | Yes | Yes |
| Microsoft-Windows-Bubbles.Resources | Yes | Yes |
| Microsoft-Windows-BuildFlighting | Yes | Yes |
| Microsoft-Windows-CEIPEnable-Adm | Yes | Yes |
| Microsoft-Windows-CEIPEnable-Adm-Deployment | Yes | Yes |
| Microsoft-Windows-CEIPEnable-Adm-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-CEIPEnable-Adm.Resources | Yes | Yes |
| Microsoft-Windows-Client-SQM-Consolidator | Yes | Yes |
| Microsoft-Windows-Compat-Appraiser | Yes | Yes |
| Microsoft-Windows-Compat-Appraiser-InboxDataFiles | Yes | Yes |
| Microsoft-Windows-Compat-Appraiser-Logger | Yes | Yes |
| Microsoft-Windows-Compat-CompatTelRunner | Yes | Yes |
| Microsoft-Windows-Compat-CompatTelRunner-DailyTask | Yes | Yes |
| Microsoft-Windows-Compat-CompatTelRunner.Resources | Yes | Yes |
| Microsoft-Windows-Compat-GeneralTel | Yes | Yes |
| Microsoft-Windows-Compat-Inventory-NonArpInv | Yes | Yes |
| Microsoft-Windows-DataCollection-Adm | Yes | Yes |
| Microsoft-Windows-DataCollection-Adm.Resources | Yes | Yes |
| Microsoft-Windows-ErrorReportingCompatibility | Yes | Yes |
| Microsoft-Windows-ErrorReportingConsole | Yes | Yes |
| Microsoft-Windows-ErrorReportingCore | Yes | Yes |
| Microsoft-Windows-ErrorReportingDumpTypeControl-Deployment | Yes | Yes |
| Microsoft-Windows-ErrorReportingPowershell | Yes | Yes |
| Microsoft-Windows-ErrorReportingUI | Yes | Yes |
| Microsoft-Windows-Feedback-CourtesyEngine | Yes | Yes |
| Microsoft-Windows-Feedback-DeploymentMgrClient | Yes | Yes |
| Microsoft-Windows-Feedback-DeploymentMgrClient-Desktop-TaskSch | Yes | Yes |
| Microsoft-Windows-Feedback-Service | Yes | Yes |
| Microsoft-Windows-Feedback-Service.Resources | Yes | Yes |
| Microsoft-Windows-FeedbackNotifications-Adm | Yes | Yes |
| Microsoft-Windows-FeedbackNotifications-Adm.Resources | Yes | Yes |
| Microsoft-Windows-Flighting-FeatureConfiguration-Tasks | Yes | Yes |
| Microsoft-Windows-Flighting-Settings | Yes | Yes |
| Microsoft-Windows-Flighting-Settings.Resources | Yes | Yes |
| Microsoft-Windows-FlipGridPWA | Yes | Yes |
| Microsoft-Windows-FlipGridPWA-Deployment | Yes | Yes |
| Microsoft-Windows-FlipGridPWA-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-Indeo4-Codecs | Yes | Yes |
| Microsoft-Windows-Indeo4-Codecs.Resources | Yes | Yes |
| Microsoft-Windows-Indeo5-Codecs | Yes | Yes |
| Microsoft-Windows-Indeo5-Codecs.Resources | Yes | Yes |
| Microsoft-Windows-KeyboardDiagnostic | Yes | Yes |
| Microsoft-Windows-KeyboardDiagnostic.Resources | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Browser.AppxMain | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Browser.AppxMain.Resources | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Browser.AppxSetup | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Capabilities | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Config | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Deployment | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Diagnostics | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-Diagnostics.Resources | Yes | Yes |
| Microsoft-Windows-Management-SecureAssessment-platforminterop | Yes | Yes |
| Microsoft-Windows-Mystify | Yes | Yes |
| Microsoft-Windows-Mystify.Resources | Yes | Yes |
| Microsoft-Windows-OOBE-FirstLogonAnim | Yes | Yes |
| Microsoft-Windows-OOBE-FirstLogonAnim.Resources | Yes | Yes |
| Microsoft-Windows-OOBE-FirstLogonAnimExe | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-Deployment | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-WOW64-Deployment | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-WOW64-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-OneDrive-SetupRegistry | Yes | Yes |
| Microsoft-Windows-OutlookPWA | Yes | Yes |
| Microsoft-Windows-OutlookPWA-Deployment | Yes | Yes |
| Microsoft-Windows-OutlookPWA-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-PeopleExperienceHost.AppxMain | Yes | Yes |
| Microsoft-Windows-PeopleExperienceHost.AppxMain.Resources | Yes | Yes |
| Microsoft-Windows-PeopleExperienceHost.AppxSetup | Yes | Yes |
| Microsoft-Windows-PhotoBasic-Feature-WOW64-Deployment | Yes | Yes |
| Microsoft-Windows-PhotoBasic-Feature-WOW64-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-PhotoBasic-PictureTools-WOW64-Deployment | Yes | Yes |
| Microsoft-Windows-PhotoBasic-PictureTools-WOW64-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-PhotoBasic-WOW64-merged-Deployment | Yes | Yes |
| Microsoft-Windows-PhotoBasic-WOW64-merged-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-PhotoScreensaver | Yes | Yes |
| Microsoft-Windows-PhotoScreensaver.Resources | Yes | Yes |
| Microsoft-Windows-PortableWorkspaces-SSO | Yes | — |
| Microsoft-Windows-PortableWorkspaces-SSO.Resources | Yes | — |
| Microsoft-Windows-PortableWorkspaces-SysPrep | Yes | Yes |
| Microsoft-Windows-QuickAssist | Yes | Yes |
| Microsoft-Windows-QuickAssist-Deployment | Yes | Yes |
| Microsoft-Windows-QuickAssist-FOD-wow64-Deployment | Yes | — |
| Microsoft-Windows-QuickAssist.Resources | Yes | Yes |
| Microsoft-Windows-RetailDemo-RetailInfo | Yes | Yes |
| Microsoft-Windows-RetailDemo-Service | Yes | Yes |
| Microsoft-Windows-RetailDemo-Service.Deployment | Yes | Yes |
| Microsoft-Windows-RetailDemo-Service.Instrumentation | Yes | Yes |
| Microsoft-Windows-RetailDemo-Service.Resources | Yes | Yes |
| Microsoft-Windows-Ribbons | Yes | Yes |
| Microsoft-Windows-Ribbons.Resources | Yes | Yes |
| Microsoft-Windows-SQM-Consolidator | Yes | Yes |
| Microsoft-Windows-SQM-Consolidator-Base | Yes | Yes |
| Microsoft-Windows-SQM-Consolidator-Base.Resources | Yes | Yes |
| Microsoft-Windows-Services-TargetedContent | Yes | Yes |
| Microsoft-Windows-SetupPlatform-Telemetry-AutoLogger | Yes | Yes |
| Microsoft-Windows-Shell-RetailDemo-DesktopTaskFactory | Yes | Yes |
| Microsoft-Windows-Shell-SoundThemes | Yes | Yes |
| Microsoft-Windows-Skype-ORTC | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-Flights | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-Flights.Resources | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-OneDriveBackup | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-SIUF | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-SIUF.Resources | Yes | Yes |
| Microsoft-Windows-TelemetryClient | Yes | Yes |
| Microsoft-Windows-UNP | Yes | Yes |
| Microsoft-Windows-UNP-Task | Yes | Yes |
| Microsoft-Windows-Unified-Telemetry-Client-Aggregators | Yes | Yes |
| Microsoft-Windows-Unified-Telemetry-Client-AutoLogger-Default | Yes | Yes |
| Microsoft-Windows-Unified-Telemetry-Client-Decoder-Host | Yes | Yes |
| Microsoft-Windows-Unified-Telemetry-Client-Settings-WindowsClient | Yes | Yes |
| Microsoft-Windows-Unified-Telemetry-Client.resources | Yes | Yes |
| Microsoft-Windows-Update-Aggregators | Yes | Yes |
| Microsoft-Windows-UsbCeip | Yes | Yes |
| Microsoft-Windows-UsbCeip.Resources | Yes | Yes |
| Microsoft-Windows-scrnsave | Yes | Yes |
| Microsoft-Windows-scrnsave.Resources | Yes | Yes |
| Microsoft-Windows-shimgvw | Yes | Yes |
| Microsoft-Windows-ssText3d | Yes | — |
| Microsoft-Windows-ssText3d.Resources | Yes | — |
| Windows-System-Diagnostics-Telemetry-PlatformTelemetryClient | Yes | — |
| Windows-System-Diagnostics-TraceReporting-PlatformDiagnosticActions | Yes | Yes |

### ai removal — 16 names across architectures

| Target component | AMD64 | ARM64 |
| --- | --- | --- |
| Microsoft-AIFabric-CBS-1-6 | Yes | Yes |
| Microsoft-Copilot | Yes | Yes |
| Microsoft-Copilot-Deployment | Yes | Yes |
| Microsoft-Copilot-Deployment-LanguagePack | Yes | Yes |
| Microsoft-OneCore-AgenticPlatform | Yes | Yes |
| Microsoft-OneCore-CapabilityAccess-Adm-windowsAI | Yes | Yes |
| Microsoft-OneCore-CapabilityAccess-Adm-windowsAI.Resources | Yes | Yes |
| Microsoft-OneCore-IsoEnvBroker | Yes | Yes |
| Microsoft-OneCore-IsoEnvBroker.Resources | Yes | Yes |
| Microsoft-Windows-AIComponentMgmt | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-Copilot | Yes | Yes |
| Revision-ReviOS-AI-Registry | Yes | Yes |
| UserExperience-AIX | Yes | Yes |
| UserExperience-AIX-Deployment | Yes | Yes |
| UserExperience-CoreAI | Yes | Yes |
| UserExperience-CoreAI-Deployment | Yes | Yes |

### defender removal — 111 names across architectures

| Target component | AMD64 | ARM64 |
| --- | --- | --- |
| Microsoft-OneCore-WebThreatDefense-Adm | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Adm.Resources | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-ClipboardMonitor | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Driver | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Driver-Client-Host | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Driver-Client-Sensor | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Driver.Resources | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-SecretFilterAP | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Service | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-Service.Resources | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-ThreatAssessment | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-ThreatExperienceManager | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-ThreatExperienceManager.Resources | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-ThreatIntelligence | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-User-Service | Yes | Yes |
| Microsoft-OneCore-WebThreatDefense-User-Service.Resources | Yes | Yes |
| Microsoft-Onecore-WebThreatDefense-ThreatResponseEngine | Yes | Yes |
| Microsoft-Windows-AppRep | Yes | Yes |
| Microsoft-Windows-AppRep-ChxApp.appxmain | Yes | Yes |
| Microsoft-Windows-AppRep-ChxApp.appxmain.resources | Yes | Yes |
| Microsoft-Windows-AppRep-ChxApp.appxsetup | Yes | Yes |
| Microsoft-Windows-DeviceManagement-CspDefinition-Defender | Yes | Yes |
| Microsoft-Windows-DeviceManagement-PolicyDefinition-ADMXWindowsDefender | Yes | Yes |
| Microsoft-Windows-DeviceManagement-PolicyDefinition-Defender | Yes | Yes |
| Microsoft-Windows-DeviceManagement-PolicyDefinition-DefenderSecCenter | Yes | Yes |
| Microsoft-Windows-DeviceManagement-PolicyDefinition-ExploitGuard | Yes | — |
| Microsoft-Windows-DeviceManagement-PolicyDefinition-SmartScreen | Yes | Yes |
| Microsoft-Windows-DeviceManagement-PolicyDefinition-WebThreatDefense | Yes | Yes |
| Microsoft-Windows-ExploitGuard-Adm | Yes | Yes |
| Microsoft-Windows-ExploitGuard-Adm.Resources | Yes | Yes |
| Microsoft-Windows-ExploitGuard-MitigationConfiguration | Yes | Yes |
| Microsoft-Windows-ExploitGuard-MitigationConfiguration.Resources | Yes | Yes |
| Microsoft-Windows-MsSecCore.Resources | Yes | Yes |
| Microsoft-Windows-MsSecWfp.Resources | Yes | Yes |
| Microsoft-Windows-MssecFilter.Resources | Yes | Yes |
| Microsoft-Windows-SenseClient-Deployment | Yes | Yes |
| Microsoft-Windows-SenseClient-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-SmartScreen | Yes | Yes |
| Microsoft-Windows-SmartScreen-Adm | Yes | Yes |
| Microsoft-Windows-SmartScreen-Adm.Resources | Yes | Yes |
| Microsoft-Windows-SmartScreen.Resources | Yes | Yes |
| Revision-ReviOS-Defender-Removal-Registry | Yes | Yes |
| Security-Malware-Windows-Defender | Yes | Yes |
| Security-Octagon-Agent | Yes | — |
| Security-Octagon-Broker | Yes | — |
| Security-Octagon-Broker.Resources | Yes | — |
| Security-Octagon-BrokerAutoStart | Yes | — |
| Security-Octagon-ClientApi | Yes | — |
| Security-Octagon-Enclave | Yes | — |
| Security-Octagon-SgrmAssertions | Yes | — |
| Windows-Defender-AM-Default-Definitions-Deployment | Yes | Yes |
| Windows-Defender-AM-Default-Definitions-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-AM-Engine | Yes | Yes |
| Windows-Defender-AM-Sigs | Yes | Yes |
| Windows-Defender-AppLayer-Group-Deployment | Yes | Yes |
| Windows-Defender-AppLayer-Group-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-ApplicationGuard-Inbox-Deployment | Yes | Yes |
| Windows-Defender-ApplicationGuard-Inbox-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-ApplicationGuard-Inbox-WOW64-Deployment | Yes | Yes |
| Windows-Defender-ApplicationGuard-Inbox-WOW64-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-ApplicationGuard-Inbox-arm64arm-Deployment | — | Yes |
| Windows-Defender-ApplicationGuard-Inbox-arm64arm-Deployment-LanguagePack | — | Yes |
| Windows-Defender-Branding | Yes | Yes |
| Windows-Defender-Branding.Resources | Yes | Yes |
| Windows-Defender-Core-Group-Deployment | Yes | Yes |
| Windows-Defender-Core-Group-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-Drivers | Yes | Yes |
| Windows-Defender-Drivers-Backup | Yes | Yes |
| Windows-Defender-Drivers-NisDrvWfpEtw | Yes | Yes |
| Windows-Defender-Events | Yes | Yes |
| Windows-Defender-Events.Resources | Yes | Yes |
| Windows-Defender-Global-Config | Yes | Yes |
| Windows-Defender-Group-Policy | Yes | Yes |
| Windows-Defender-Group-Policy-Deployment | Yes | Yes |
| Windows-Defender-Group-Policy-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-Group-Policy.Resources | Yes | Yes |
| Windows-Defender-Management-Group-Deployment | Yes | Yes |
| Windows-Defender-Management-Group-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-Management-MDM | Yes | Yes |
| Windows-Defender-Management-MDM-Group-Deployment | Yes | Yes |
| Windows-Defender-Management-MDM-Group-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-Management-Onecore | Yes | Yes |
| Windows-Defender-Management-Onecore.Resources | Yes | Yes |
| Windows-Defender-Management-Powershell | Yes | Yes |
| Windows-Defender-Management-Powershell-Group-Deployment | Yes | Yes |
| Windows-Defender-Management-Powershell-Group-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-Management-V1 | Yes | Yes |
| Windows-Defender-Nis-Drivers | Yes | Yes |
| Windows-Defender-Nis-Group-Deployment | Yes | Yes |
| Windows-Defender-Nis-Group-Deployment-LanguagePack | Yes | Yes |
| Windows-Defender-Nis-Service | Yes | Yes |
| Windows-Defender-Offline-Amcore | Yes | Yes |
| Windows-Defender-Offline-Amcore.Resources | Yes | Yes |
| Windows-Defender-Offline-Onecore | Yes | Yes |
| Windows-Defender-Service | Yes | Yes |
| Windows-Defender-Service-MpClientEtw | Yes | Yes |
| Windows-Defender-Service-MpRtpEtw | Yes | Yes |
| Windows-Defender-Service-MpSvcEtw | Yes | Yes |
| Windows-Defender-Service.Resources | Yes | Yes |
| Windows-Defender-UI | Yes | Yes |
| Windows-Defender-UI.Resources | Yes | Yes |
| Windows-SECDriver | Yes | Yes |
| Windows-SecCoreDriver | Yes | Yes |
| Windows-SecWfpDriver | Yes | Yes |
| Windows-SecurityHealth-SSO | Yes | Yes |
| Windows-SecurityHealth-SSO.Resources | Yes | Yes |
| Windows-SenseClient-MDM | Yes | Yes |
| Windows-SenseClient-Service | Yes | Yes |
| Windows-SenseClient-Service.Resources | Yes | Yes |
| Windows-Shield-Provider | Yes | Yes |
| Windows-Shield-Provider.Resources | Yes | Yes |

### onedrive removal — 8 names across architectures

| Target component | AMD64 | ARM64 |
| --- | --- | --- |
| Microsoft-Windows-OneDrive-Setup | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-Deployment | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-WOW64-Deployment | Yes | Yes |
| Microsoft-Windows-OneDrive-Setup-WOW64-Deployment-LanguagePack | Yes | Yes |
| Microsoft-Windows-OneDrive-SetupRegistry | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-OneDriveBackup | Yes | Yes |
| Microsoft-Windows-SystemSettings-SettingsHandlers-OneDriveBackup.Resources | Yes | Yes |

### xbox removal — 33 names across architectures

| Target component | AMD64 | ARM64 |
| --- | --- | --- |
| Microsoft-Gaming-GameBar-Internal-PresenceWriter | Yes | Yes |
| Microsoft-Media-Capture-Internal-BroadcastDVR | Yes | Yes |
| Microsoft-Media-Capture-Internal-BroadcastDVR.Resources | Yes | Yes |
| Microsoft-OneCore-Multimedia-BroadcastDVR | Yes | Yes |
| Microsoft-OneCore-Multimedia-BroadcastDVR-Capabilities | Yes | Yes |
| Microsoft-Windows-GDVR-Adm | Yes | Yes |
| Microsoft-Windows-GDVR-Adm.Resources | Yes | Yes |
| Microsoft-Windows-Gaming-Services-Instrumentation | Yes | Yes |
| Microsoft-Windows-XboxAccessory-Capabilities | Yes | Yes |
| Microsoft-Xbox-AuthManager-Client-Component | Yes | Yes |
| Microsoft-Xbox-AuthManager-Component | Yes | Yes |
| Microsoft-Xbox-AuthManager-Component.Resources | Yes | Yes |
| Microsoft-Xbox-GameCallableUI.appxmain | Yes | Yes |
| Microsoft-Xbox-GameCallableUI.appxmain.resources | Yes | Yes |
| Microsoft-Xbox-GameCallableUI.appxsetup | Yes | Yes |
| Microsoft-Xbox-GameCallableUI.toolkit | Yes | Yes |
| Microsoft-Xbox-GameChatOverlayExt | Yes | Yes |
| Microsoft-Xbox-GameChatTranscription-Component | Yes | Yes |
| Microsoft-Xbox-GameOverlay | Yes | Yes |
| Microsoft-Xbox-GameOverlay.Resources | Yes | Yes |
| Microsoft-Xbox-GameStreamingExt-Component | Yes | Yes |
| Microsoft-Xbox-ShellCore-GamingUI-Component | Yes | Yes |
| Windows-Gaming-Preview-GamesEnumeration-WinRT | Yes | Yes |
| Windows-Gaming-UI-GameBar-Component | Yes | Yes |
| Windows-Gaming-XboxLive-Storage-Client-Component | Yes | Yes |
| Windows-Gaming-XboxLive-Storage-Service-Component | Yes | Yes |
| Windows-Gaming-XboxLive-Storage-Service-Component.Resources | Yes | Yes |
| Windows-Gaming-XboxLive-Storage-WinRT-Common-Component | Yes | Yes |
| Windows-Gaming-XboxLive-Storage-WinRT-Component | Yes | Yes |
| Windows-Gaming-XboxLive-Storage-XblGameSaveExt-OneCore-Component | Yes | Yes |
| Windows-Internal-Gaming-ForceFeedback-WinRT | Yes | Yes |
| Windows-Networking-XboxLive-Windows-Component | Yes | Yes |
| Windows-Networking-XboxLive-Windows-Component.Resources | Yes | Yes |


</details>

<details>
<summary>E. Win11Debloat: every feature/build gate, defaults, execution controls and removal catalogue</summary>

### All 103 feature definitions

[Pinned feature map](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Features.json); [actual registry files](https://github.com/Raphire/Win11Debloat/tree/32024662f3c602442e7af82bbf52c89143b31aeb/Regfiles).

Build gates below are declared numeric build checks, not comprehensive edition/hardware applicability. App-removal parameters and mutually exclusive UI alternatives are included. Undo mappings live in the feature map and Regfiles/Undo; saved registry-state restore is a separate mechanism.

| Feature ID | Feature | Implementation | Declared build gate |
| --- | --- | --- | --- |
| RemoveApps | Remove the apps specified with the 'Apps' parameter | Custom operation / parameter | No gate declared |
| Apps | The selection of apps to remove, specified as a comma separated list. Use 'Default' (or omit) to use the default apps list | Custom operation / parameter | No gate declared |
| RemoveGamingApps | Remove the Xbox App and Xbox Gamebar | Custom operation / parameter | No gate declared |
| RemoveHPApps | Remove HP OEM applications | Custom operation / parameter | No gate declared |
| CreateRestorePoint | Create a system restore point | Custom operation / parameter | No gate declared |
| DisableTelemetry | Disable telemetry, tracking & targeted ads | Disable_Telemetry.reg | No gate declared |
| DisableSuggestions | Disable tips, tricks & suggested content throughout Windows | Disable_Windows_Suggestions.reg | No gate declared |
| DisableNotifications | Disable Windows Notifications (From apps and other senders) | Disable_Notifications.reg | No gate declared |
| DisableLocationServices | Disable Windows location services & app location access | Disable_Location_Services.reg | No gate declared |
| DisableFindMyDevice | Disable Find My Device location tracking | Disable_Find_My_Device.reg | No gate declared |
| DisableLockscreenTips | Disable tips & tricks on the lock screen | Disable_Lockscreen_Tips.reg | No gate declared |
| EnableDesktopSpotlight | Enable Windows spotlight desktop background and shortcut | Enable_Desktop_Spotlight.reg | No gate declared |
| DisableDesktopSpotlight | Disable Windows spotlight desktop background | Disable_Desktop_Spotlight.reg | No gate declared |
| HideDesktopSpotlightIcon | Hide the 'Learn about this picture' desktop shortcut | Hide_Desktop_Spotlight_Icon.reg | No gate declared |
| DisableEdgeAds | Disable ads, suggestions and newsfeed in Edge | Disable_Edge_Ads_And_Suggestions.reg | No gate declared |
| DisableCopilot | Disable Microsoft Copilot | Disable_Copilot.reg | >= 22621 |
| DisableRecall | Disable Windows Recall | Disable_AI_Recall.reg | >= 22621 |
| DisableClickToDo | Disable Click To Do, AI text & image analysis | Disable_Click_to_Do.reg | >= 22621 |
| DisableAISvcAutoStart | Prevent AI service from starting automatically | Disable_AI_Service_Auto_Start.reg | >= 22621 |
| DisableDVR | Disable Xbox game/screen recording | Disable_DVR.reg | No gate declared |
| DisableGameBarIntegration | Disable Game Bar integration | Disable_Game_Bar_Integration.reg | No gate declared |
| ClearStart | Remove all pinned apps from the start menu for this user only | Custom operation / parameter | >= 22621 |
| ClearStartAllUsers | Remove all pinned apps from the start menu for all existing and new users | Custom operation / parameter | >= 22621 |
| ReplaceStart | Replace the start menu layout for this user only with the provided template file | Custom operation / parameter | >= 22621 |
| ReplaceStartAllUsers | Replace the start menu layout for all existing and new users with the provided template file | Custom operation / parameter | >= 22621 |
| DisableStartRecommended | Hide recommended section in the start menu | Disable_Start_Recommended.reg | >= 22621 |
| DisableStartAllApps | Hide 'All Apps' section in the start menu | Disable_Start_All_Apps.reg | >= 26200 |
| DisableStartPhoneLink | Disable Phone Link integration in the start menu | Disable_Phone_Link_In_Start.reg | >= 22621 |
| DisableBing | Disable Bing web search & Copilot integration in search | Disable_Bing_Cortana_In_Search.reg | No gate declared |
| DisableStoreSearchSuggestions | Disable Microsoft Store app suggestions in search | Custom operation / parameter | >= 22621 |
| DisableSettings365Ads | Hide Microsoft 365 Copilot ads in Settings Home | Disable_Settings_365_Ads.reg | >= 22000 |
| DisableSettingsHome | Hide Settings 'Home' page | Disable_Settings_Home.reg | >= 22000 |
| DisableEdgeAI | Disable AI features in Microsoft Edge | Disable_Edge_AI_Features.reg | >= 22621 |
| DisablePaintAI | Disable AI features in Paint | Disable_Paint_AI_Features.reg | >= 22621 |
| DisableNotepadAI | Disable AI features in Notepad | Disable_Notepad_AI_Features.reg | >= 22621 |
| EnableDarkMode | Enable dark theme for system and apps | Enable_Dark_Mode.reg | No gate declared |
| DisableDragTray | Disable 'Drag Tray' for sharing & moving files | Disable_Share_Drag_Tray.reg | >= 26200 |
| RevertContextMenu | Use classic Windows 10 context menu style | Disable_Show_More_Options_Context_Menu.reg | >= 22000 |
| DisableMouseAcceleration | Disable Enhance Pointer Precision (mouse acceleration) | Disable_Enhance_Pointer_Precision.reg | No gate declared |
| DisableStickyKeys | Disable Sticky Keys keyboard shortcut (5x shift) | Disable_Sticky_Keys_Shortcut.reg | >= 26100 |
| DisableWindowSnapping | Disable window snapping | Disable_Window_Snapping.reg | No gate declared |
| DisableSnapAssist | Disable showing app suggestions when snapping windows | Disable_Snap_Assist.reg | >= 22000 |
| DisableSnapLayouts | Hide snap layout flyout at top of screen and on maximize button | Disable_Snap_Layouts.reg | >= 22000 |
| HideTabsInAltTab | Hide tabs from apps when snapping or pressing Alt+Tab | Hide_Tabs_In_Alt_Tab.reg | >= 22000 |
| Show3TabsInAltTab | Show 3 tabs from apps when snapping or pressing Alt+Tab | Show_3_Tabs_In_Alt_Tab.reg | >= 22000 |
| Show5TabsInAltTab | Show 5 tabs from apps when snapping or pressing Alt+Tab | Show_5_Tabs_In_Alt_Tab.reg | >= 22000 |
| Show20TabsInAltTab | Show 20 tabs from apps when snapping or pressing Alt+Tab | Show_20_Tabs_In_Alt_Tab.reg | >= 22000 |
| TaskbarAlignLeft | Align taskbar to the left | Align_Taskbar_Left.reg | >= 22000 |
| HideSearchTb | Hide search icon from the taskbar | Hide_Search_Taskbar.reg | >= 22000 |
| ShowSearchIconTb | Show search icon on the taskbar | Show_Search_Icon.reg | >= 22000 |
| ShowSearchLabelTb | Show search icon with label on the taskbar | Show_Search_Icon_And_Label.reg | >= 22000 |
| ShowSearchBoxTb | Show search box on the taskbar | Show_Search_Box.reg | >= 22000 |
| HideTaskview | Hide 'Task view' button on the taskbar | Hide_Taskview_Taskbar.reg | >= 22000 |
| DisableWidgets | Disable widgets on the taskbar & lock screen | Custom operation / parameter | No gate declared |
| HideChat | Hide Chat (meet now) icon on the taskbar | Disable_Chat_Taskbar.reg | ; <= 22621 |
| DisableStorageSense | Disable Storage Sense automatic disk cleanup | Disable_Storage_Sense.reg | >= 22000 |
| DisableFastStartup | Disable fast start-up | Disable_Fast_Startup.reg | No gate declared |
| DisableBitlockerAutoEncryption | Disable BitLocker automatic device encryption | Disable_Bitlocker_Auto_Encryption.reg | >= 22000 |
| DisableModernStandbyNetworking | Disable Modern Standby network connectivity | Disable_Modern_Standby_Networking.reg | >= 22000 |
| EnableEndTask | Show 'End Task' option in taskbar context menu | Enable_End_Task.reg | >= 22631 |
| EnableLastActiveClick | Enable 'Last Active Click' behavior for taskbar apps | Enable_Last_Active_Click.reg | >= 22000 |
| CombineTaskbarAlways | Always combine taskbar buttons and hide labels for the main display | Combine_Taskbar_Always.reg | >= 22000 |
| CombineMMTaskbarAlways | Always combine taskbar buttons and hide labels for secondary displays | Combine_MMTaskbar_Always.reg | >= 22000 |
| CombineTaskbarWhenFull | Combine taskbar buttons and hide labels when taskbar is full for the main display | Combine_Taskbar_When_Full.reg | >= 22000 |
| CombineMMTaskbarWhenFull | Combine taskbar buttons and hide labels when taskbar is full for secondary displays | Combine_MMTaskbar_When_Full.reg | >= 22000 |
| CombineTaskbarNever | Never combine taskbar buttons and show labels for the main display | Combine_Taskbar_Never.reg | >= 22000 |
| CombineMMTaskbarNever | Never combine taskbar buttons and show labels for secondary displays | Combine_MMTaskbar_Never.reg | >= 22000 |
| MMTaskbarModeAll | Show app icons on all taskbars | MMTaskbarMode_All.reg | >= 22000 |
| MMTaskbarModeMainActive | Show app icons on main taskbar and on taskbar where the windows is open | MMTaskbarMode_Main_Active.reg | >= 22000 |
| MMTaskbarModeActive | Show app icons only on taskbar where the window is open | MMTaskbarMode_Active.reg | >= 22000 |
| ExplorerToHome | Change the default location that File Explorer opens to 'Home' | Launch_File_Explorer_To_Home.reg | No gate declared |
| ExplorerToThisPC | Change the default location that File Explorer opens to 'This PC' | Launch_File_Explorer_To_This_PC.reg | No gate declared |
| ExplorerToDownloads | Change the default location that File Explorer opens to 'Downloads' | Launch_File_Explorer_To_Downloads.reg | No gate declared |
| ExplorerToOneDrive | Change the default location that File Explorer opens to 'OneDrive' | Launch_File_Explorer_To_OneDrive.reg | No gate declared |
| ShowKnownFileExt | Show file extensions for known file types | Show_Extensions_For_Known_File_Types.reg | No gate declared |
| ShowHiddenFolders | Show hidden files, folders and drives | Show_Hidden_Folders.reg | No gate declared |
| HideDupliDrive | Hide duplicate removable drive entries | Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg | No gate declared |
| HideHome | Hide 'Home' from navigation pane | Hide_Home_from_Explorer.reg | >= 22000 |
| HideGallery | Hide 'Gallery' from navigation pane | Hide_Gallery_from_Explorer.reg | >= 22000 |
| DisableTransparency | Disable transparency effects | Disable_Transparency.reg | No gate declared |
| DisableAnimations | Disable animations and visual effects | Disable_Animations.reg | No gate declared |
| DisableUpdateASAP | Prevent getting updates as soon as they're available | Disable_Update_ASAP.reg | No gate declared |
| PreventUpdateAutoReboot | Prevent automatic restarts after updates while signed in | Prevent_Auto_Reboot.reg | No gate declared |
| DisableDeliveryOptimization | Disable sharing downloaded updates with other PCs | Disable_Delivery_Optimization.reg | No gate declared |
| DisableDeviceAutoAppDownload | Prevent Windows from auto-installing device companion apps | Disable_Device_Auto_App_Download.reg | No gate declared |
| ForceRemoveEdge | Forcefully uninstall Microsoft Edge. NOT RECOMMENDED! | Custom operation / parameter | No gate declared |
| HideOnedrive | Hide 'OneDrive' from navigation pane | Hide_Onedrive_Folder.reg | No gate declared |
| Hide3dObjects | Hide '3D objects' folder under 'This PC' | Hide_3D_Objects_Folder.reg | ; <= 21999 |
| HideMusic | Hide 'Music' folder under 'This PC' | Hide_Music_Folder.reg | ; <= 21999 |
| AddFoldersToThisPC | Add common folders back to 'This PC' page | Add_All_Folders_Under_This_PC.reg | >= 22000 |
| HideIncludeInLibrary | Hide 'Include in library' option in the context menu | Disable_Include_in_library_from_context_menu.reg | ; <= 21999 |
| HideGiveAccessTo | Hide 'Give access to' option in the context menu | Disable_Give_access_to_context_menu.reg | ; <= 21999 |
| HideShare | Hide 'Share' option in the context menu | Disable_Share_from_context_menu.reg | ; <= 21999 |
| DisableBraveBloat | Disable bloat in Brave browser (AI, Crypto, etc.) | Disable_Brave_Bloat.reg | No gate declared |
| EnableWindowsSandbox | Enable Windows Sandbox | Custom operation / parameter | >= 22483 |
| EnableWindowsSubsystemForLinux | Enable Windows Subsystem for Linux | Custom operation / parameter | >= 22000 |
| ShowDriveLettersFirst | Show drive letters before drive label | Show_Drive_Letters_First.reg | No gate declared |
| ShowDriveLettersLast | Show drive letters after drive label | Show_Drive_Letters_Last.reg | No gate declared |
| ShowNetworkDriveLettersFirst | Show network drive letters before drive label | Show_Network_Drive_Letters_First.reg | No gate declared |
| HideDriveLetters | Hide all drive letters | Hide_Drive_Letters.reg | No gate declared |
| StartAllAppsCategory | Show All Apps in Category view (Default) | Start_AllApps_Category.reg | >= 26200 |
| StartAllAppsGrid | Show All Apps in Grid view | Start_AllApps_Grid.reg | >= 26200 |
| StartAllAppsList | Show All Apps in List view | Start_AllApps_List.reg | >= 26200 |

### Defaults and execution controls

**Selected default settings:** `CreateRestorePoint`, `DisableTelemetry`, `DisableSuggestions`, `DisableEdgeAds`, `DisableLockscreenTips`, `DisableBing`, `DisableStoreSearchSuggestions`, `DisableCopilot`, `DisableRecall`, `DisableClickToDo`, `DisableAISvcAutoStart`, `DisableWidgets`, `HideChat`, `ShowKnownFileExt`, `DisableDragTray`, `Hide3dObjects`, `DisableModernStandbyNetworking`.

Source also exposes `WhatIf`, CLI/GUI selection, config import/export and saved settings, log path, target user, AllUsers/CurrentUser app-removal scope, Sysprep/default-profile handling, skip-Explorer-restart and skip-registry-backup controls. Registry-backed settings are paired with state detection, prior-state snapshots and restore. [Entry point](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Win11Debloat.ps1); [feature executor/backup sources](https://github.com/Raphire/Win11Debloat/tree/32024662f3c602442e7af82bbf52c89143b31aeb/Scripts/Features).

### App-removal catalogue (141 entries)

[Pinned app definitions and presets](https://github.com/Raphire/Win11Debloat/blob/32024662f3c602442e7af82bbf52c89143b31aeb/Config/Apps.json)

Default selection and recommendation labels below are upstream metadata, not this report's approval to remove those apps.

| Application | Exact catalogue identity | Removal method | Upstream default selection |
| --- | --- | --- | --- |
| Clipchamp | Clipchamp.Clipchamp | Appx | Selected |
| 3D Builder | Microsoft.3DBuilder | Appx | Selected |
| Cortana | Microsoft.549981C3F5F10 | Appx | Selected |
| Bing Finance | Microsoft.BingFinance | Appx | Selected |
| Bing Food And Drink | Microsoft.BingFoodAndDrink | Appx | Selected |
| Bing Health And Fitness | Microsoft.BingHealthAndFitness | Appx | Selected |
| Bing News | Microsoft.BingNews | Appx | Selected |
| Bing Sports | Microsoft.BingSports | Appx | Selected |
| Bing Translator | Microsoft.BingTranslator | Appx | Selected |
| Bing Travel | Microsoft.BingTravel | Appx | Selected |
| Bing Weather | Microsoft.BingWeather | Appx | Selected |
| Microsoft Copilot | XP9CXNGPPJ97XX | WinGet | Selected |
| Copilot+ AI Hub | Microsoft.Windows.AIHub | Appx | Selected |
| Microsoft PC Manager | Microsoft.PCManager | Appx | Selected |
| Get Started | Microsoft.Getstarted | Appx | Selected |
| Messaging | Microsoft.Messaging | Appx | Selected |
| 3D Viewer | Microsoft.Microsoft3DViewer | Appx | Selected |
| Microsoft Journal | Microsoft.MicrosoftJournal | Appx | Selected |
| Office Hub | Microsoft.MicrosoftOfficeHub | Appx | Selected |
| Power BI | Microsoft.MicrosoftPowerBIForWindows | Appx | Selected |
| Solitaire Collection | Microsoft.MicrosoftSolitaireCollection | Appx | Selected |
| Sticky Notes | Microsoft.MicrosoftStickyNotes | Appx | Selected |
| Mixed Reality Portal | Microsoft.MixedReality.Portal | Appx | Selected |
| Network Speed Test | Microsoft.NetworkSpeedTest | Appx | Selected |
| Microsoft News | Microsoft.News | Appx | Selected |
| OneNote | Microsoft.Office.OneNote | Appx | Selected |
| Sway | Microsoft.Office.Sway | Appx | Selected |
| One Connect | Microsoft.OneConnect | Appx | Selected |
| Print 3D | Microsoft.Print3D | Appx | Selected |
| Power Automate | Microsoft.PowerAutomateDesktop | Appx | Selected |
| Skype (UWP) | Microsoft.SkypeApp | Appx | Selected |
| Microsoft To Do | Microsoft.Todos | Appx | Selected |
| Dev Home | Microsoft.Windows.DevHome | Appx | Selected |
| Alarms & Clock | Microsoft.WindowsAlarms | Appx | Selected |
| Feedback Hub | Microsoft.WindowsFeedbackHub | Appx | Selected |
| Windows Maps | Microsoft.WindowsMaps | Appx | Selected |
| Sound Recorder | Microsoft.WindowsSoundRecorder | Appx | Selected |
| Xbox Console Companion | Microsoft.XboxApp | Appx | Selected |
| Movies & TV | Microsoft.ZuneVideo | Appx | Selected |
| Family Safety | MicrosoftCorporationII.MicrosoftFamily | Appx | Selected |
| Quick Assist | MicrosoftCorporationII.QuickAssist | Appx | Selected |
| Microsoft Teams (Old) | MicrosoftTeams | Appx | Selected |
| Microsoft Teams (New) | MSTeams | Appx | Selected |
| ACG Media Player | ACGMediaPlayer | Appx | Selected |
| Actipro Software | ActiproSoftwareLLC | Appx | Selected |
| Adobe Photoshop Express | AdobeSystemsIncorporated.AdobePhotoshopExpress | Appx | Selected |
| Amazon | Amazon.com.Amazon | Appx | Selected |
| Prime Video | AmazonVideo.PrimeVideo | Appx | Selected |
| Asphalt 8 | Asphalt8Airborne | Appx | Selected |
| Autodesk SketchBook | AutodeskSketchBook | Appx | Selected |
| Caesars Slots | CaesarsSlotsFreeCasino | Appx | Selected |
| Cooking Fever | COOKINGFEVER | Appx | Selected |
| CyberLink Media Suite | CyberLinkMediaSuiteEssentials | Appx | Selected |
| Disney Magic Kingdoms | DisneyMagicKingdoms | Appx | Selected |
| Disney+ | Disney.37853FC22B2CE | Appx | Selected |
| Drawboard PDF | DrawboardPDF | Appx | Selected |
| Duolingo | Duolingo-LearnLanguagesforFree | Appx | Selected |
| Eclipse Manager | EclipseManager | Appx | Selected |
| Facebook | FACEBOOK.FACEBOOK | Appx | Selected |
| FarmVille 2 | FarmVille2CountryEscape | Appx | Selected |
| Flipboard | Flipboard | Appx | Selected |
| Hidden City | HiddenCity | Appx | Selected |
| Hulu | HULULLC.HULUPLUS | Appx | Selected |
| iHeartRadio | iHeartRadio | Appx | Selected |
| Instagram | Facebook.Instagram | Appx | Selected |
| Bubble Witch 3 | king.com.BubbleWitch3Saga | Appx | Selected |
| Candy Crush Saga | king.com.CandyCrushSaga | Appx | Selected |
| Candy Crush Soda | king.com.CandyCrushSodaSaga | Appx | Selected |
| LinkedIn | LinkedInforWindows | Appx | Selected |
| March of Empires | MarchofEmpires | Appx | Selected |
| Netflix | 4DF9E0F8.Netflix | Appx | Selected |
| NYT Crossword | NYTCrossword | Appx | Selected |
| One Calendar | OneCalendar | Appx | Selected |
| Pandora | PandoraMediaInc | Appx | Selected |
| Phototastic Collage | PhototasticCollage | Appx | Selected |
| PicsArt | PicsArt-PhotoStudio | Appx | Selected |
| Polarr Photo Editor | PolarrPhotoEditorAcademicEdition | Appx | Selected |
| Royal Revolt | flaregamesGmbH.RoyalRevolt | Appx | Selected |
| Live Wallpaper | Sidia.LiveWallpaper | Appx | Selected |
| Sling TV | SlingTV | Appx | Selected |
| Spotify | SpotifyAB.SpotifyMusic | Appx | Selected |
| TikTok | BytedancePte.Ltd.TikTok | Appx | Selected |
| TuneIn Radio | TuneInRadio | Appx | Selected |
| WinZip | WinZipUniversal | Appx | Selected |
| Bing Search | Microsoft.BingSearch | Appx | Unselected |
| Microsoft Edge | ['Microsoft.Edge', 'XPFFTQ037JWMHS'] | WinGet | Unselected |
| Xbox Gaming App | Microsoft.GamingApp | Appx | Unselected |
| Get Help | Microsoft.GetHelp | Appx | Unselected |
| Microsoft 365 Companions | Microsoft.M365Companions | Appx | Unselected |
| Paint 3D | Microsoft.MSPaint | Appx | Unselected |
| OneDrive | Microsoft.OneDrive | WinGet | Unselected |
| Outlook for Windows | Microsoft.OutlookForWindows | Appx | Unselected |
| Paint | Microsoft.Paint | Appx | Unselected |
| People | Microsoft.People | Appx | Unselected |
| Remote Desktop | Microsoft.RemoteDesktop | Appx | Unselected |
| Snipping Tool | Microsoft.ScreenSketch | Appx | Unselected |
| Widgets Experience | Microsoft.StartExperiencesApp | Appx | Unselected |
| Whiteboard | Microsoft.Whiteboard | Appx | Unselected |
| Photos | Microsoft.Windows.Photos | Appx | Unselected |
| Calculator | Microsoft.WindowsCalculator | Appx | Unselected |
| Camera | Microsoft.WindowsCamera | Appx | Unselected |
| Mail & Calendar | Microsoft.windowscommunicationsapps | Appx | Unselected |
| Notepad | Microsoft.WindowsNotepad | Appx | Unselected |
| Microsoft Store | Microsoft.WindowsStore | Appx | Unselected |
| Windows Terminal | Microsoft.WindowsTerminal | Appx | Unselected |
| Xbox TCUI Framework | Microsoft.Xbox.TCUI | Appx | Unselected |
| Xbox Game Overlay | Microsoft.XboxGameOverlay | Appx | Unselected |
| Xbox Gaming Overlay | Microsoft.XboxGamingOverlay | Appx | Unselected |
| Xbox Identity Provider | Microsoft.XboxIdentityProvider | Appx | Unselected |
| Xbox Speech To Text | Microsoft.XboxSpeechToTextOverlay | Appx | Unselected |
| Phone Link | Microsoft.YourPhone | Appx | Unselected |
| Media Player | Microsoft.ZuneMusic | Appx | Unselected |
| Cross Device Experience | MicrosoftWindows.CrossDevice | Appx | Unselected |
| Windows Web Experience Pack | MicrosoftWindows.Client.WebExperience | Appx | Unselected |
| Widgets Platform Runtime | Microsoft.WidgetsPlatformRuntime | Appx | Unselected |
| LG Monitor App | LGElectronics.LGMonitorApp | Appx | Unselected |
| HP AI Experience Center | AD2F1837.HPAIExperienceCenter | Appx | Unselected |
| HP Connected Music | AD2F1837.HPConnectedMusic | Appx | Unselected |
| HP Connected Photo | AD2F1837.HPConnectedPhotopoweredbySnapfish | Appx | Unselected |
| HP Desktop Support Utilities | AD2F1837.HPDesktopSupportUtilities | Appx | Unselected |
| HP Easy Clean | AD2F1837.HPEasyClean | Appx | Unselected |
| HP File Viewer | AD2F1837.HPFileViewer | Appx | Unselected |
| HP JumpStarts | AD2F1837.HPJumpStarts | Appx | Unselected |
| HP PC Hardware Diagnostics | AD2F1837.HPPCHardwareDiagnosticsWindows | Appx | Unselected |
| HP Power Manager | AD2F1837.HPPowerManager | Appx | Unselected |
| HP Printer Control | AD2F1837.HPPrinterControl | Appx | Unselected |
| HP Privacy Settings | AD2F1837.HPPrivacySettings | Appx | Unselected |
| HP QuickDrop | AD2F1837.HPQuickDrop | Appx | Unselected |
| HP QuickTouch | AD2F1837.HPQuickTouch | Appx | Unselected |
| HP Registration | AD2F1837.HPRegistration | Appx | Unselected |
| HP Support Assistant | AD2F1837.HPSupportAssistant | Appx | Unselected |
| HP Sure Shield AI | AD2F1837.HPSureShieldAI | Appx | Unselected |
| HP System Information | AD2F1837.HPSystemInformation | Appx | Unselected |
| HP Welcome | AD2F1837.HPWelcome | Appx | Unselected |
| HP WorkWell | AD2F1837.HPWorkWell | Appx | Unselected |
| myHP | AD2F1837.myHP | Appx | Unselected |
| Lenovo Vantage | E046963F.LenovoCompanion | Appx | Unselected |
| Lenovo Vantage Service | LenovoCompanyLimited.LenovoVantageService | Appx | Unselected |
| Dell SupportAssist | DellInc.DellSupportAssistforPCs | Appx | Unselected |
| Dell Digital Delivery Services | DellInc.DellDigitalDelivery | Appx | Unselected |
| Dell Mobile Connect | DellInc.DellMobileConnect | Appx | Unselected |


</details>

<details>
<summary>F. Sophia Script: every public function in the Windows 11 PowerShell 7 module</summary>

### All 120 public module functions

[Pinned module](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Module/Sophia.psm1); [editable preset](https://github.com/farag2/Sophia-Script-for-Windows/blob/4a89b522eab3ad0b106003fe5b791530c8d1f3a1/src/Sophia_Script_for_Windows_11_PowerShell_7/Sophia.ps1).

Exact names are listed by the module's own top-level regions. Most preferences expose explicit opposite settings; other functions install/remove, export/import or run a maintenance action. The preset decides what runs. This inventory does not imply all 120 run by default or that enabling one side is recommended.

#### Protection

- `Logging`
- `CreateRestorePoint`

#### Privacy & Telemetry

- `DiagTrackService`
- `DiagnosticDataLevel`
- `ErrorReporting`
- `FeedbackFrequency`
- `ScheduledTasks`
- `SigninInfo`
- `LanguageListAccess`
- `AdvertisingID`
- `WindowsWelcomeExperience`
- `WindowsTips`
- `SettingsSuggestedContent`
- `AppsSilentInstalling`
- `WhatsNewInWindows`
- `TailoredExperiences`
- `BingSearch`

#### UI & Personalization

- `ThisPC`
- `CheckBoxes`
- `HiddenItems`
- `FileExtensions`
- `MergeConflicts`
- `OpenFileExplorerTo`
- `FileExplorerCompactMode`
- `OneDriveFileExplorerAd`
- `SnapAssist`
- `FileTransferDialog`
- `RecycleBinDeleteConfirmation`
- `QuickAccessRecentFiles`
- `QuickAccessFrequentFolders`
- `TaskbarAlignment`
- `TaskbarWidgets`
- `TaskbarSearch`
- `SearchHighlights`
- `TaskViewButton`
- `SecondsInSystemClock`
- `ClockInNotificationCenter`
- `TaskbarCombine`
- `UnpinTaskbarShortcuts`
- `TaskbarEndTask`
- `ControlPanelView`
- `WindowsColorMode`
- `AppColorMode`
- `FirstLogonAnimation`
- `JPEGWallpapersQuality`
- `ShortcutsSuffix`
- `PrtScnSnippingTool`
- `AppsLanguageSwitch`
- `AeroShaking`
- `Install-Cursors`
- `FolderGroupBy`
- `NavigationPaneExpand`
- `RecentlyAddedStartApps`
- `UnpinAllStartTiles`
- `StartAppsView`
- `MostUsedStartApps`
- `StartRecommendedSection`
- `StartRecommendationsTips`
- `StartAccountNotifications`

#### OneDrive

- `OneDrive`

#### System

- `StorageSense`
- `Hibernation`
- `Win32LongPathsSupport`
- `BSoDStopError`
- `AdminApprovalMode`
- `DeliveryOptimization`
- `WindowsManageDefaultPrinter`
- `WindowsFeatures`
- `WindowsCapabilities`
- `UpdateMicrosoftProducts`
- `RestartNotification`
- `RestartDeviceAfterUpdate`
- `ActiveHours`
- `WindowsLatestUpdate`
- `PowerPlan`
- `NetworkAdaptersSavePower`
- `InputMethod`
- `Set-UserShellFolderLocation`
- `WinPrtScrFolder`
- `RecommendedTroubleshooting`
- `ReservedStorage`
- `F1HelpPage`
- `NumLock`
- `CapsLock`
- `StickyShift`
- `Autoplay`
- `ThumbnailCacheRemoval`
- `SaveRestartableApps`
- `RestorePreviousFolders`
- `Set-Association`
- `Export-Associations`
- `Import-Associations`
- `DefaultTerminalApp`
- `Install-VCRedist`
- `Install-DotNetRuntimes`
- `PreventEdgeShortcutCreation`
- `RegistryBackup`
- `WindowsAI`

#### WSL

- `Install-WSL`

#### UWP apps

- `Uninstall-UWPApps`

#### Gaming

- `XboxGameBar`
- `XboxGameTips`
- `GPUScheduling`

#### Scheduled tasks

- `CleanupTask`
- `SoftwareDistributionTask`
- `TempTask`

#### Microsoft Defender & Security

- `NetworkProtection`
- `PUAppsDetection`
- `DefenderSandbox`
- `EventViewerCustomView`
- `AppsSmartScreen`
- `SaveZoneInformation`
- `WindowsSandbox`
- `DNSoverHTTPS`
- `LocalSecurityAuthority`

#### Context menu

- `MSIExtractContext`
- `CABInstallContext`
- `UseStoreOpenWith`
- `OpenWindowsTerminalAdminContext`
- `ScanRegistryPolicies`


</details>
