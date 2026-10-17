import QtQuick

QtObject {
    id: spring
    property var values: [0]
    property var target: values.slice()
    property var velocity: values.map(() => 0)
    property real retention: 0.14
    property real force: 0.19
    readonly property bool running: frames.running
    signal settled()

    function snap(next) {
        frames.stop();
        target = next.slice();
        velocity = next.map(() => 0);
        values = next.slice();
    }
    function move(next) {
        target = next.slice();
        if (Theme.reducedMotion) {
            snap(next);
            settled();
        } else frames.start();
    }
    function step(seconds) {
        // Original Canopy's per-frame spring, normalized to 60 Hz and capped
        // after a missed frame. Retargeting preserves the current momentum.
        const elapsed = Math.min(2, Math.max(0, seconds * 60));
        const next = values.slice(), speeds = velocity.slice();
        let done = true;
        for (let i = 0; i < target.length; i++) {
            const delta = target[i] - values[i];
            const movement = speeds[i] * retention + delta * force * elapsed;
            if (Math.abs(delta) < 0.1 && Math.abs(movement) < 0.1) {
                next[i] = target[i];
                speeds[i] = 0;
            } else {
                next[i] += movement;
                speeds[i] = movement;
                done = false;
            }
        }
        velocity = speeds;
        values = next;
        if (done) {
            frames.stop();
            settled();
        }
    }
    property FrameAnimation frames: FrameAnimation {
        onTriggered: spring.step(frameTime)
    }
}
