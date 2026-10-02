# Canopy runtime

Canopy extends a pinned YASB checkout with the bar and launcher in [canopy/](canopy/).
Desktop usage is in [Daily use](../../docs/desktop.md); deployed bar configuration and CSS are
in [home/](../../home/dot_config/yasb/).

## Install and start

After `chezmoi apply` and `mise install bun node uv`, run these from the repository root in
PowerShell 7:

```powershell
.\apps\yasb\Setup.ps1
.\apps\yasb\Start.ps1
```

Setup uses `mise exec -- uv`, so shell activation is not required. uv owns Canopy's pinned
Python version and `.venv`; mise owns uv. [upstream.json](upstream.json) pins YASB's source,
while [uv.lock](uv.lock) pins its Python dependencies. Keep custom code out of `.upstream/`.

## Update or recover the runtime

Setup retains a matching checkout and updates a clean checkout to the pinned commit when the
pin changes. A dirty checkout is rejected; preserve its edits before retrying. If cloning was
interrupted, inspect `.upstream/`, move the incomplete directory aside, and rerun setup. Do not
remove `.venv` or download a new YASB release just to retry a failed dependency installation.
Stop the running bar before updating dependencies if Windows reports files in use.

For an upstream update, change the tag and commit in `upstream.json`, run setup, then regenerate
the lockfile with `mise exec -- uv lock --project apps/yasb` if dependencies changed. Review the
lockfile and rerun setup and the checks below. [launch.py](launch.py) installs the host fixes,
Qt command routing, and theme before starting YASB. Native monitor positioning and shutdown
need verification when updating upstream.

## Verify changes

```powershell
.\apps\yasb\Setup.ps1 -Dev
.\apps\yasb\.venv\Scripts\python.exe -m pytest apps/yasb/tests
pwsh.exe -NoProfile -File .\apps\yasb\tests\Setup.Tests.ps1
.\apps\yasb\Start.ps1 -Preview
```

Tests protect launcher reliability and shutdown, monitor targeting, denied setting changes,
and hotkey timeouts. Preview uses simulated state; live monitor changes and Windows appearance
still require manual checks. YASB supplies native desktop integration, while Canopy keeps its
behavior and styling local; replacing that dependency would make this repository own those
Windows integrations as well.
