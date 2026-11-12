// Ringförmiger Audio-Visualizer: Balken strahlen kreisförmig um ein rundes Bild nach außen.
import QtQuick

Item {
    id: vr

    property var values: []           // 0..1 je Balken
    property real innerRadius: 80     // Abstand vom Mittelpunkt, an dem die Balken beginnen
    property real maxLength: 34       // maximale Balkenlänge
    property real minLength: 3
    property real barWidth: 4
    property color color: "white"
    property int count: 48

    Repeater {
        model: vr.count
        Item {
            // Drehpunkt in der Mitte des Rings
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
