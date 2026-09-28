from copy import deepcopy
from types import SimpleNamespace

from core.widgets.canopy.backend import Backend
from core.widgets.canopy.model import State
from core.widgets.services.komorebi.client import KomorebiClient


def test_secondary_canvas_shows_numbers_and_routes_click_after_monitor_reorder(app):
    from PyQt6.QtCore import QObject, Qt
    from PyQt6.QtTest import QTest
    from PyQt6.QtWidgets import QWidget, QVBoxLayout
    from core.widgets.canopy.widget import Canvas

    backend = Backend.__new__(Backend)
    QObject.__init__(backend)
    backend.state = backend_for([monitor(11, 'DISPLAY1', 8), monitor(22, 'DISPLAY2')]).state
    calls = []
    backend._komorebi = SimpleNamespace(activate_workspace=lambda *args: calls.append(args))
    root = QWidget()
    root.resize(640, 360)
    canvas = Canvas(backend, root)
    canvas.monitor_handle = lambda: {'id': 22, 'name': r'\\.\DISPLAY2'}
    layout = QVBoxLayout(root)
    layout.addWidget(canvas)
    layout.addStretch()
    root.show()
    canvas.sync('all')
    app.processEvents()
    assert [button.text() for button in canvas.workspaces.buttons] == list('12345678')
    assert all(button.isVisible() and button.width() > 0 for button in canvas.workspaces.buttons)
    backend.state.wm['monitors']['elements'].reverse()
    QTest.mouseClick(canvas.workspaces.buttons[7], Qt.MouseButton.LeftButton)
    assert calls == [(0, 7)], 'A click must resolve the monitor again instead of using its old ring index'
    root.deleteLater()
    backend.deleteLater()
    app.processEvents()


def workspace(name=None, *, title=''):
    windows = [{'title': title}] if title else []
    containers = [{'windows': {'elements': windows, 'focused': 0}}] if windows else []
    return {'name': name, 'layout': {'Default': 'BSP'}, 'containers': {'elements': containers, 'focused': 0},
            'floating_windows': [], 'monocle_container': None, 'maximized_window': None}


def monitor(identifier, name, count=1, focused=0):
    return {'id': identifier, 'name': name, 'device': name, 'device_id': name + '-persistent',
            'workspaces': {'elements': [workspace() for _ in range(count)], 'focused': focused}}


def backend_for(monitors, index_map=None):
    return SimpleNamespace(state=State(wm={'monitors': {'elements': monitors, 'focused': 0},
                                           'monitor_usr_idx_map': index_map or {}}),
                           _komorebi=KomorebiClient())


def test_second_monitor_shows_eight_workspaces_before_visiting_the_eighth():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1', 8), monitor(22, r'\\.\DISPLAY2')])
    items, layout, title, index = Backend.workspaces(backend, 22)
    assert [item['name'] for item in items] == [str(i) for i in range(1, 9)]
    assert [item['active'] for item in items] == [True] + [False] * 7
    assert not any(item['occupied'] for item in items)
    assert (layout, title, index) == ('BSP', '', 1)


def test_monitor_name_fallback_handles_recreated_native_monitor_handles():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1'), monitor(22, r'\\.\DISPLAY2', focused=0)])
    items, _, _, index = Backend.workspaces(backend, {'id': 999, 'name': r'\\.\DISPLAY2'})
    assert len(items) == 8
    assert index == 1


def test_handle_identity_wins_over_display_name_and_preference_index():
    backend = backend_for([monitor(22, r'\\.\DISPLAY2', 8), monitor(11, r'\\.\DISPLAY1', 8)], {'0': 1, '1': 0})
    items, _, _, index = Backend.workspaces(backend, {'id': 22, 'name': r'\\.\DISPLAY1'})
    assert len(items) == 8
    assert index == 0, 'focus-monitor-workspace accepts the internal ring index, not the config index'


def test_reading_workspaces_does_not_mutate_shared_komorebi_state():
    backend = backend_for([monitor(22, r'\\.\DISPLAY2', 8)])
    before = deepcopy(backend.state.wm)
    Backend.workspaces(backend, 22)
    assert backend.state.wm == before


def test_actual_names_occupancy_and_focused_window_are_preserved():
    screen = monitor(22, r'\\.\DISPLAY2', 2, focused=1)
    screen['workspaces']['elements'] = [workspace('Inbox'), workspace('Code', title='Editor')]
    backend = backend_for([screen])
    items, layout, title, index = Backend.workspaces(backend, 22)
    assert [item['name'] for item in items[:3]] == ['Inbox', 'Code', '3']
    assert items[1] == {'name': 'Code', 'occupied': True, 'active': True}
    assert (layout, title, index) == ('BSP', 'Editor', 0)


def test_unknown_monitor_never_routes_clicks_to_primary_monitor():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1')])
    items, _, _, index = Backend.workspaces(backend, 999)
    assert items == []
    assert index is None
    calls = []
    backend._komorebi = SimpleNamespace(activate_workspace=lambda *args: calls.append(args))
    Backend.focus_workspace(backend, index, 7)
    assert not calls


def test_virtual_workspace_click_uses_the_matching_physical_monitor_index():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1'), monitor(22, r'\\.\DISPLAY2')])
    _, _, _, index = Backend.workspaces(backend, 22)
    calls = []
    backend._komorebi = SimpleNamespace(activate_workspace=lambda *args: calls.append(args))
    Backend.focus_workspace(backend, index, 7)
    assert calls == [(1, 7)]


def test_click_resolves_monitor_identity_again_after_hotplug_reordering():
    backend = backend_for([monitor(11, r'\\.\DISPLAY1'), monitor(22, r'\\.\DISPLAY2')])
    identity = {'id': 22, 'name': r'\\.\DISPLAY2'}
    assert Backend.workspaces(backend, identity)[3] == 1
    backend.state.wm['monitors']['elements'].reverse()
    calls = []
    backend._komorebi = SimpleNamespace(activate_workspace=lambda *args: calls.append(args))
    Backend.focus_workspace(backend, identity, 7)
    assert calls == [(0, 7)]


def test_sparse_workspace_data_and_extra_workspaces_remain_visible():
    screen = monitor('22', r'\\.\DISPLAY2')
    screen['workspaces'] = {'elements': [{}, {'name': None}], 'focused': 9}
    screen['workspace_names'] = {'4': 'Chat'}
    items, _, _, index = Backend.workspaces(backend_for([screen]), 22)
    assert len(items) == 10
    assert items[4]['name'] == 'Chat'
    assert items[9]['active']
    assert index == 0


def test_ambiguous_display_name_does_not_select_an_arbitrary_monitor():
    backend = backend_for([monitor(11, 'DISPLAY'), monitor(22, 'DISPLAY')])
    assert Backend.workspaces(backend, {'id': 0, 'name': 'DISPLAY'}) == ([], '', '', None)
