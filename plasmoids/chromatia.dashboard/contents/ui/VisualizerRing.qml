// Round audio visualizer: bars radiate outwards around a round picture.
import QtQuick

Item {
    id: vr

    property var values: []           // 0..1 per bar
    property real innerRadius: 80     // distance from the center where the bars start
    property real maxLength: 34       // maximum bar length
    property real minLength: 3
    property real barWidth: 4
    property color color: "white"
    property int count: 48

    Repeater {
        model: vr.count
        Item {
            // rotate around the center of the ring
            x: vr.width / 2
            y: vr.height / 2
            rotation: index * 360 / vr.count

            Rectangle {
                readonly property real v: (vr.values && vr.values.length > index) ? vr.values[index] : 0
                width: vr.barWidth
                height: vr.minLength + v * vr.maxLength
                radius: width / 2
                x: -width / 2
                y: -vr.innerRadius - height
                color: vr.color
                opacity: 0.55 + 0.45 * v
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
}
