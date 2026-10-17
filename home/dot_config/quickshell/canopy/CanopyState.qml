pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray

Singleton {
    id: root
    readonly property bool preview: Quickshell.env("CANOPY_PREVIEW") === "1"
    property bool launcherOpen: false
    property string launcherQuery: ""
    property string panel: ""
    property string coveredPanel: ""
    property var coveredScreen: null
    property bool trayMenuOpen: false
    readonly property var trayItems: preview ? [] : SystemTray.items.values
    property var targetScreen: null
    property var islandWidths: ({})
    property string lastError: ""
    property bool wifiEnabled: preview
    property string networkName: preview ? "Canopy home" : ""
    property string networkState: "Disconnected"
    property string powerProfile: "balanced"
    readonly property var brightnessOutputs: preview ? [
        {name: "DP-1", model: "External display", x: -2560, y: 0},
        {name: "eDP-1", model: "Built-in display", x: 0, y: 0}
    ] : Quickshell.screens.slice().sort((a, b) => a.x - b.x || a.y - b.y || a.name.localeCompare(b.name))
    readonly property string brightnessCommand: Quickshell.env("HOME") + "/.local/bin/screen-brightness"
    property int pendingVolume: -1
    property var pendingBrightness: ({})
    property bool bluetoothAction: false
    readonly property bool actionBusy: action.running
    property bool closeAfterAction: false
    readonly property var sink: preview ? null : Pipewire.defaultAudioSink
    readonly property var microphone: preview ? null : Pipewire.defaultAudioSource
    readonly property int volume: preview ? 64 : sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: !preview && sink && sink.audio ? sink.audio.muted : false
    readonly property bool microphoneMuted: !preview && microphone && microphone.audio ? microphone.audio.muted : false
    readonly property string audioDevice: preview ? "Speakers" : sink ? sink.nickname || sink.description || sink.name : "No output device"
    readonly property string audioDeviceDescription: preview ? "Built-in audio" : sink ? sink.description || sink.name : ""
    readonly property var audioOutputs: preview ? [{id: 1, name: "Speakers", description: "Built-in audio", active: true}] : Pipewire.nodes.values
        .filter(node => node.isSink && !node.isStream && node.audio)
        .map(node => ({id: node.id, name: node.nickname || node.description || node.name,
            description: node.description || node.name, active: node === root.sink}))
    readonly property bool bluetoothEnabled: preview || !!(adapter && adapter.enabled)
    readonly property var adapter: preview ? null : Bluetooth.defaultAdapter
    readonly property var player: preview ? null : Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    readonly property string mediaTitle: preview ? "A walk through the forest" : player ? player.trackTitle || player.identity : "Nothing playing"
    readonly property string mediaArtist: preview ? "Canopy · local preview" : player ? player.trackArtist : ""
    readonly property var battery: preview ? null : UPower.displayDevice && UPower.displayDevice.isLaptopBattery ? UPower.displayDevice : null
    readonly property int batteryPercentage: preview ? 82 : battery ? Math.round(battery.percentage * 100) : -1
    readonly property bool charging: preview || !!(battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge))
    readonly property string batteryStatus: preview ? "Charging" : battery ? UPowerDeviceState.toString(battery.state) : "No battery"
    readonly property string batteryText: batteryPercentage >= 0 ? batteryPercentage + "%" : ""
    readonly property var notifications: preview ? [
        {appName: "Canopy", summary: "Everything in its place", body: "Your workspace is ready."}
    ] : notificationServer.trackedNotifications.values

    function registerIslands(screen, leftWidth, mediaWidth, rightWidth) {
        if (!screen) return;
        const widths = Object.assign({}, islandWidths);
        widths[screen.name] = {left: leftWidth, media: mediaWidth, right: rightWidth};
        islandWidths = widths;
    }
    function focusedScreen() {
        if (!preview && Hyprland.focusedMonitor) {
            const found = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name);
            if (found) return found;
        }
        return Quickshell.screens[0] || null;
    }
    function toggleLauncher(screen) {
        const requestedScreen = screen || focusedScreen();
        const sameScreen = targetScreen && requestedScreen && targetScreen.name === requestedScreen.name;
        const wasOpen = launcherOpen && sameScreen;
        targetScreen = requestedScreen;
        panel = "";
        launcherQuery = "";
        launcherOpen = !wasOpen;
    }
    function togglePanel(kind, screen) {
        const requestedScreen = screen || focusedScreen();
        const sameScreen = targetScreen && requestedScreen && targetScreen.name === requestedScreen.name;
        const wasOpen = panel === kind && sameScreen;
        targetScreen = requestedScreen;
        launcherOpen = false;
        panel = wasOpen ? "" : kind;
    }
    function close() { launcherOpen = false; panel = ""; }
    function launch(args) {
        close();
        if (!preview) Quickshell.execDetached(args);
    }
    function focusWorkspace(number, screen) {
        if (preview || !Number.isInteger(number) || number < 1 || number > 8) return;
        if (screen) Hyprland.dispatch("hl.dsp.focus({ monitor = " + JSON.stringify(screen.name) + " })");
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + number + ", on_current_monitor = true })");
    }
    function toggleBluetooth() {
        if (adapter) run(["bluetoothctl", "--timeout", "8", "power", adapter.enabled ? "off" : "on"]);
    }
    function toggleMicrophone() { run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]); }
    function toggleMute() { run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); }
    function setVolume(value) {
        if (preview || !isFinite(value)) return;
        pendingVolume = Math.max(0, Math.min(100, Math.round(value)));
        sliderCommit.restart();
    }
    function setBrightness(output, value) {
        if (preview || !output || !isFinite(value)) return;
        const pending = Object.assign({}, pendingBrightness);
        pending[output] = Math.max(0, Math.min(100, Math.round(value)));
        pendingBrightness = pending;
        sliderCommit.restart();
    }
    function run(args, closeAfter) {
        if (preview || action.running) return;
        lastError = "";
        closeAfterAction = !!closeAfter;
        bluetoothAction = args[0] === "bluetoothctl";
        action.command = ["timeout", "--kill-after=1", "10", ...args];
        action.running = true;
    }
    function refresh() {
        if (preview) return;
        if (!wifiProbe.running) wifiProbe.running = true;
        if (!networkProbe.running) networkProbe.running = true;
        if (!ssidProbe.running) ssidProbe.running = true;
        if (!profileProbe.running) profileProbe.running = true;
    }
    function dismiss(notification) { if (!preview) notification.dismiss(); }

    PwObjectTracker { objects: root.preview ? [] : [root.sink, root.microphone].filter(n => n) }
    NotificationServer {
        id: notificationServer
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (trackedNotifications.values.length > 30) trackedNotifications.values[0].dismiss();
        }
    }
    Process {
        id: action
        environment: ({"LC_ALL": "C"})
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: (code, status) => {
            const output = actionOutput.text.trim();
            const bluetoothFailed = root.bluetoothAction && /failed|not available|no default controller/i.test(output);
            if (code === 124 || code === 137) root.lastError = "The operation timed out. Try again.";
            else if (code !== 0 || status !== 0 || bluetoothFailed)
                root.lastError = actionError.text.trim() || output || "The operation was not accepted.";
            else if (root.closeAfterAction) root.close();
            root.refresh();
            if (root.pendingVolume >= 0 || Object.keys(root.pendingBrightness).length > 0) sliderCommit.restart();
        }
    }
    Process {
        id: wifiProbe
        command: ["nmcli", "-t", "-f", "WIFI", "general"]
        environment: ({"LC_ALL": "C"})
        stdout: StdioCollector { id: wifiOutput; onStreamFinished: root.wifiEnabled = wifiOutput.text.trim() === "enabled" }
    }
    Process {
        id: networkProbe
        command: ["nmcli", "-t", "-f", "STATE", "general"]
        environment: ({"LC_ALL": "C"})
        stdout: StdioCollector { id: networkOutput; onStreamFinished: root.networkState = networkOutput.text.trim() || "Disconnected" }
    }
    Process {
        id: ssidProbe
        command: ["nmcli", "--terse", "--escape", "no", "--fields", "IN-USE,SSID", "device", "wifi", "list", "--rescan", "no"]
        environment: ({"LC_ALL": "C"})
        stdout: StdioCollector {
            id: ssidOutput
            onStreamFinished: {
                const current = ssidOutput.text.split("\n").find(line => line.startsWith("*:"));
                root.networkName = current ? current.slice(2) : "";
            }
        }
    }
    Process {
        id: profileProbe
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector { id: profileOutput; onStreamFinished: root.powerProfile = profileOutput.text.trim() }
    }
    Timer {
        id: sliderCommit
        interval: 60
        onTriggered: {
            if (action.running) return;
            if (root.pendingVolume >= 0) {
                const level = root.pendingVolume;
                root.pendingVolume = -1;
                root.run(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", level + "%"]);
            } else {
                const pending = Object.assign({}, root.pendingBrightness);
                const output = Object.keys(pending)[0];
                if (!output) return;
                const level = pending[output];
                delete pending[output];
                root.pendingBrightness = pending;
                root.run([root.brightnessCommand, "--output", output, "set", String(level)]);
            }
        }
    }
    Timer { interval: 10000; running: !root.preview; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
