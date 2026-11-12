// Chromatia Hintergrund-Panel – gleitet vom linken Bildschirmrand heraus.
//
// Sitzt in einer dünnen Leiste links, die optisch den linken Rahmen bildet. Fährt die
// Maus in der Mitte an den linken Rand, gleitet eine Bildergalerie heraus (Ordner
// ~/Bilder/Hintergründe). Ein Klick setzt das Bild auf allen Bildschirmen. Rahmen und
// Farben passen sich danach automatisch an (Dienst rahmen-hintergrund).

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.dbus
import org.kde.plasma.plasma5support as P5Support
import QtCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ---- Farben (wie Dashboard, Leiste, Rahmen) ----
    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cBase: Qt.hsla(hue, 0.25, 0.075, 1)
    readonly property color cCard: Qt.hsla(hue, 0.20, 0.14, 1)
    readonly property color cCard2: Qt.hsla(hue, 0.22, 0.22, 1)
    readonly property color cText: Qt.hsla(hue, 0.55, 0.90, 1)
    readonly property color cDim: Qt.hsla(hue, 0.25, 0.68, 1)

    // ---- Maße ----
    readonly property int fullW: 380         // ausgefahrene Breite (ohne gewölbte Ecken)
    readonly property int bodyH: 660         // Höhe des Panels
    readonly property int inv: 24            // gewölbte Ecken am Rahmen (oben/unten links)
    readonly property int rad: 28            // runde Ecken rechts
    readonly property int triggerH: 520      // Auslösebereich am linken Rand

    property real reveal: 0

    readonly property string script: "\"$HOME/.local/bin/chromatia-sync\""
    readonly property string thumbDir: String(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)).replace("file://", "") + "/chromatia/thumbs"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.indexOf(" --thumbs") >= 0) root.thumbRev++;   // neue Vorschauen da: neu laden
        }
    }
    property int thumbRev: 0
    function shq(t) { return "'" + t.replace(/'/g, "'\\''") + "'"; }

    // Bild setzen: das Skript rahmt es, bestimmt die Akzentfarbe und setzt es genau einmal
    function applyWallpaper(url) {
        Plasmoid.configuration.current = url.toString();
        const path = decodeURIComponent(url.toString().replace("file://", ""));
        runner.connectSource(root.script + " --set " + shq(path));
    }
    // Wallpaper folder: from the widget settings, default ~/Pictures/Wallpapers
    readonly property string folderUrl: Plasmoid.configuration.folder !== "" ? Plasmoid.configuration.folder
        : (String(StandardPaths.writableLocation(StandardPaths.PicturesLocation)) + "/Wallpapers")
    function refreshThumbs() {
        runner.connectSource(root.script + " --thumbs " + shq(decodeURIComponent(folderUrl.replace("file://", ""))));
    }

    fullRepresentation: Item {
        id: rep
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: root.triggerH

        MouseArea {
            id: trigger
            width: parent.width
            height: root.triggerH
            anchors.centerIn: parent
            hoverEnabled: true
            onEntered: rep.open()
            onExited: closeTimer.restart()
        }

        function open() {
            closeTimer.stop();
            if (!drawer.visible) root.refreshThumbs();
            drawer.visible = true;
            anim.stop();
            anim.to = 1; anim.duration = 340; anim.easing.type = Easing.OutQuint;
            anim.start();
        }
        function close() {
            anim.stop();
            anim.to = 0; anim.duration = 220; anim.easing.type = Easing.InCubic;
            anim.start();
        }

        NumberAnimation {
            id: anim
            target: root
            property: "reveal"
            onFinished: if (root.reveal <= 0.001) drawer.visible = false
        }

        Timer {
            id: closeTimer
            interval: 380
            onTriggered: {
                if (trigger.containsMouse || bodyHover.hovered) return;
                rep.close();
            }
        }

        PlasmaCore.Dialog {
            id: drawer
            visualParent: trigger
            location: PlasmaCore.Types.LeftEdge
            type: PlasmaCore.Dialog.Normal
            flags: Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: false
            visible: false

            mainItem: Item {
                id: body
                width: root.fullW
                height: root.bodyH + 2 * root.inv

                HoverHandler {
                    id: bodyHover
                    onHoveredChanged: if (!hovered) closeTimer.restart(); else closeTimer.stop()
                }

                readonly property real bw: Math.max(root.rad + 2, root.fullW * root.reveal)
                readonly property real bh: height

                // Form: links mit gewölbten Ecken am Rahmen, rechts rund
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: root.cBase
                        strokeColor: "transparent"
                        PathSvg {
                            readonly property real w: body.bw
                            readonly property real h: body.bh
                            readonly property real ri: root.inv
                            readonly property real ro: Math.min(root.rad, body.bw / 2)
                            path: `M0,0 A${ri},${ri} 0 0 0 ${ri},${ri} L${w - ro},${ri} `
                                + `A${ro},${ro} 0 0 1 ${w},${ri + ro} L${w},${h - ri - ro} `
                                + `A${ro},${ro} 0 0 1 ${w - ro},${h - ri} L${ri},${h - ri} `
                                + `A${ri},${ri} 0 0 0 0,${h} Z`
                        }
                    }
                }

                // Inhalt
                Item {
                    x: 0
                    y: root.inv
                    width: body.bw
                    height: root.bodyH
                    clip: true

                    Item {
                        id: content
                        width: root.fullW
                        height: root.bodyH
                        x: -(1 - root.reveal) * 40
                        opacity: Math.min(1, root.reveal * 1.8)

                        Text {
                            id: title
                            x: 22; y: 16
                            text: "Wallpapers"
                            color: root.cText
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            anchors.left: title.right
                            anchors.leftMargin: 8
                            anchors.baseline: title.baseline
                            text: folderModel.count + " wallpapers"
                            color: root.cDim
                            font.pixelSize: 12
                        }

                        FolderListModel {
                            id: folderModel
                            folder: root.folderUrl
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp",
                                          "*.PNG", "*.JPG", "*.JPEG", "*.WEBP",
                                          "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.MP4", "*.WEBM"]
                            showDirs: false
                            sortField: FolderListModel.Name
                        }

                        GridView {
                            id: grid
                            anchors.top: title.bottom
                            anchors.topMargin: 14
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 16
                            anchors.rightMargin: 10
                            anchors.bottomMargin: 12
                            clip: true
                            model: folderModel
                            cellWidth: Math.floor(width / 2)
                            cellHeight: Math.round(cellWidth * 0.62)
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: 1600
                            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                                policy: QQC2.ScrollBar.AsNeeded
                                width: 8
                                background: Item {}
                                contentItem: Rectangle {
                                    implicitWidth: 5
                                    radius: 3
                                    color: root.cCard2
                                    opacity: parent.active ? 1 : 0.6
                                }
                            }

                            delegate: Item {
                                width: grid.cellWidth
                                height: grid.cellHeight
                                readonly property bool isCurrent: Plasmoid.configuration.current === fileUrl.toString()

                                Rectangle {
                                    id: frame
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    radius: 14
                                    color: isCurrent ? root.accent : (thumbMouse.containsMouse ? root.cCard2 : root.cCard)
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Kirigami.ShadowedImage {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: 11
                                        color: root.cCard
                                        // Vorschau aus dem Cache; fehlt sie noch, wird nach --thumbs neu geladen.
                                        // Bilder dürfen solange direkt gezeigt werden, Videos nicht (das kann Image nicht).
                                        readonly property bool isVid: /\.(mp4|webm|mkv|mov|m4v)$/i.test(fileName)
                                        property bool fallback: false
                                        readonly property int rev: root.thumbRev
                                        onRevChanged: fallback = false
                                        source: (fallback && !isVid) ? fileUrl
                                              : ("file://" + root.thumbDir + "/" + fileName + ".jpg?v=" + rev)
                                        onStatusChanged: if (status === Image.Error && !fallback) fallback = true
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 360
                                        sourceSize.height: 200
                                        scale: thumbMouse.containsMouse ? 1.0 : 0.98
                                        Behavior on scale { NumberAnimation { duration: 150 } }
                                    }
                                    // Kennzeichen für Video-Hintergründe
                                    Rectangle {
                                        visible: /\.(mp4|webm|mkv|mov|m4v)$/i.test(fileName)
                                        anchors.right: parent.right; anchors.bottom: parent.bottom
                                        anchors.margins: 9
                                        width: 24; height: 24; radius: 12
                                        color: Qt.alpha(root.cBase, 0.85)
                                        Kirigami.Icon { anchors.centerIn: parent; width: 12; height: 12; source: "media-playback-start-symbolic"; isMask: true; color: root.cText }
                                    }

                                    MouseArea {
                                        id: thumbMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyWallpaper(fileUrl)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: folderModel.count === 0
                            anchors.centerIn: grid
                            width: grid.width - 20
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: "Put images or videos into\n~/Pictures/Wallpapers"
                            color: root.cDim
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
