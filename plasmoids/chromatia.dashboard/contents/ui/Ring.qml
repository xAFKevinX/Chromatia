// Ringanzeige (0–100 %) mit Wert in der Mitte und Beschriftung darunter.
import QtQuick
import QtQuick.Shapes

Item {
    id: ring

    property real value: 0            // 0..100
    property string label: ""
    property string valueText: Math.round(value) + " %"
    property color trackColor: "#33ffffff"
    property color barColor: "white"
    property color textColor: "white"
    property real thickness: 8

    implicitWidth: 104
    implicitHeight: 124

    readonly property real size: Math.min(width, height - labelText.height - 6)
    property real shown: Math.max(0, Math.min(100, value))

    Behavior on shown { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    Item {
        id: dial
        width: ring.size
        height: ring.size
        anchors.horizontalCenter: parent.horizontalCenter

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: ring.trackColor
                strokeWidth: ring.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: dial.width / 2; centerY: dial.height / 2
                    radiusX: dial.width / 2 - ring.thickness; radiusY: radiusX
                    startAngle: 135; sweepAngle: 270
                }
            }
            ShapePath {
                strokeColor: ring.barColor
                strokeWidth: ring.thickness
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: dial.width / 2; centerY: dial.height / 2
                    radiusX: dial.width / 2 - ring.thickness; radiusY: radiusX
                    startAngle: 135; sweepAngle: Math.max(0.1, 270 * ring.shown / 100)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: ring.valueText
            color: ring.textColor
            font.pixelSize: Math.round(ring.size * 0.2)
            font.bold: true
        }
    }

    Text {
        id: labelText
        anchors.top: dial.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: ring.label
        color: ring.textColor
        opacity: 0.75
        font.pixelSize: 12
    }
}
