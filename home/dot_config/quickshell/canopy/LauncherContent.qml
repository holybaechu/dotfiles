pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

CanopySurface {
    id: root
    implicitWidth: 480
    implicitHeight: 420
    color: Qt.rgba(17 / 255, 22 / 255, 15 / 255, 190 / 255)
    radius: 32
    borderColor: Qt.rgba(132 / 255, 149 / 255, 117 / 255, 0.47)
    borderWidth: 1
    property var files: []
    property string runningQuery: ""
    property string searchError: ""
    property bool launching: false
    readonly property string historyDirectory: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/canopy"
    property bool historyLoaded: false
    property bool historyDirectoryReady: false
    property var pendingHistory: []
    readonly property bool fileMode: /^\s*file\s/i.test(input.text)
    readonly property string query: (fileMode ? input.text.replace(/^\s*file\s+/i, "") : input.text).trim()
    readonly property var entries: CanopyState.preview ? [
        {name: "Codex", genericName: "Coding assistant", icon: "chatgpt"},
        {name: "Kitty", genericName: "Terminal", icon: "utilities-terminal"},
        {name: "Helium", genericName: "Web browser", icon: "web-browser"},
        {name: "mpv", genericName: "Media player", icon: "mpv"},
        {name: "PeaZip", genericName: "Archive manager", icon: "package-x-generic"},
        {name: "Yazi File Manager", genericName: "File manager", icon: "system-file-manager"}
    ] : DesktopEntries.applications.values
    readonly property var settings: [
        {name: "Sound", detail: "Settings · Output volume and microphone", keywords: "audio speaker volume mute", panel: "quick", icon: "volume"},
        {name: "Wi-Fi", detail: "Settings · Network connections", keywords: "network internet wireless", panel: "quick", icon: "wifi"},
        {name: "Bluetooth", detail: "Settings · Bluetooth devices", keywords: "wireless devices", panel: "quick", icon: "bluetooth"},
        {name: "Brightness", detail: "Settings · Display brightness", keywords: "screen display backlight", panel: "quick", icon: "sun"},
        {name: "Power mode", detail: "Settings · Power profiles", keywords: "battery performance balanced saver", panel: "quick", icon: "battery"},
        {name: "Notifications", detail: "Settings · Notification history", keywords: "messages alerts", panel: "notifications", icon: "bell"},
        {name: "Calendar", detail: "Settings · Date and calendar", keywords: "date time clock", panel: "calendar", icon: "panels-top-left"}
    ]
    readonly property var results: {
        const fileResults = files.map(path => ({
            name: path.replace(/\/$/, "").split("/").pop(),
            detail: (path.endsWith("/") ? "Folder" : "File") + " · " + path,
            path: path,
            icon: path.endsWith("/") ? "folder" : "file"
        }));
        if (fileMode) return fileResults;
        const history = launchHistory.applications || {};
        const recent = Object.keys(history).filter(id => history[id] && Number.isFinite(history[id].lastUsed))
            .sort((a, b) => history[b].lastUsed - history[a].lastUsed).slice(0, 10);
        const apps = entries.filter(entry => !entry.noDisplay).map(entry => ({
            name: entry.name,
            detail: "Application" + (entry.genericName ? " · " + entry.genericName : ""),
            entry: entry,
            lastUsed: recent.includes(entry.id) ? history[entry.id].lastUsed || 0 : 0,
            score: appScore(entry)
        })).filter(result => result.score >= 0);
        const matchedSettings = query ? settings.map(setting => Object.assign({}, setting, {
            score: matchScore(query, setting.name, setting.keywords)
        })).filter(result => result.score >= 0) : [];
        const matched = apps.concat(matchedSettings).sort((a, b) => (query ? b.score - a.score : b.lastUsed - a.lastUsed) || a.name.localeCompare(b.name));
        // Reserve some places for filenames, as in the original combined search.
        const reserved = Math.min(5, fileResults.length);
        return matched.slice(0, 24 - reserved).concat(fileResults.slice(0, Math.max(reserved, 24 - matched.length)));
    }

    function appScore(entry) {
        const score = matchScore(query, entry.name, (entry.genericName || "") + " " + (entry.keywords || ""));
        const previous = (launchHistory.applications || {})[entry.id];
        if (score < 400 || !previous || !Number.isFinite(previous.count) || !Number.isFinite(previous.lastUsed)) return score;
        // Match Canopy's original frequency/recency boost without promoting
        // weak subsequence matches above well-matched application names.
        const hours = (Date.now() - previous.lastUsed) / 3600000;
        const recency = hours < 4 ? 1 : hours < 24 ? 0.8 : hours < 168 ? 0.6 : 0.4;
        return score + Math.min((previous.count || 0) * recency * 1.5, 3) * 200;
    }
    function recordApplication(id) {
        if (CanopyState.preview || !id) return;
        if (!historyLoaded) {
            pendingHistory = pendingHistory.concat([id]);
            return;
        }
        const history = Object.assign({}, launchHistory.applications || {});
        const count = (history[id] || {}).count;
        history[id] = {count: Math.min(Number.isFinite(count) ? count + 1 : 1, 1000000), lastUsed: Date.now()};
        const retained = Object.keys(history).filter(key => history[key] && Number.isFinite(history[key].lastUsed))
            .sort((a, b) => history[b].lastUsed - history[a].lastUsed).slice(0, 100);
        const bounded = {};
        for (const key of retained) bounded[key] = history[key];
        launchHistory.applications = bounded;
        if (historyDirectoryReady) historyFile.writeAdapter();
        else if (!makeHistoryDirectory.running) makeHistoryDirectory.running = true;
    }
    function finishHistoryLoad() {
        historyLoaded = true;
        const pending = pendingHistory;
        pendingHistory = [];
        for (const id of pending) recordApplication(id);
    }

    function matchScore(needle, name, keywords) {
        if (!needle) return 0;
        needle = needle.toLowerCase();
        name = name.toLowerCase();
        if (name === needle) return 1000;
        if (name.startsWith(needle)) return 800;
        if (name.includes(needle)) return 600;
        if (needle.split(/\s+/).every(word => (name + " " + keywords.toLowerCase()).includes(word))) return 400;
        // Short abbreviations may match the name in order (e.g. "kty" → Kitty).
        let position = -1;
        let gaps = 0;
        for (const letter of needle.replace(/\s+/g, "")) {
            const next = name.indexOf(letter, position + 1);
            if (next < 0) return -1;
            gaps += next - position - 1;
            position = next;
        }
        return 100 - Math.min(gaps, 99);
    }
    function reset(text) {
        launching = false;
        input.text = text || "";
        searchError = "";
        list.currentIndex = results.length ? 0 : -1;
        input.forceActiveFocus();
        if (query.length >= 2) debounce.restart();
    }
    function moveSelection(step) {
        list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + step));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function activate(index) {
        const result = results[index];
        if (!result || launching || input.inputMethodComposing || (!CanopyState.launcherOpen && !CanopyState.preview)) return;
        launching = true;
        if (result.panel) {
            CanopyState.togglePanel(result.panel, CanopyState.targetScreen);
            return;
        }
        CanopyState.close();
        if (CanopyState.preview) return;
        if (result.path) Quickshell.execDetached(["xdg-open", result.path]);
        else if (result.entry.runInTerminal) {
            // DesktopEntry.command retains field codes; no files are being
            // supplied when opening a terminal app from the launcher.
            const command = result.entry.command.filter(arg => !/^%[fFuU]$/.test(arg)).map(arg => arg.replace(/%%/g, "%"));
            Quickshell.execDetached(["kitty", "--directory=" + (result.entry.workingDirectory || Quickshell.env("HOME")), ...command]);
        } else result.entry.execute();
        if (result.entry) recordApplication(result.entry.id);
    }
    onQueryChanged: {
        files = [];
        runningQuery = "";
        searchError = "";
        launching = false;
        if (search.running) search.running = false;
        debounce.restart();
    }
    onResultsChanged: {
        // App results update immediately; incoming filenames must not move an app
        // that the user has already selected with the keyboard.
        const selectedName = list.selectionQuery === query ? list.selectedName : "";
        const index = selectedName ? results.findIndex(result => result.name === selectedName) : -1;
        list.selectionQuery = query;
        list.currentIndex = results.length ? Math.max(0, index) : -1;
        list.selectedName = list.currentIndex >= 0 ? results[list.currentIndex].name : "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 10
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 25
            Layout.rightMargin: 25
            spacing: 12
            CanopyIcon { name: "search"; size: 24; color: Theme.accent }
            TextField {
                id: input
                Layout.fillWidth: true
                implicitHeight: 48
                padding: 0
                placeholderText: "Search apps, settings and files…"
                Accessible.name: "Search applications, settings and files"
                font.family: Theme.font
                font.pixelSize: 17
                color: Theme.text
                placeholderTextColor: Theme.muted
                selectionColor: Theme.accent
                selectedTextColor: Theme.black
                background: Item {}
                Keys.onPressed: event => {
                    if (input.inputMethodComposing) return;
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
                        root.moveSelection(event.key === Qt.Key_Down ? 1 : event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_PageDown ? 5 : -5);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate(list.currentIndex);
                    else if (event.key === Qt.Key_Escape) CanopyState.close();
                    else if (event.key === Qt.Key_R && event.modifiers & Qt.ControlModifier) {
                        root.searchError = "";
                        debounce.restart();
                    } else return;
                    event.accepted = true;
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 26
            Layout.rightMargin: 26
            Layout.preferredHeight: 22
            text: root.searchError || (root.fileMode ? "Files & folders · Home" : "Applications, settings & files")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: root.searchError ? Theme.error : Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }
        ListView {
            id: list
            property string selectedName: ""
            property string selectionQuery: ""
            Layout.fillWidth: true
            Layout.fillHeight: true
            Accessible.name: "Search results"
            clip: true
            model: root.results
            currentIndex: 0
            highlightMoveDuration: 0
            onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.results.length) selectedName = root.results[currentIndex].name
            ScrollBar.vertical: ScrollBar {
                implicitWidth: 4
                padding: 0
                contentItem: Rectangle { implicitWidth: 4; implicitHeight: 24; color: Theme.raised; radius: 2 }
                background: Item {}
            }
            delegate: Item {
                id: resultRow
                required property var modelData
                required property int index
                width: list.width
                height: 54
                readonly property bool selected: ListView.isCurrentItem
                CanopySurface {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 14
                    color: resultRow.selected ? Theme.raised : rowMouse.containsMouse ? Theme.surface : "transparent"
                    Rectangle {
                        x: 1; y: 16; width: 3; height: 18; radius: 1.5
                        color: Theme.accent
                        visible: resultRow.selected
                    }
                    Image {
                        id: appIcon
                        x: 14; y: 10; width: 30; height: 30
                        visible: source.toString().length > 0 && status !== Image.Error
                        source: resultRow.modelData.entry ? Quickshell.iconPath(resultRow.modelData.entry.icon, true) : ""
                        sourceSize.width: 30
                        sourceSize.height: 30
                    }
                    CanopyIcon {
                        x: 17; y: 13; size: 24
                        visible: !appIcon.visible
                        name: resultRow.modelData.icon || "app-window"
                        color: resultRow.selected ? Theme.accent : Theme.muted
                    }
                    Text {
                        x: 58; y: 7; width: parent.width - 84; height: 20
                        text: resultRow.modelData.name
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    Text {
                        x: 58; y: 27; width: parent.width - 84; height: 16
                        text: resultRow.modelData.detail
                        textFormat: Text.PlainText
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.activate(resultRow.index)
                }
                ToolTip.visible: rowMouse.containsMouse
                ToolTip.delay: 700
                ToolTip.text: modelData.name + "\n" + modelData.detail
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 52
                visible: root.results.length === 0
                text: root.searchError || (search.running ? "Searching…" : root.fileMode && root.query.length < 2 ? "Search files and folders\nType a filename after “file ”." : "No matches. Try another name.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }
        }
        Text {
            Layout.leftMargin: 26
            Layout.preferredHeight: 26
            topPadding: 6
            text: "↑↓  Navigate     Enter  Open     Esc  Close"
            color: Theme.muted
            font.family: Theme.utilityFont
            font.pixelSize: 10
        }
    }
    FileView {
        id: historyFile
        path: CanopyState.preview ? "" : root.historyDirectory + "/launcher-history.json"
        printErrors: false
        onLoaded: root.finishHistoryLoad()
        onLoadFailed: root.finishHistoryLoad()
        onSaveFailed: error => console.warn("Could not save launcher history:", FileViewError.toString(error))
        JsonAdapter { id: launchHistory; property var applications: ({}) }
    }
    Process {
        id: makeHistoryDirectory
        command: ["mkdir", "-p", "--", root.historyDirectory]
        onExited: (code, status) => {
            if (code === 0) {
                root.historyDirectoryReady = true;
                historyFile.writeAdapter();
            } else console.warn("Could not create the launcher history directory.");
        }
    }
    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            if (root.query.length < 2) return;
            if (CanopyState.preview) {
                root.files = root.fileMode ? ["/home/demo/Documents/Canopy notes.md", "/home/demo/Pictures/Forest/"] : [];
                return;
            }
            if (search.running) { restart(); return; }
            root.runningQuery = root.query;
            search.command = ["fd", "--type", "f", "--type", "d", "--color", "never", "--absolute-path", "--hidden", "--ignore-case", "--fixed-strings", "--max-results", "24", "--exclude", ".git", "--exclude", ".cache", "--exclude", "node_modules", "--exclude", ".venv", "--print0", "--", root.query, Quickshell.env("HOME")];
            search.running = true;
        }
    }
    Connections {
        target: CanopyState
        function onLauncherOpenChanged() {
            if (!CanopyState.launcherOpen) {
                debounce.stop();
                root.runningQuery = "";
                search.running = false;
                root.files = [];
            }
        }
    }
    Timer {
        interval: 8000
        running: search.running
        onTriggered: {
            root.runningQuery = "";
            search.running = false;
            root.searchError = "Search timed out. Try a more specific filename.";
        }
    }
    Process {
        id: search
        stderr: StdioCollector { id: searchFailure }
        onExited: (code, status) => {
            if (code !== 0 && root.runningQuery && root.query === root.runningQuery)
                root.searchError = searchFailure.text.trim() || "File search could not finish. Press Ctrl+R to retry.";
        }
        stdout: StdioCollector {
            id: fileOutput
            onStreamFinished: {
                if (root.runningQuery && root.query === root.runningQuery) root.files = fileOutput.text.split("\0").filter(path => path.length > 0);
            }
        }
    }
}
