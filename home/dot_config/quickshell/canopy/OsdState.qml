pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool shown: false
    property string kind: "volume"
    property string label: "Volume"
    property int value: 0
    property bool muted: false
    property var screen: null
    readonly property bool audioReady: !!(CanopyState.sink && CanopyState.sink.ready && CanopyState.sink.audio)
    property bool audioInitialized: false
    property var observedSink: null
    property int previousVolume: 0
    property bool previousMuted: false
    property var expectedAudio: []

    function show(kind, label, value, muted, screen) {
        root.kind = kind;
        root.label = label;
        root.value = value;
        root.muted = muted;
        root.screen = screen;
        shown = true;
        hide.restart();
    }
    function brightness(output, name, value) {
        const screen = Quickshell.screens.find(s => s.name === output);
        if (screen) show("brightness", name || "Brightness", value, false, screen);
    }
    // Match only changes requested by Quick Settings, even while its panel is open.
    function expectAudio(kind, value) {
        const now = Date.now();
        expectedAudio = expectedAudio.filter(change => change.until > now)
            .concat([{kind: kind, value: value, until: now + 1500}]);
    }
    function consumeExpected(kind, value) {
        const pending = expectedAudio.filter(change => change.until > Date.now());
        const index = pending.findIndex(change => change.kind === kind && change.value === value);
        if (index >= 0) pending.splice(index, 1);
        expectedAudio = pending;
        return index >= 0;
    }
    function resetAudio() {
        audioInitialized = false;
        expectedAudio = [];
        feedback.stop();
        initialize.restart();
    }
    function observeAudio() {
        if (observedSink !== CanopyState.sink) { resetAudio(); return; }
        if (!audioInitialized || !audioReady) return;
        const volume = CanopyState.volume;
        const muted = CanopyState.muted;
        let external = false;
        if (volume !== previousVolume) external = !consumeExpected("volume", volume);
        if (muted !== previousMuted) external = !consumeExpected("mute", muted) || external;
        if (volume === previousVolume && muted === previousMuted) return;
        previousVolume = volume;
        previousMuted = muted;
        if (external) show("volume", "Volume", volume, muted, CanopyState.focusedScreen());
        feedback.restart();
    }
    onAudioReadyChanged: resetAudio()
    Connections {
        target: CanopyState
        function onSinkChanged() { root.resetAudio(); }
        function onVolumeChanged() { root.observeAudio(); }
        function onMutedChanged() { root.observeAudio(); }
    }
    Timer {
        id: initialize
        interval: 200
        onTriggered: {
            if (!root.audioReady) return;
            root.previousVolume = CanopyState.volume;
            root.previousMuted = CanopyState.muted;
            root.observedSink = CanopyState.sink;
            root.audioInitialized = true;
        }
    }
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }
    Timer {
        id: feedback
        interval: 150
        onTriggered: {
            if (!CanopyState.preview && root.audioReady && !CanopyState.muted && CanopyState.volume > 0 && !sound.running)
                sound.running = true;
        }
    }
    Process {
        id: sound
        command: ["timeout", "--kill-after=1", "2", "pw-play", "--media-role", "Notification",
            "--volume", "1", "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"]
    }
    Component.onCompleted: resetAudio()
}
