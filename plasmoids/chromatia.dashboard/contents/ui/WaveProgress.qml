// Squiggly progress (Android 13 style): the filled part is a moving wave, the rest a flat track.
// The wave flattens when playback pauses or a slider is muted; amplitude 0 gives a plain bar.
import QtQuick
import QtQuick.Shapes

Item {
    id: w
    property real value: 0              // 0..1
    property bool playing: false        // wavy (true) or flat (false)
    property bool running: true         // the wave moves only while this is true, e.g. while visible
    property color color: "white"
    property color trackColor: "gray"
    property real lineWidth: 3
    property real amplitude: 3
    property real wavelength: 22
    property bool seekable: true
    signal seek(real v)
    implicitHeight: 20

    readonly property real shown: ma.pressed ? ma.live : Math.max(0, Math.min(1, value))
    readonly property real px: shown * width
    property real amp: playing ? amplitude : 0
    Behavior on amp { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    property real phase: 0
    Timer { interval: 33; repeat: true; running: w.running && w.playing && w.amplitude > 0; onTriggered: w.phase = (w.phase + 0.18) % (2 * Math.PI) }

    Rectangle {
        x: w.px + 5; width: Math.max(0, w.width - x); height: w.lineWidth; radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: w.trackColor
    }
    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: w.color; strokeWidth: w.lineWidth; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathPolyline {
                path: { const p = [], h = w.height / 2, k = 2 * Math.PI / w.wavelength;
                        for (let x = 0; x <= w.px; x += 2) p.push(Qt.point(x, h + w.amp * Math.sin(x * k - w.phase)));
                        return p; }
            }
        }
    }
    Rectangle {         // thumb: a small vertical pill
        width: w.lineWidth + 2; height: 14; radius: width / 2
        x: w.px - width / 2; anchors.verticalCenter: parent.verticalCenter
        color: w.color
        visible: w.value > 0 || ma.pressed
    }
    MouseArea {
        id: ma
        visible: w.seekable
        anchors.fill: parent; anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real live: 0
        function at(mx) { return Math.max(0, Math.min(1, (mx - 6) / w.width)); }
        onPressed: m => live = at(m.x)
        onPositionChanged: m => { if (pressed) live = at(m.x); }
        onReleased: w.seek(live)
    }
}
