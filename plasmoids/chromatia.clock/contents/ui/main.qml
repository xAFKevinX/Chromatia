// Chromatia Desktop-Uhr – große Digitaluhr mit Datum, Farben aus der Akzentfarbe.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cTime: Qt.hsla(hue, 0.55, 0.92, 1)
    readonly property color cSoft: Qt.hsla(hue, 0.55, 0.78, 1)
    readonly property color cDim: Qt.hsla(hue, 0.30, 0.80, 1)

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    fullRepresentation: Item {
        id: face
        Layout.preferredWidth: 430
        Layout.preferredHeight: 140
        Layout.minimumWidth: 300
        Layout.minimumHeight: 100

        readonly property real s: Math.min(width / 430, height / 140)

        Item {
            id: content
            anchors.fill: parent

            Row {
                anchors.centerIn: parent
                spacing: Math.round(18 * face.s)

                Row {
                    id: timeRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * face.s)
                    Text {
                        text: Qt.locale("en_US").toString(root.now, "hh")
                        color: root.cTime
                        font.pixelSize: Math.round(96 * face.s)
                        font.weight: Font.Black
                    }
                    Text {
                        text: ":"
                        color: root.accent
                        font.pixelSize: Math.round(96 * face.s)
                        font.weight: Font.Black
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -Math.round(6 * face.s)
                    }
                    Text {
                        text: Qt.locale("en_US").toString(root.now, "mm")
                        color: root.cTime
                        font.pixelSize: Math.round(96 * face.s)
                        font.weight: Font.Black
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(2, Math.round(4 * face.s))
                    height: Math.round(86 * face.s)
                    radius: width / 2
                    color: root.accent
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * face.s)
                    Text {
                        text: Qt.locale("en_US").toString(root.now, "MMMM").toUpperCase()
                        color: root.cSoft
                        font.pixelSize: Math.round(20 * face.s)
                        font.bold: true
                        font.letterSpacing: Math.round(4 * face.s)
                    }
                    Text {
                        text: Qt.locale("en_US").toString(root.now, "dd")
                        color: root.cTime
                        font.pixelSize: Math.round(44 * face.s)
                        font.weight: Font.Black
                    }
                    Text {
                        text: Qt.locale("en_US").toString(root.now, "dddd")
                        color: root.cDim
                        font.pixelSize: Math.round(18 * face.s)
                        font.letterSpacing: Math.round(1 * face.s)
                    }
                }
            }
        }

        // weicher Schatten für Lesbarkeit auf hellen Hintergründen
        MultiEffect {
            source: content
            anchors.fill: content
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.6
            shadowVerticalOffset: 2
            z: -1
        }
    }
}
