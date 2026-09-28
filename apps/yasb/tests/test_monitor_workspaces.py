from types import SimpleNamespace

from core.widgets.canopy.backend import Backend
from core.widgets.canopy.model import State


def monitor(identifier, name):
    return {'id': identifier, 'name': name}


def backend_for(monitors):
    return SimpleNamespace(state=State(wm={'monitors': {'elements': monitors}}))


def test_unknown_monitor_never_routes_clicks_to_primary_monitor():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1')])
    items, _, _, index = Backend.workspaces(backend, 999)
    assert items == []
    assert index is None
    calls = []
    backend._komorebi = SimpleNamespace(activate_workspace=lambda *args: calls.append(args))
    Backend.focus_workspace(backend, index, 7)
    assert not calls


def test_click_resolves_monitor_identity_again_after_hotplug_reordering():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1'), monitor(22, r'\\.\DISPLAY2')])
    identity = {'id': 22, 'name': r'\\.\DISPLAY2'}
    assert Backend.workspaces(backend, identity)[3] == 1
    backend.state.wm['monitors']['elements'].reverse()
    calls = []
    backend._komorebi = SimpleNamespace(activate_workspace=lambda *args: calls.append(args))
    Backend.focus_workspace(backend, identity, 7)
    assert calls == [(0, 7)]


def test_ambiguous_display_name_does_not_select_an_arbitrary_monitor():
    backend = backend_for([monitor(11, 'DISPLAY'), monitor(22, 'DISPLAY')])
    assert Backend.workspaces(backend, {'id': 0, 'name': 'DISPLAY'}) == ([], '', '', None)
