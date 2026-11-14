// Chromatia wallpaper gallery – slides out of the left screen edge.
//
// Lives in a thin panel on the left that forms the left part of the frame. When the
// mouse reaches the middle of the left edge, a gallery slides out (folder from the
// widget settings, otherwise ~/Pictures/Wallpapers). A click sets the wallpaper on all
// screens, then chromatia-sync recolors everything to match.

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import Qt.labs.folderlistmodel
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import QtCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ---- Colors (like dashboard, bar, frame) ----
    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cBase: Qt.hsla(hue, 0.25, 0.075, 1)
    readonly property color cCard: Qt.hsla(hue, 0.20, 0.14, 1)
    readonly property color cCard2: Qt.hsla(hue, 0.22, 0.22, 1)
    readonly property color cText: Qt.hsla(hue, 0.55, 0.90, 1)
    readonly property color cDim: Qt.hsla(hue, 0.25, 0.68, 1)

    // ---- Sizes ----
    readonly property int fullW: 380         // width when open (without the curved corners)
    readonly property int bodyH: 660         // height of the gallery
    readonly property int inv: 24            // curved corners at the frame (top/bottom left)
    readonly property int rad: 28            // round corners on the right
    readonly property int triggerH: 520      // trigger area at the left edge

    property real reveal: 0

    readonly property string script: "\"$HOME/.local/bin/chromatia-sync\""
    readonly property string thumbDir: String(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)).replace("file://", "") + "/chromatia/thumbs"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.indexOf(" --thumbs") >= 0) root.thumbRev++;   // new previews ready: reload
        }
    }
    property int thumbRev: 0
    function shq(t) { return "'" + t.replace(/'/g, "'\\''") + "'"; }

    // set a wallpaper: chromatia-sync picks the accent color and sets it exactly once
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

                // shape: curved corners at the frame on the left, round on the right
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

                // content
                Item {
                    x: 0
                    y: root.inv
                    width: body.bw
                    height: root.bodyH
                    clip: true

                    Item {
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
                            text: folderModel.count + (folderModel.count === 1 ? " wallpaper" : " wallpapers")
                            color: root.cDim
                            font.pixelSize: 12
                        }
                        // open the wallpaper folder in the file manager
                        Rectangle {
                            width: 32; height: 32
                            radius: width / 2
                            x: root.fullW - width - 16
                            anchors.verticalCenter: title.verticalCenter
                            color: folderMouse.containsMouse ? root.cCard2 : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 18; height: 18
                                source: "folder-open-symbolic"
                                isMask: true
                                color: folderMouse.containsMouse ? root.accent : root.cText
                            }
                            MouseArea {
                                id: folderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(root.folderUrl)
                            }
                            QQC2.ToolTip.text: "Open the wallpaper folder"
                            QQC2.ToolTip.visible: folderMouse.containsMouse
                            QQC2.ToolTip.delay: 600
                        }

                        FolderListModel {
                            id: folderModel
                            folder: root.folderUrl
                            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v"]
                            caseSensitive: false
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
                                readonly property bool isVid: /\.(mp4|webm|mkv|mov|m4v)$/i.test(fileName)

                                Rectangle {
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
                                        // preview from the cache; if it is missing, it reloads after --thumbs.
                                        // Until then images are shown directly, videos are not (Image can't show them).
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
                                    // badge for video wallpapers
                                    Rectangle {
                                        visible: isVid
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
