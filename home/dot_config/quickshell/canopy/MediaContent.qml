import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

ColumnLayout {
    id: root
    readonly property var player: CanopyState.player
    readonly property bool hasTrack: CanopyState.preview || !!player
    readonly property real duration: CanopyState.preview ? 247 : player && player.lengthSupported ? player.length : 0
    readonly property real position: CanopyState.preview ? 94 : player && player.positionSupported ? player.position : 0
    spacing: 0
    function time(value) {
        const seconds = Math.max(0, Math.floor(value));
        return Math.floor(seconds / 60) + ":" + (seconds % 60).toString().padStart(2, "0");
    }
    Timer {
        interval: 1000
        running: root.visible && !!root.player && root.player.isPlaying && root.player.positionSupported
        repeat: true
        onTriggered: root.player.positionChanged()
    }
    Text {
        visible: !root.hasTrack
        Layout.fillWidth: true
        Layout.preferredHeight: 120
        text: "No media playing\n\nPlay something in a media app to see it here."
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
    }
    ColumnLayout {
        visible: root.hasTrack
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Item {
                Layout.preferredWidth: 104
                Layout.preferredHeight: 104
                CanopySurface { anchors.fill: parent; radius: 26; color: Theme.surface }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    layer.enabled: true
                }
                CanopySurface { id: artMask; anchors.fill: parent; radius: 26; color: "white"; layer.enabled: true; visible: false }
                MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: artMask; visible: art.status === Image.Ready }
                CanopyIcon { anchors.centerIn: parent; name: "disc-3"; size: 48; color: Theme.accent; visible: art.status !== Image.Ready }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                spacing: 0
                Item { Layout.fillHeight: true }
                Text {
                    text: CanopyState.mediaTitle; textFormat: Text.PlainText
                    color: Theme.text; font.family: Theme.displayFont; font.pixelSize: 25; font.weight: Font.DemiBold; font.letterSpacing: -0.6
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: text.length > 0
                    text: CanopyState.mediaArtist; textFormat: Text.PlainText
                    color: Theme.text; font.family: Theme.font; font.pixelSize: 13; elide: Text.ElideRight
                    Layout.fillWidth: true; Layout.topMargin: 8
                }
                Text {
                    visible: text.length > 0
                    text: CanopyState.preview ? "Forest sessions" : root.player ? root.player.trackAlbum : ""
                    textFormat: Text.PlainText; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight
                    Layout.fillWidth: true; Layout.topMargin: 3
                }
                Item { Layout.fillHeight: true }
            }
        }
        Item {
            visible: root.duration > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 25
            Layout.topMargin: 18
            Rectangle { width: parent.width; height: 4; radius: 2; color: Theme.raised }
            Rectangle { width: parent.width * Math.min(1, Math.max(0, root.position / root.duration)); height: 4; radius: 2; color: Theme.accent }
            Text { y: 10; text: root.time(root.position); color: Theme.text; font.family: Theme.utilityFont; font.pixelSize: 11 }
            Text { y: 10; anchors.right: parent.right; text: root.time(root.duration); color: Theme.muted; font.family: Theme.utilityFont; font.pixelSize: 11 }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            spacing: 8
            CanopyButton {
                id: previousButton
                implicitWidth: 40; implicitHeight: 40; radius: 16
                iconName: "skip-back"; iconSize: 22; hint: "Previous track"
                background: CanopySurface { radius: 16; color: previousButton.down ? Theme.selection : previousButton.hovered ? Theme.raised : Theme.surface; borderColor: Theme.accent; borderWidth: previousButton.visualFocus ? 1 : 0 }
                enabled: CanopyState.preview || !!root.player && root.player.canGoPrevious
                onClicked: { if (root.player) root.player.previous(); }
            }
            CanopyButton {
                implicitWidth: 64; implicitHeight: 40; radius: 20
                iconName: CanopyState.preview || root.player && root.player.isPlaying ? "pause" : "play"
                iconSize: 22; accent: true; hint: "Play or pause"
                enabled: CanopyState.preview || !!root.player && root.player.canTogglePlaying
                onClicked: { if (root.player) root.player.togglePlaying(); }
            }
            CanopyButton {
                id: nextButton
                implicitWidth: 40; implicitHeight: 40; radius: 16
                iconName: "skip-forward"; iconSize: 22; hint: "Next track"
                background: CanopySurface { radius: 16; color: nextButton.down ? Theme.selection : nextButton.hovered ? Theme.raised : Theme.surface; borderColor: Theme.accent; borderWidth: nextButton.visualFocus ? 1 : 0 }
                enabled: CanopyState.preview || !!root.player && root.player.canGoNext
                onClicked: { if (root.player) root.player.next(); }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: false
            Layout.preferredWidth: Math.min(root.width, outputLabel.implicitWidth + 19)
            Layout.topMargin: 14
            spacing: 6
            CanopyIcon { name: "headphones"; size: 13; color: Theme.muted }
            Text { id: outputLabel; text: CanopyState.audioDevice; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
}
