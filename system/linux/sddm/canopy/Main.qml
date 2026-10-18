pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1440
    height: 900
    color: "#11160f"

    readonly property color surface: "#11160f"
    readonly property color raised: "#293522"
    readonly property color selection: "#3c502b"
    readonly property color accent: "#7cab3d"
    readonly property color foreground: "#f0f3e7"
    readonly property color muted: "#aab69e"
    readonly property int horizontalInset: Math.round(width * 0.09)
    readonly property int verticalInset: Math.round(height * 0.08)
    readonly property bool loginScreen: primaryScreen || Application.screens.length === 1
    property bool authenticating: false
    property bool focusInitialized: false
    property bool failed: false
    property string statusMessage: ""
    property string pendingPower: ""
    property date now: new Date()
    property int userIndex: Math.max(0, userModel.lastIndex)
    readonly property var selectedAccount: accounts.count ? accounts.objectAt(userIndex) : null
    readonly property string selectedUser: selectedAccount ? selectedAccount.name : ""

    Instantiator {
        id: accounts
        model: userModel
        delegate: QtObject { required property string name }
    }

    Keys.onLeftPressed: (event) => { event.accepted = event.modifiers === Qt.NoModifier && root.switchUser(-1); }
    Keys.onRightPressed: (event) => { event.accepted = event.modifiers === Qt.NoModifier && root.switchUser(1); }

    function switchUser(direction) {
        if (!loginScreen || authenticating || accounts.count < 2)
            return false;
        userIndex = (userIndex + direction + accounts.count) % accounts.count;
        password.clear();
        statusMessage = "";
        failed = false;
        focusInput();
        return true;
    }

    function focusInput() {
        if (!loginScreen || authenticating)
            return;
        const window = root.Window.window;
        if (window && window.visible && !window.active)
            window.requestActivate();
        password.forceActiveFocus();
        focusInitialized = !!window && window.active;
    }

    function submit(fingerprintOnly) {
        if (authenticating || !selectedUser || session.count === 0 || session.currentIndex < 0)
            return;
        authenticating = true;
        failed = false;
        const submittedPassword = fingerprintOnly ? "" : password.text;
        statusMessage = submittedPassword.length ? "Signing in…" : "Scan your finger…";
        sddm.login(selectedUser, submittedPassword, session.currentIndex);
    }

    function power(action) {
        if (pendingPower !== action) {
            pendingPower = action;
            powerReset.restart();
            return;
        }
        pendingPower = "";
        powerReset.stop();
        if (action === "restart") sddm.reboot();
        else if (action === "shutdown") sddm.powerOff();
        else if (action === "sleep") sddm.suspend();
    }

    Component.onCompleted: Qt.callLater(focusInput)
    onLoginScreenChanged: {
        focusInitialized = false;
        Qt.callLater(focusInput);
    }

    Connections {
        target: root.Window.window
        function onVisibleChanged() {
            if (root.Window.window.visible && !root.focusInitialized)
                Qt.callLater(root.focusInput);
        }
        function onActiveChanged() {
            if (root.Window.window.active && !root.focusInitialized)
                Qt.callLater(root.focusInput);
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    Timer { id: powerReset; interval: 5000; onTriggered: root.pendingPower = "" }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false;
            root.failed = true;
            root.statusMessage = "Couldn’t sign in. Please try again.";
            password.clear();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() { root.statusMessage = "Welcome back."; }
        function onInformationMessage(message) {
            root.failed = false;
            root.statusMessage = message;
        }
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl(config.stringValue("background"))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: "#11160f"; opacity: 0.14 }

    Column {
        id: clock
        visible: root.loginScreen
        anchors { top: parent.top; right: parent.right; topMargin: root.verticalInset; rightMargin: root.horizontalInset }
        spacing: 8
        Text {
            anchors.right: parent.right
            text: Qt.formatTime(root.now, "HH:mm")
            font { family: "Inter"; pixelSize: 104; weight: Font.Light; letterSpacing: -4 }
            color: root.foreground
        }
        Text {
            anchors.right: parent.right
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            font { family: "Inter"; pixelSize: 14; letterSpacing: 0.3 }
            color: root.muted
        }
    }

    ColumnLayout {
        id: loginForm
        objectName: "loginForm"
        visible: root.loginScreen
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.horizontalInset; bottomMargin: root.verticalInset }
        width: Math.min(400, root.width - 2 * root.horizontalInset)
        spacing: 14

        Text {
            objectName: "account"
            Layout.fillWidth: true
            Layout.bottomMargin: 16
            text: root.selectedUser || "No accounts available"
            color: root.foreground
            font { family: "Inter"; pixelSize: 34; weight: Font.Medium; letterSpacing: -0.7 }
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Input {
                id: password
                objectName: "password"
                echoMode: TextInput.Password
                placeholderText: "Password"
                enabled: !root.authenticating
                focus: root.loginScreen
                Keys.forwardTo: [root]
                Accessible.name: "Password"
                onAccepted: root.submit()
            }
            ActionButton {
                objectName: "signIn"
                primary: true
                text: root.authenticating ? "…" : "→"
                enabled: !root.authenticating && root.selectedUser.length > 0 && session.count > 0 && session.currentIndex >= 0
                Accessible.name: root.authenticating ? "Signing in" : "Sign in"
                ToolTip.visible: hovered
                ToolTip.text: "Sign in"
                onClicked: root.submit()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Selector {
                id: session
                objectName: "session"
                implicitHeight: 34
                model: sessionModel
                currentIndex: Math.max(0, sessionModel.lastIndex)
                emptyText: "No sessions available"
                textColor: root.muted
                font.pixelSize: 13
                Accessible.name: "Desktop session"
            }
            ActionButton {
                id: fingerprint
                objectName: "fingerprint"
                text: "Fingerprint"
                enabled: !root.authenticating && root.selectedUser.length > 0 && session.count > 0 && session.currentIndex >= 0
                Accessible.name: "Sign in with fingerprint"
                KeyNavigation.tab: password
                Keys.onReturnPressed: root.submit(true)
                Keys.onEnterPressed: root.submit(true)
                onClicked: root.submit(true)
            }
        }
    }

    Text {
        objectName: "status"
        visible: root.loginScreen
        anchors { left: loginForm.left; top: loginForm.bottom; topMargin: 12 }
        width: loginForm.width
        text: root.statusMessage || (keyboard.capsLock ? "Caps Lock is on" :
              !password.text.length && (password.activeFocus || fingerprint.activeFocus) ? "Press Enter to scan your finger." : "")
        color: root.failed || keyboard.capsLock ? "#eea99a" : root.muted
        font { family: "Inter"; pixelSize: 12 }
        wrapMode: Text.WordWrap
    }

    Row {
        visible: root.loginScreen
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: root.horizontalInset; bottomMargin: root.verticalInset }
        spacing: 22
        PowerButton { label: "Sleep"; powerAction: "sleep"; visible: sddm.canSuspend }
        PowerButton { label: "Restart"; powerAction: "restart"; visible: sddm.canReboot }
        PowerButton { label: "Shut down"; powerAction: "shutdown"; visible: sddm.canPowerOff }
    }

    component Input: TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: 52
        leftPadding: 0
        rightPadding: 0
        color: root.foreground
        placeholderTextColor: root.muted
        selectionColor: root.accent
        selectedTextColor: root.surface
        font { family: "Inter"; pixelSize: 16 }
        background: Item {
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: input.activeFocus ? root.accent : root.muted
                opacity: input.activeFocus ? 0.9 : 0.4
            }
        }
    }

    component Selector: ComboBox {
        id: selector
        property string emptyText: ""
        property color textColor: root.foreground
        Layout.fillWidth: true
        implicitHeight: 48
        textRole: "name"
        valueRole: "name"
        enabled: !root.authenticating
        leftPadding: 0
        rightPadding: 18
        font { family: "Inter"; pixelSize: 15 }
        contentItem: Text {
            text: selector.count ? selector.displayText : selector.emptyText
            color: selector.hovered || selector.activeFocus ? root.foreground : selector.textColor
            font: selector.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            x: Math.min(selector.contentItem.implicitWidth + 10, selector.width - width)
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"; color: root.muted; font.pixelSize: 10
        }
        background: Item {
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                visible: selector.activeFocus
                color: root.accent
            }
        }
        delegate: ItemDelegate {
            id: option
            required property string name
            required property int index
            width: selector.width - 8
            text: name
            font: selector.font
            highlighted: selector.highlightedIndex === index
            contentItem: Text { text: option.text; color: root.foreground; font: selector.font; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 8; color: option.highlighted ? root.selection : "transparent" }
        }
        popup: Popup {
            y: -implicitHeight - 8
            width: selector.width
            padding: 4
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 180)
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: selector.popup.visible ? selector.delegateModel : null
                currentIndex: selector.highlightedIndex
            }
            background: Rectangle { color: root.surface; radius: 12; border.color: root.selection }
        }
    }

    component ActionButton: Button {
        id: button
        property bool primary: false
        implicitWidth: primary ? 52 : implicitContentWidth
        implicitHeight: primary ? 52 : 34
        leftPadding: 0
        rightPadding: 0
        opacity: enabled ? 1 : 0.45
        contentItem: Text {
            text: button.text
            color: button.primary ? root.accent : button.hovered || button.activeFocus ? root.foreground : root.muted
            font { family: "Inter"; pixelSize: button.primary ? 27 : 13; weight: Font.Normal }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: button.primary ? height / 2 : 4
            color: button.primary && (button.hovered || button.down) ? root.selection : "transparent"
            border.width: button.activeFocus ? 1 : 0
            border.color: root.accent
        }
    }

    component PowerButton: ActionButton {
        required property string label
        required property string powerAction
        text: root.pendingPower === powerAction ? "Confirm " + label.toLowerCase() : label
        enabled: !root.authenticating
        onClicked: root.power(powerAction)
    }
}
