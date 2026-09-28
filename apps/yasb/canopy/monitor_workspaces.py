"""Project Komorebi's physical monitor state into stable, selectable workspace slots."""
from __future__ import annotations

# Matches the managed Komorebi configuration and whkd's workspace 1–8 shortcuts.
# Komorebi materializes a missing workspace when focus_workspace is requested.
WORKSPACE_SLOTS = 8


def elements(ring):
    value = ring.get('elements', []) if isinstance(ring, dict) else ring
    return value if isinstance(value, (list, tuple)) else []


def focused(ring):
    if not isinstance(ring, dict):
        return None
    values = elements(ring)
    index = ring.get('focused', 0)
    return values[index] if isinstance(index, int) and 0 <= index < len(values) else None


def _handle(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _display_name(value):
    return str(value or '').strip().casefold().removeprefix('\\\\.\\')


def resolve_monitor(state, identity):
    """Return (internal ring index, monitor), never a configured display index.

    An HMONITOR is preferred; the Windows display name survives handle replacement.
    Ambiguous/unmatched identities must not silently select the primary display.
    """
    monitors = elements(state.get('monitors', {}))
    handle = _handle(identity.get('id')) if isinstance(identity, dict) else _handle(identity)
    if handle:
        for index, monitor in enumerate(monitors):
            if isinstance(monitor, dict) and _handle(monitor.get('id')) == handle:
                return index, monitor
    name = _display_name(identity.get('name')) if isinstance(identity, dict) else ''
    if name:
        matches = [(index, monitor) for index, monitor in enumerate(monitors)
                   if isinstance(monitor, dict) and name in
                   {_display_name(monitor.get('name')), _display_name(monitor.get('device'))}]
        if len(matches) == 1:
            return matches[0]
    return None, None


def _occupied(workspace):
    if not isinstance(workspace, dict):
        return False
    if workspace.get('maximized_window') or elements(workspace.get('floating_windows')):
        return True
    containers = list(elements(workspace.get('containers')))
    if workspace.get('monocle_container'):
        containers.append(workspace['monocle_container'])
    return any(isinstance(container, dict) and elements(container.get('windows')) for container in containers)


def workspace_view(state, identity):
    index, monitor = resolve_monitor(state, identity)
    if monitor is None:
        return [], '', '', None
    ring = monitor.get('workspaces', {})
    actual = elements(ring)
    selected = ring.get('focused', 0) if isinstance(ring, dict) else 0
    if not isinstance(selected, int) or selected < 0:
        selected = 0
    count = max(WORKSPACE_SLOTS, len(actual), selected + 1)
    names = monitor.get('workspace_names') or {}
    items = []
    for slot in range(count):
        workspace = actual[slot] if slot < len(actual) and isinstance(actual[slot], dict) else {}
        name = workspace.get('name') or names.get(str(slot)) or names.get(slot) or str(slot + 1)
        items.append({'name': str(name), 'active': slot == selected, 'occupied': bool(_occupied(workspace))})
    workspace = focused(ring) or {}
    layout = workspace.get('layout', '')
    if isinstance(layout, dict):
        layout = layout.get('Default', layout.get('Custom', ''))
    container = workspace.get('monocle_container') or focused(workspace.get('containers')) or {}
    window = workspace.get('maximized_window') or focused(container.get('windows')) or {}
    return items, str(layout).upper(), window.get('title', ''), index
