// Big Chromatia clock (same look as the desktop clock widget): hh:mm | MONTH / dd / weekday
import QtQuick
import QtQuick.Effects

Item {
    id: clock
    required property QtObject pal
    property real s: 1                      // size factor
    property Item shadow: Item {}           // WallpaperFader writes shadow.opacity
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clock.now = new Date() }
    function t(f) { return Qt.locale("en_US").toString(clock.now, f); }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(26 * clock.s)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(3 * clock.s)
            Text { text: clock.t("hh"); color: clock.pal.time; font.pixelSize: Math.round(140 * clock.s); font.weight: Font.Black }
            Text {
                text: ":"; color: clock.pal.glow
                font.pixelSize: Math.round(140 * clock.s); font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(9 * clock.s)
            }
            Text { text: clock.t("mm"); color: clock.pal.time; font.pixelSize: Math.round(140 * clock.s); font.weight: Font.Black }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, Math.round(6 * clock.s)); height: Math.round(124 * clock.s); radius: width / 2
            color: clock.pal.glow
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(3 * clock.s)
            Text { text: clock.t("MMMM").toUpperCase(); color: clock.pal.soft; font.pixelSize: Math.round(29 * clock.s); font.bold: true; font.letterSpacing: Math.round(6 * clock.s) }
            Text { text: clock.t("dd"); color: clock.pal.time; font.pixelSize: Math.round(64 * clock.s); font.weight: Font.Black }
            Text { text: clock.t("dddd"); color: clock.pal.dim; font.pixelSize: Math.round(26 * clock.s); font.letterSpacing: Math.round(1.5 * clock.s) }
        }
        layer.enabled: true
        layer.effect: MultiEffect {     // soft shadow so it stays readable on bright wallpapers
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.6
            shadowVerticalOffset: 2
        }
    }
}
