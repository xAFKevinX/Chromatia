// Chromatia media island: cover, title, wavy progress and controls of the current player
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

Rectangle {
    id: island
    required property QtObject pal
    property real s: 1
    property bool wave: true
    property bool active: true              // the wave and the position timer only run while shown

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0
    Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: island.active && !!island.player; onTriggered: island.player.updatePosition() }
    function fmt(us) { const t = Math.max(0, Math.floor(us / 1e6)); return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0"); }

    visible: !!player
    enabled: !!player && player.canControl
    implicitWidth: Math.round(560 * s)
    implicitHeight: Math.round(76 * s)
    radius: height / 2
    color: Qt.alpha(pal.base, 0.85)
    border.width: 1
    border.color: Qt.alpha(pal.card2, 0.9)

    Kirigami.ShadowedImage {
        id: art
        x: Math.round(10 * island.s)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - Math.round(20 * island.s); height: width
        radius: width / 2
        color: island.pal.card2
        source: island.player ? island.player.artUrl : ""
        fillMode: Image.PreserveAspectCrop
        Image {
            visible: !island.player || !island.player.artUrl
            anchors.centerIn: parent
            source: Qt.resolvedUrl("images/cat.svg")
            width: parent.width * 0.62; height: width * 0.86
            sourceSize.width: 112
        }
    }
    Column {
        anchors.left: art.right; anchors.leftMargin: Math.round(14 * island.s)
        anchors.right: buttons.left; anchors.rightMargin: Math.round(14 * island.s)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(1 * island.s)
        Text {
            width: parent.width
            text: island.player && island.player.track ? island.player.track : ""
            color: island.pal.text
            font.pixelSize: Math.round(15 * island.s); font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: island.player ? island.player.artist : ""
            visible: text !== ""
            color: island.pal.dim
            font.pixelSize: Math.round(12 * island.s)
            elide: Text.ElideRight
        }
        Item {
            width: parent.width; height: Math.round(20 * island.s)
            visible: !!island.player && island.player.length > 0
            Text { id: pos; anchors.verticalCenter: parent.verticalCenter; text: island.fmt(island.player ? island.player.position : 0); color: island.pal.dim; font.pixelSize: Math.round(11 * island.s) }
            WaveProgress {
                anchors.left: pos.right; anchors.right: len.left; anchors.leftMargin: 6; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(18 * island.s)
                value: island.progress
                playing: island.playing
                running: island.active
                amplitude: island.wave ? 3 * island.s : 0
                lineWidth: Math.max(2, 3 * island.s)
                color: island.pal.accent
                trackColor: island.pal.card2
                seekable: false
            }
            Text { id: len; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: island.fmt(island.player ? island.player.length : 0); color: island.pal.dim; font.pixelSize: Math.round(11 * island.s) }
        }
    }
    Row {
        id: buttons
        anchors.right: parent.right; anchors.rightMargin: Math.round(14 * island.s)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(6 * island.s)
        MediaButton { icon: "media-skip-backward"; enabled: !!island.player && island.player.canGoPrevious; onClicked: island.player.Previous() }
        MediaButton { icon: island.playing ? "media-playback-pause" : "media-playback-start"; big: true; onClicked: island.player.PlayPause() }
        MediaButton { icon: "media-skip-forward"; enabled: !!island.player && island.player.canGoNext; onClicked: island.player.Next() }
    }

    component MediaButton: Rectangle {
        id: mb
        property string icon
        property bool big: false
        signal clicked()
        width: Math.round((big ? 44 : 34) * island.s); height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        opacity: enabled ? 1 : 0.4
        color: big ? island.pal.accent : (mbMouse.containsMouse ? island.pal.card2 : "transparent")
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(mb.width * 0.5); height: width
            source: mb.icon
            isMask: true
            color: mb.big ? "white" : island.pal.text
        }
        MouseArea {
            id: mbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }
}
