pragma Singleton
import QtQuick

QtObject {
    readonly property bool reducedMotion: Application.styleHints.accessibility.motionPreference === Qt.ReducedMotion
    // Qt's blur kernel needs this range to match Canopy's Gaussian radius of 4.
    readonly property int transitionBlurMax: 20
    readonly property color black: "#000000"
    readonly property color surface: "#11160f"
    readonly property color raised: "#293522"
    readonly property color selection: "#3c502b"
    readonly property color accent: "#7cab3d"
    readonly property color text: "#f0f3e7"
    readonly property color muted: "#aab69e"
    readonly property color error: "#eea99a"
    readonly property color border: "#849575"
    readonly property string font: "Inter"
    readonly property string displayFont: "Inter"
    readonly property string utilityFont: "JetBrains Mono"
    readonly property string icons: "JetBrainsMono Nerd Font Mono"
}
