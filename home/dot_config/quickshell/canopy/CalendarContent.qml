import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    readonly property date today: calendarClock.date
    property int month: today.getMonth()
    property int year: today.getFullYear()
    property date focusedDate: today
    readonly property date first: new Date(year, month, 1)
    readonly property int offset: (first.getDay() + 6) % 7
    spacing: 16
    SystemClock { id: calendarClock; precision: SystemClock.Minutes }
    function focusDate(date, grab) {
        focusedDate = date;
        year = date.getFullYear(); month = date.getMonth();
        if (grab) Qt.callLater(() => {
            const day = days.itemAt(date.getDate() + root.offset - 1);
            if (day) day.forceActiveFocus(Qt.TabFocusReason);
        });
    }
    function changeMonth(delta, date, grab) {
        const next = new Date(date.getFullYear(), date.getMonth() + delta, 1);
        next.setDate(Math.min(date.getDate(), new Date(next.getFullYear(), next.getMonth() + 1, 0).getDate()));
        focusDate(next, grab);
    }
    function move(date, amount) { focusDate(new Date(date.getFullYear(), date.getMonth(), date.getDate() + amount), true); }
    RowLayout {
        spacing: 8
        CanopyButton { implicitWidth: 32; iconName: "chevron-left"; hint: "Previous month"; onClicked: root.changeMonth(-1, root.first, false) }
        CanopyButton {
            Layout.fillWidth: true
            text: Qt.locale().name.startsWith("ko") ? Qt.formatDate(root.first, "yyyy년 M월") : Qt.formatDate(root.first, "MMMM yyyy")
            font.family: Theme.displayFont; font.pixelSize: 18; font.weight: Font.DemiBold
            hint: "Back to this month"
            onClicked: root.focusDate(root.today, false)
        }
        CanopyButton { implicitWidth: 32; iconName: "chevron-right"; hint: "Next month"; onClicked: root.changeMonth(1, root.first, false) }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 4
        rowSpacing: 4
        Repeater {
            model: 7
            Text {
                required property int index
                text: {
                    const day = (index + 1) % 7;
                    const narrow = Qt.locale().dayName(day, Locale.NarrowFormat);
                    return /^[0-9]+$/.test(narrow) ? Qt.locale().dayName(day, Locale.ShortFormat).slice(0, 1) : narrow;
                }
                color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true; Layout.preferredHeight: 30
            }
        }
        Repeater {
            id: days
            model: 42
            Button {
                id: dayButton
                required property int index
                readonly property date day: new Date(root.year, root.month, index - root.offset + 1)
                readonly property bool current: day.toDateString() === root.today.toDateString()
                implicitWidth: 32; implicitHeight: 32
                Layout.alignment: Qt.AlignHCenter
                hoverEnabled: true
                focusPolicy: day.toDateString() === root.focusedDate.toDateString() ? Qt.StrongFocus : Qt.ClickFocus
                Accessible.name: Qt.formatDate(day, Qt.DefaultLocaleLongDate)
                contentItem: Text {
                    text: dayButton.day.getDate()
                    color: dayButton.current ? Theme.black : dayButton.day.getMonth() === root.month ? Theme.text : Theme.border
                    font.family: Theme.font; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 16
                    color: dayButton.current ? Theme.accent : dayButton.hovered ? Theme.surface : "transparent"
                    border.width: dayButton.visualFocus ? 2 : 0
                    border.color: Theme.accent
                }
                onClicked: root.focusedDate = day
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) root.move(day, -1);
                    else if (event.key === Qt.Key_Right) root.move(day, 1);
                    else if (event.key === Qt.Key_Up) root.move(day, -7);
                    else if (event.key === Qt.Key_Down) root.move(day, 7);
                    else if (event.key === Qt.Key_Home) root.move(day, -((day.getDay() + 6) % 7));
                    else if (event.key === Qt.Key_End) root.move(day, 6 - ((day.getDay() + 6) % 7));
                    else if (event.key === Qt.Key_PageUp) root.changeMonth(-1, day, true);
                    else if (event.key === Qt.Key_PageDown) root.changeMonth(1, day, true);
                    else return;
                    event.accepted = true;
                }
            }
        }
    }
}
