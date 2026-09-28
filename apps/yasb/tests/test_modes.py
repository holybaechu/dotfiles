import asyncio
from threading import Event
from types import SimpleNamespace

import pytest
from PyQt6.QtCore import QThread, Qt
from PyQt6.QtTest import QTest

from core.widgets.canopy import system_modes
from core.widgets.canopy.model import PreviewBackend
from core.widgets.canopy.panels import Quick


def wait_until(predicate, timeout=2000):
    for _ in range(timeout // 10):
        if predicate():
            return
        QTest.qWait(10)
    assert predicate()


@pytest.mark.parametrize('flag,expected', [(0, False), (1, True), (255, None)])
def test_saver_status_uses_actual_system_flag(monkeypatch, flag, expected):
    monkeypatch.setattr(system_modes, '_read_power_status',
                        lambda: SimpleNamespace(SystemStatusFlag=flag, BatteryLifePercent=5, ACLineStatus=0))
    assert system_modes.battery_saver_enabled() is expected


def test_saver_status_failure_is_unknown(monkeypatch):
    def fail():
        raise OSError('Unavailable')
    monkeypatch.setattr(system_modes, '_read_power_status', fail)
    assert system_modes.battery_saver_enabled() is None


@pytest.mark.parametrize('airplane_on,radio_enabled', [(True, 0), (False, 1)])
def test_airplane_writes_inverse_radio_enablement_without_touching_windows(monkeypatch, airplane_on, radio_enabled):
    writes = []
    fake = SimpleNamespace(IsRMSupported=lambda: 1, GetSystemRadioState=lambda: (radio_enabled, 1, 0),
                           SetSystemRadioState=writes.append)
    monkeypatch.setattr(system_modes, '_radio_manager', lambda: fake)
    driver = system_modes.WindowsModes()
    assert driver.read('airplane_mode') is airplane_on
    driver.write('airplane_mode', airplane_on)
    assert writes == [radio_enabled]


def test_unsupported_airplane_read_is_unknown(monkeypatch):
    monkeypatch.setattr(system_modes, '_radio_manager', lambda: SimpleNamespace(IsRMSupported=lambda: 0))
    assert system_modes.WindowsModes().read('airplane_mode') is None


def test_preview_switches_change_fixture_only(app, monkeypatch):
    backend = PreviewBackend()
    opened = []
    monkeypatch.setattr(backend, 'open_settings', opened.append)
    panel = Quick(backend)
    try:
        assert panel.airplane.isCheckable() and panel.battery_saver.isCheckable()
        panel.airplane.click()
        panel.battery_saver.click()
        assert backend.state.airplane_mode and backend.state.battery_saver
        assert panel.airplane.isChecked() and panel.battery_saver.isChecked()
        assert panel.airplane.subtitle == 'On'
        assert not opened
    finally:
        panel.deleteLater()
        backend.deleteLater()


def test_switch_waits_for_confirmed_state_and_disables_when_pending(app, monkeypatch):
    backend = PreviewBackend()
    requests = []
    monkeypatch.setattr(backend, 'set_airplane_mode', requests.append)
    panel = Quick(backend)
    try:
        panel.airplane.click()
        assert requests == [True]
        assert not panel.airplane.isChecked()
        backend.state.pending_modes.add('airplane_mode')
        backend.changed.emit('status')
        assert not panel.airplane.toggle_enabled
        assert panel.airplane.subtitle == 'Updating…'
        backend.state.pending_modes.clear()
        backend.state.airplane_mode = None
        backend.state.mode_errors['airplane_mode'] = 'Radio management is unavailable.'
        backend.changed.emit('status')
        assert panel.airplane.subtitle == 'Unavailable'
        assert not panel.airplane.toggle_enabled
        assert panel.airplane.toolTip() == 'Radio management is unavailable.'
    finally:
        panel.deleteLater()
        backend.deleteLater()


class FakeModes:
    def __init__(self):
        self.values = {mode: False for mode in system_modes.MODE_NAMES}
        self.writes = []

    def read(self, mode):
        return self.values[mode]

    def write(self, mode, value):
        self.writes.append((mode, value))
        self.values[mode] = value


def test_native_writes_run_off_ui_thread_and_confirm_readback(app):
    started, release = Event(), Event()

    class DelayedModes(FakeModes):
        def write(self, mode, value):
            started.set()
            assert release.wait(2)
            super().write(mode, value)

    driver = DelayedModes()
    service = system_modes.SystemModes(driver=driver)
    snapshots, pending = [], []
    service.changed.connect(snapshots.append)
    service.pending_changed.connect(lambda mode, value: pending.append((mode, value)))
    try:
        wait_until(lambda: snapshots)
        assert service.set_mode('airplane_mode', True)
        assert not service.set_mode('airplane_mode', False)
        wait_until(started.is_set)
        assert pending == [('airplane_mode', True)]
        assert snapshots[-1]['airplane_mode'] is False
        release.set()
        wait_until(lambda: len(pending) == 2)
        assert snapshots[-1]['airplane_mode'] is True
        assert pending[-1] == ('airplane_mode', False)
    finally:
        release.set()
        service.shutdown()
    assert not service._worker.isRunning()


def test_native_write_failure_preserves_real_state_and_reports_error(app):
    class DeniedModes(FakeModes):
        def write(self, mode, value):
            raise OSError('Access denied by Windows')

    service = system_modes.SystemModes(driver=DeniedModes())
    snapshots, errors, pending = [], [], []
    service.changed.connect(snapshots.append)
    service.failed.connect(errors.append)
    service.pending_changed.connect(lambda mode, value: pending.append((mode, value)))
    try:
        wait_until(lambda: snapshots)
        service.set_mode('battery_saver', True)
        wait_until(lambda: errors)
        assert snapshots[-1]['battery_saver'] is False
        assert 'Access denied' in errors[0]
        assert pending[-1] == ('battery_saver', False)
    finally:
        service.shutdown()


@pytest.mark.parametrize('field,card_name,page', [
    ('wifi_enabled', 'wifi', 'network-wifi'),
    ('bluetooth_enabled', 'bluetooth', 'bluetooth'),
    ('airplane_mode', 'airplane', 'network-airplanemode'),
    ('battery_saver', 'battery_saver', 'batterysaver'),
])
def test_settings_arrow_is_separate_and_available_during_pending_or_unknown(app, monkeypatch, field, card_name, page):
    backend = PreviewBackend()
    opened, toggled = [], []
    monkeypatch.setattr(backend, 'open_settings', opened.append)
    monkeypatch.setattr(backend, f'set_{field}', toggled.append)
    panel = Quick(backend)
    panel.resize(312, panel.sizeHint().height())
    panel.show()
    card = getattr(panel, card_name)
    try:
        for unavailable in (False, True):
            setattr(backend.state, field, None if unavailable else False)
            backend.state.pending_modes.add(field)
            backend.changed.emit('status')
            QTest.mouseClick(card.settings_arrow, Qt.MouseButton.LeftButton)
            card.click()
            assert not toggled
            assert card.settings_arrow.isEnabled()
        assert opened == [page, page]
        backend.state.pending_modes.clear()
        setattr(backend.state, field, False)
        backend.changed.emit('status')
        card.click()
        assert toggled == [True]
    finally:
        panel.deleteLater()
        backend.deleteLater()


@pytest.mark.parametrize('enabled,payload', [(True, 2), (False, 1)])
def test_battery_saver_uses_verified_native_override_values(monkeypatch, enabled, payload):
    writes = []
    monkeypatch.setattr(system_modes, '_publish_saver_override', writes.append)
    system_modes.WindowsModes().write('battery_saver', enabled)
    assert writes == [payload]


@pytest.mark.parametrize('mode', ['wifi_enabled', 'bluetooth_enabled'])
def test_radio_control_reports_actual_state_without_touching_windows(monkeypatch, mode):
    from winrt.windows.devices.radios import RadioAccessStatus, RadioState
    radio = SimpleNamespace(state=RadioState.OFF)
    writes = []

    async def set_state(value):
        writes.append(value)
        radio.state = value
        return RadioAccessStatus.ALLOWED

    async def radios(requested):
        assert requested == mode
        return [radio]

    radio.set_state_async = set_state
    monkeypatch.setattr(system_modes, '_matching_radios', radios)
    driver = system_modes.WindowsModes()
    assert driver.read(mode) is False
    driver.write(mode, True)
    assert writes == [RadioState.ON]
    assert driver.read(mode) is True


def test_radio_permission_denial_is_visible(monkeypatch):
    from winrt.windows.devices.radios import RadioAccessStatus, RadioState

    async def denied(_):
        return RadioAccessStatus.DENIED_BY_SYSTEM

    async def radios(_):
        return [SimpleNamespace(state=RadioState.OFF, set_state_async=denied)]

    monkeypatch.setattr(system_modes, '_matching_radios', radios)
    with pytest.raises(OSError, match='denied access'):
        system_modes.WindowsModes().write('wifi_enabled', True)


def test_radio_permission_is_requested_once_on_gui_thread_after_click(app):
    async def exercise():
        gate = asyncio.Event()
        calls = []

        async def request_access():
            calls.append(QThread.currentThread())
            await gate.wait()
            return True

        driver = FakeModes()
        service = system_modes.SystemModes(driver=driver, request_radio_access=request_access)
        try:
            assert not calls
            assert service.set_mode('wifi_enabled', True)
            assert not service.set_mode('wifi_enabled', False)
            assert service.set_mode('bluetooth_enabled', True)
            await asyncio.sleep(0)
            assert calls == [app.thread()]
            assert not driver.writes
            gate.set()
            await asyncio.sleep(0)
            wait_until(lambda: len(driver.writes) == 2)
            wait_until(lambda: not service._pending)
            service.set_mode('wifi_enabled', False)
            wait_until(lambda: len(driver.writes) == 3)
            assert len(calls) == 1
        finally:
            service.shutdown()
    asyncio.run(exercise())


def test_radio_permission_denial_never_reaches_native_writer(app):
    async def exercise():
        async def denied():
            return False

        driver = FakeModes()
        service = system_modes.SystemModes(driver=driver, request_radio_access=denied)
        errors = []
        service.failed.connect(errors.append)
        try:
            service.set_mode('wifi_enabled', True)
            await asyncio.sleep(0)
            assert errors and 'denied permission' in errors[0]
            assert not driver.writes
            assert not service._pending
        finally:
            service.shutdown()
    asyncio.run(exercise())


def test_unconfirmed_native_change_never_reports_on(app):
    class IgnoredWrite(FakeModes):
        def write(self, mode, enabled):
            self.writes.append((mode, enabled))

    service = system_modes.SystemModes(driver=IgnoredWrite())
    service._worker.confirmation_timeout = .01
    errors, snapshots = [], []
    service.failed.connect(errors.append)
    service.changed.connect(snapshots.append)
    try:
        service.set_mode('battery_saver', True)
        wait_until(lambda: errors)
        assert 'did not confirm' in errors[0]
        assert snapshots[-1]['battery_saver'] is False
        assert not service._pending
    finally:
        service.shutdown()


@pytest.mark.parametrize('status', [0, -1073741790])
def test_native_saver_publish_wire_contract_and_status(monkeypatch, status):
    import ctypes

    calls = []
    def publish(name, type_id, payload, size, scope):
        calls.append((name, type_id, ctypes.cast(payload, ctypes.POINTER(ctypes.c_uint32)).contents.value,
                      size, scope))
        return status

    monkeypatch.setattr(system_modes.ctypes, 'WinDLL', lambda _: SimpleNamespace(RtlPublishWnfStateData=publish))
    if status < 0:
        with pytest.raises(OSError, match='C0000022'):
            system_modes._publish_saver_override(2)
    else:
        system_modes._publish_saver_override(2)
    assert calls == [(0x41C6013DA3BC3075, None, 2, 4, None)]
