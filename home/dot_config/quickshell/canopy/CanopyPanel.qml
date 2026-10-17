pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: popup
    property string kind: "quick"
    property var hostWindow: null
    property real sourceWidth: 240
    property real availableHeight: 900
    property bool expanded: false
    property bool present: false
    property real reveal: 0
    property bool opening: false
    readonly property bool rightEdge: kind !== "media"
    readonly property real bodyWidth: width - (rightEdge ? 24 : 48)
    readonly property real bodyHeight: Math.min(body.implicitHeight, availableHeight)
    property alias hitArea: shape
    implicitWidth: Math.max(body.implicitWidth, sourceWidth) + (rightEdge ? 24 : 48)
    // A fixed canvas avoids clipping a shrinking shape and reallocating effect
    // textures on every frame when a section inside the panel expands.
    implicitHeight: availableHeight + 24
    visible: present
    focus: true
    Keys.onEscapePressed: CanopyState.close()
    signal opened()
    signal closed()

    function destination() { return expanded ? [bodyWidth, bodyHeight, 44] : [sourceWidth, 40, 16]; }
    function finishTransition() {
        if (geometry.running || contentReveal.running) return;
        if (!expanded && present) {
            present = false;
            closed();
        } else if (expanded && opening) {
            opening = false;
            opened();
        }
    }
    function begin() {
        contentReveal.stop();
        if (expanded && !present) {
            geometry.snap([sourceWidth, 40, 16]);
            reveal = 0;
            present = true;
            Qt.callLater(() => popup.forceActiveFocus());
        }
        if (!present) return;
        opening = expanded;
        contentReveal.start();
        geometry.move(destination());
    }
    function fit() {
        if (!present || !expanded) return;
        // The device list already animates its layout. Follow that height
        // directly instead of putting a second spring behind it.
        if (!opening && body.resizing) geometry.snap(destination());
        else geometry.move(destination());
    }
    onExpandedChanged: begin()
    onBodyWidthChanged: fit()
    onBodyHeightChanged: fit()
    onSourceWidthChanged: { if (present && !expanded) geometry.move(destination()); }

    CanopySpring { id: geometry; values: [240, 40, 16]; onSettled: popup.finishTransition() }
    SequentialAnimation {
        id: contentReveal
        PauseAnimation { duration: popup.expanded && !Theme.reducedMotion ? 70 : 0 }
        NumberAnimation {
            target: popup
            property: "reveal"
            to: popup.expanded ? 1 : 0
            duration: Theme.reducedMotion ? 100 : popup.expanded ? 220 : 120
            easing.type: Easing.OutCubic
        }
        onFinished: popup.finishTransition()
    }
    Item {
        anchors.fill: parent
        // Keep the shadow's render targets fixed while the shape grows inside.
        // Resizing the effect itself reallocates its blur textures every frame.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#60000000"
            shadowBlur: 0.7
            shadowVerticalOffset: 8
            shadowOpacity: popup.reveal
        }
        CanopySurface {
            id: shape
            x: popup.rightEdge ? popup.width - width : (popup.width - width) / 2
            width: geometry.values[0]
            height: geometry.values[1]
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: geometry.values[2]
            bottomRightRadius: popup.rightEdge ? 0 : bottomLeftRadius
        }
    }
    Item {
        id: contentMask
        width: body.width
        height: body.height
        visible: false
        layer.enabled: true
        CanopySurface {
            x: shape.x - body.x
            y: -body.y
            width: shape.width
            height: shape.height
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: shape.bottomLeftRadius
            bottomRightRadius: shape.bottomRightRadius
            color: "white"
        }
    }
    PanelContent {
        id: body
        x: popup.rightEdge ? popup.width - width : (popup.width - width) / 2
        y: Theme.reducedMotion ? 0 : 4 * (1 - popup.reveal)
        width: popup.bodyWidth
        height: popup.availableHeight
        kind: popup.kind
        hostWindow: popup.hostWindow
        paintBackground: false
        opacity: popup.reveal
        enabled: popup.expanded && popup.reveal >= 0.8
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: contentMask
            blurEnabled: !Theme.reducedMotion
            blurMax: Theme.transitionBlurMax
            blur: 1 - popup.reveal
        }
    }
    onOpened: body.forceActiveFocus()
}
