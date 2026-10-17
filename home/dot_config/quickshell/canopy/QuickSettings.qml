import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: root
    property bool showOutputs: false
    readonly property bool resizing: outputExpansion.running
    spacing: 12

    CanopySurface {
        Layout.fillWidth: true
        implicitHeight: brightnessBody.implicitHeight + 24
        radius: 18
        color: Theme.surface
        ColumnLayout {
            id: brightnessBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16; topMargin: 12 }
            spacing: 7
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 8
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    CanopyIcon { anchors.centerIn: parent; name: "monitor"; size: 18; color: Theme.muted }
                }
                Text { text: "Brightness"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
            }
            Repeater {
                model: CanopyState.brightnessOutputs
                ColumnLayout {
                    id: display
                    required property var modelData
                    required property int index
                    readonly property string outputName: modelData.name
                    readonly property string displayName: modelData.model.trim() || outputName
                    property int brightness: CanopyState.preview ? (index === 0 ? 72 : 85) : -1
                    property string error: ""
                    Layout.fillWidth: true
                    Layout.topMargin: index > 0 ? 8 : 1
                    spacing: 7

                    function refresh() {
                        if (!CanopyState.preview && !CanopyState.actionBusy && !probe.running) probe.running = true;
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            CanopyIcon { anchors.centerIn: parent; name: "sun"; size: 14; color: Theme.muted }
                        }
                        Text { text: display.displayName; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                        RowLayout {
                            visible: display.brightness >= 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            Text { text: Math.round(brightnessSlider.value); color: Theme.text; font.family: Theme.utilityFont; font.pixelSize: 16; Layout.alignment: Qt.AlignBaseline }
                            Text { text: "%"; color: Theme.muted; font.family: Theme.utilityFont; font.pixelSize: 10; Layout.alignment: Qt.AlignBaseline }
                        }
                    }
                    CanopySlider {
                        id: brightnessSlider
                        Layout.fillWidth: true
                        enabled: display.brightness >= 0
                        label: "Display brightness: " + display.displayName
                        value: Math.max(0, display.brightness)
                        onCommitted: level => CanopyState.setBrightness(display.outputName, level)
                    }
                    Text {
                        visible: display.brightness < 0
                        text: display.error || "Reading display brightness…"
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
                    }
                    Process {
                        id: probe
                        command: [CanopyState.brightnessCommand, "--output", display.outputName, "get"]
                        stdout: StdioCollector { id: output }
                        stderr: StdioCollector { id: errors }
                        onExited: (code, status) => {
                            if (code === 0 && status === 0) {
                                try {
                                    const result = JSON.parse(output.text);
                                    if (result.output !== display.outputName || !Number.isFinite(result.value)) throw new Error("Invalid brightness response");
                                    display.brightness = result.value;
                                    display.error = "";
                                    return;
                                } catch (error) { display.error = "Could not read display brightness."; }
                            } else {
                                display.error = errors.text.trim() || "Could not read display brightness.";
                            }
                            display.brightness = -1;
                        }
                    }
                    Connections {
                        target: CanopyState
                        function onActionBusyChanged() { if (!CanopyState.actionBusy) display.refresh(); }
                    }
                    Timer { interval: 10000; running: !CanopyState.preview; repeat: true; onTriggered: display.refresh() }
                    Component.onCompleted: refresh()
                }
            }
        }
    }
    CanopySurface {
        Layout.fillWidth: true
        implicitHeight: volumeBody.implicitHeight + 24
        radius: 18
        color: Theme.surface
        ColumnLayout {
            id: volumeBody
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16; topMargin: 12 }
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 8
                CanopyButton {
                    implicitWidth: 32
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    iconName: CanopyState.muted ? "volume-x" : "volume-2"
                    textColor: CanopyState.muted ? Theme.accent : Theme.text
                    hint: CanopyState.muted ? "Unmute playback" : "Mute playback"
                    enabled: CanopyState.preview || !!CanopyState.sink
                    onClicked: CanopyState.toggleMute()
                }
                Text { text: "Volume"; color: Theme.text; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium; Layout.alignment: Qt.AlignVCenter }
                Text { visible: CanopyState.muted; text: "Muted"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text { text: Math.round(volumeSlider.value); color: Theme.text; font.family: Theme.utilityFont; font.pixelSize: 24; Layout.alignment: Qt.AlignBaseline }
                    Text { text: "%"; color: Theme.muted; font.family: Theme.utilityFont; font.pixelSize: 11; Layout.alignment: Qt.AlignBaseline }
                }
            }
            CanopySlider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.topMargin: 10
                label: "Volume"
                value: CanopyState.volume
                enabled: CanopyState.preview || !!CanopyState.sink
                onMoved: CanopyState.setVolume(value)
            }
            CanopyButton {
                Layout.fillWidth: true
                Layout.topMargin: 10
                implicitHeight: Math.max(24, outputSummary.implicitHeight)
                padding: 0
                hint: "Choose audio output\n" + CanopyState.audioDeviceDescription
                onClicked: root.showOutputs = !root.showOutputs
                contentItem: RowLayout {
                    spacing: 8
                    ColumnLayout {
                        id: outputSummary
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text { text: CanopyState.audioDevice; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        Text {
                            visible: text.length > 0 && text !== CanopyState.audioDevice
                            text: CanopyState.audioDeviceDescription
                            color: Theme.muted; font.family: Theme.font; font.pixelSize: 10
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                        }
                    }
                    CanopyIcon { name: root.showOutputs ? "chevron-down" : "chevron-right"; size: 13; color: Theme.muted; Layout.alignment: Qt.AlignVCenter }
                }
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: outputExpansion.values[0]
                clip: true
                enabled: root.showOutputs
                CanopySpring { id: outputExpansion; values: [0] }
                ColumnLayout {
                    id: outputs
                    y: 10
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: CanopyState.audioOutputs
                        CanopyButton {
                            id: outputButton
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitHeight: outputLabel.implicitHeight + 16
                            leftPadding: 10; rightPadding: 10
                            topPadding: 8; bottomPadding: 8
                            text: modelData.name
                            hint: modelData.description || modelData.name
                            checked: modelData.active
                            contentItem: ColumnLayout {
                                id: outputLabel
                                spacing: 2
                                Text {
                                    text: outputButton.modelData.name
                                    color: outputButton.textColor; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                }
                                Text {
                                    visible: text.length > 0 && text !== outputButton.modelData.name
                                    text: outputButton.modelData.description || ""
                                    color: outputButton.checked ? Theme.black : Theme.muted
                                    font.family: Theme.font; font.pixelSize: 10
                                    Layout.fillWidth: true; wrapMode: Text.Wrap
                                }
                            }
                            onClicked: CanopyState.run(["wpctl", "set-default", String(modelData.id)])
                        }
                    }
                    Text { visible: CanopyState.audioOutputs.length === 0; text: "No audio outputs available"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    onImplicitHeightChanged: outputExpansion.move([root.showOutputs ? implicitHeight + y : 0])
                }
            }
        }
    }
    RowLayout {
        spacing: 8
        ModeCard {
            Layout.fillWidth: true
            caption: "Wi-Fi"
            symbol: active ? "wifi" : "wifi-off"
            active: CanopyState.preview || CanopyState.wifiEnabled
            busy: CanopyState.actionBusy
            showSettings: true
            onToggled: CanopyState.run(["nmcli", "radio", "wifi", CanopyState.wifiEnabled ? "off" : "on"])
            onSettingsRequested: CanopyState.launch(["kitty", "nmtui"])
        }
        ModeCard {
            Layout.fillWidth: true
            caption: "Bluetooth"
            symbol: "bluetooth"
            active: CanopyState.preview || !!CanopyState.adapter && CanopyState.adapter.enabled
            available: CanopyState.preview || !!CanopyState.adapter
            busy: CanopyState.actionBusy
            showSettings: true
            onToggled: CanopyState.toggleBluetooth()
            onSettingsRequested: CanopyState.launch(["kitty", "bluetoothctl"])
        }
    }
    RowLayout {
        spacing: 8
        ModeCard {
            Layout.fillWidth: true
            caption: "Microphone"
            symbol: active ? "mic" : "mic-off"
            active: !CanopyState.microphoneMuted
            available: CanopyState.preview || !!CanopyState.microphone
            busy: CanopyState.actionBusy
            onToggled: CanopyState.toggleMicrophone()
        }
        ModeCard {
            Layout.fillWidth: true
            caption: "Energy saver"
            symbol: "leaf"
            active: CanopyState.powerProfile === "power-saver"
            available: CanopyState.preview || CanopyState.powerProfile.length > 0
            busy: CanopyState.actionBusy
            onToggled: CanopyState.run(["powerprofilesctl", "set", active ? "balanced" : "power-saver"])
        }
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: 40
        Rectangle { x: 0; y: 4; width: parent.width; height: 1; color: Theme.raised }
        RowLayout {
            anchors { left: parent.left; right: powerButton.left; verticalCenter: powerButton.verticalCenter; rightMargin: 8 }
            spacing: 8
            visible: CanopyState.batteryText.length > 0
            CanopyIcon { name: CanopyState.charging ? "battery-charging" : "battery-medium"; size: 15; color: Theme.text; Layout.alignment: Qt.AlignVCenter }
            Text { text: CanopyState.batteryText + " · " + CanopyState.batteryStatus; color: Theme.text; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
        }
        CanopyButton { id: powerButton; anchors.right: parent.right; y: 8; width: 32; iconName: "power"; iconSize: 15; hint: "Power options"; onClicked: CanopyState.panel = "power" }
    }
    onShowOutputsChanged: outputExpansion.move([showOutputs ? outputs.implicitHeight + outputs.y : 0])
}
