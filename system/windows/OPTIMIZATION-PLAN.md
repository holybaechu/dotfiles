# Selected Windows preferences

Decisions recorded 2026-10-01. Research: [source inventory and suggestions](OPTIMIZATION-SUGGESTIONS.md).

Implementation starts from main at `5d63e7a`, which already includes privacy, graphics, optional-component removal and narrow minimize/restore animation preferences. “No” and “keep defaults” mean no additional management of the declined setting in this change; existing independently configured settings remain owned by their existing modules. New preference groups do not create rollback journals, restore points or troubleshooting tools.

The location conflict was resolved explicitly: **disable both location services and Find My Device**.

## Implementation

1. Extend app removal using exact package identities for the selected remaining apps; retain existing Widgets, Office Hub and standalone Microsoft Copilot removal.
2. Add current-user desktop preferences: This PC, hidden Home/Gallery, dark mode, windows-only Alt+Tab, disabled snapping suggestions/native arranging, hidden taskbar entry points and the Sticky Keys shortcut.
3. Add the selected privacy/preferences with the existing user/elevated DSC split: web/cloud search controls, promotions, activity uploads, speech/typing collection, DiagTrack, location/Find My Device, device companion apps, tool telemetry, AI-app policies and long paths. Existing privacy settings remain authoritative for overlapping values.
4. Enable Defender PUA and network protection on supported active Defender installations; report unmet prerequisites and rejected changes without disabling existing protections.
5. Wire bootstrap, document applicability and sign-out/restart behavior, validate syntax and isolated behavior, then open a focused PR. Applying the PR to the live Windows installation is a separate operation.

## Decision record

| Question | Choice | Implementation scope |
| --- | --- | --- |
| 1 | This PC | Explorer default location |
| 2–3 | Yes | Hide Home and Gallery |
| 4–6 | No | No compact-view/recent-file/frequent-folder changes |
| 7 | Keep | No folder-type discovery or view reset |
| 8–9 | No | No additional animation or transparency changes |
| 10–11 | No | No classic context menu or taskbar End Task |
| 12 | Yes | Alt+Tab windows only |
| 13 | No | No scrollbar changes |
| 14–15 | Yes | Dark mode; disable Sticky Keys shortcut only |
| 16–18 | Yes | Disable Snap Assist, Snap Layout flyouts and native arranging |
| 19–20 | Yes; uninstall | Existing Widgets/Web Experience package removal and taskbar preference |
| 21 | All three | Hide Search, Task View and Chat |
| 22 | All listed | Dev Home, Office Hub, Solitaire, Get Started, Mail/Calendar, Maps, Skype and 3D Viewer |
| 23 | Yes | Existing new Outlook deprovisioning; use supported Windows 11 behavior, not Windows 10-only updater blocks |
| 24–27 | Yes | Promotions, suggested installs, sync-provider and account prompts |
| 28–29 | Yes | Local-only search, cloud suggestions and highlights disabled |
| 30 | Yes | Stop activity publication/upload; preserve clipboard history |
| 31–32 | Yes | Existing advertising ID and tailored-experience opt-outs |
| 33 | Yes | Minimum supported diagnostic level, edition-aware |
| 34 | Yes | Disable DiagTrack |
| 35–36 | Disable both | Location services and Find My Device disabled after clarification |
| 37–38 | Yes | Online speech and typing/inking collection disabled; retain keyboard/IME support |
| 39–41 | Yes | PowerShell, .NET CLI and WinGet telemetry opt-outs |
| 42–43 | Yes | Existing standalone Microsoft Copilot removal and supported Recall controls |
| 44–45 | Yes | Notepad and supported Paint AI policies |
| 46 | Yes | Prevent automatic device companion-app downloads; retain drivers |
| 47–54 | Keep defaults | No additional update-sharing, active-hours, notifications/restart, preview/driver, DNS or filtering changes |
| 55 | Keep defaults | No Fast Startup/hibernation changes |
| 56 | No | No Windows Sandbox installation |
| 57 | Yes | Win32 long paths |
| 58–61 | No | No new restore points, backups, environment reports or repair commands |
| 62–63 | Yes | Defender PUA and supported network protection |
| 64–65 | Keep defaults | No SmartScreen/LSA changes |

## Validation and limits

Use syntax/configuration parsing, chezmoi template rendering and mocked state-change checks. Existing app-removal and privacy/graphics checks remain relevant. Do not apply settings or remove apps on the research host as a test. Unsupported build/edition policies must be reported, not counted as effective merely because a registry value exists. GUI behavior, IME, WSL connectivity and Defender enforcement need verification after the user applies the PR.

Implementation and isolated validation are complete:

- PowerShell syntax and native interop compilation passed without invoking the real preference APIs.
- The retained debloat, privacy/graphics and optional-component fixtures passed; diagnostic-data checks cover Pro and Enterprise.
- New fixtures passed for user/elevated scope, reruns, denied/ignored settings, DiagTrack, unsupported AI policy builds, Defender prerequisites and rejected protection changes.
- Native chezmoi rendering preserved unrelated JSONC WinGet settings, produced an identical result on reapply, and created the settings successfully in a fresh isolated destination.
- WinGet accepted all 14 preference resources, including the intended elevation boundaries. Standalone DSC accepted a scratch copy normalized to its v3 schema identifier; the actual file retains WinGet's accepted 2023 schema identifier.

Paint's documented policies cover Cocreator, generative fill and Image Creator. Generative erase/background-removal policy support could not be verified from Microsoft's policy definitions and is explicitly reported as a limitation. Existing supported Recall removal/policy and new Outlook deprovisioning are reused. No live registry, service, Defender, app-removal or appearance changes were performed for these tests.
