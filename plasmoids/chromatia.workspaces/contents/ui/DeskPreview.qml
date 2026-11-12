// Mini-Ansicht einer Arbeitsfläche: Hintergrundbild plus Live-Bilder der Fenster an ihrer Position.
import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire

PlasmaCore.Dialog {
    id: dlg

    required property var pills          // Hauptobjekt (Farben, Umschalten)
    property Item target: null
    property var desktopId: ""
    property int number: 0
    property real reveal: 0
    readonly property bool hovered: hover.hovered
    property bool ownerHovered: false     // vom Dock bzw. den Pillen gesetzt
    signal left()

    // Geometrie des eigenen Bildschirms (logische Pixel)
    property rect screenGeo: Qt.rect(0, 0, 1920, 1080)
    readonly property real miniW: 360
    readonly property real sc: miniW / Math.max(1, screenGeo.width)
    readonly property real miniH: Math.round(screenGeo.height * sc)

    visualParent: target
    location: PlasmaCore.Types.BottomEdge
    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: false
    visible: false

    function show(item, id, num, geo) {
        target = item; desktopId = id; number = num; screenGeo = geo;
        visible = true;
        anim.stop(); anim.to = 1; anim.duration = 380; anim.easing.type = Easing.OutBack; anim.easing.overshoot = 1.15; anim.start();
    }
    function hide() {
        anim.stop(); anim.to = 0; anim.duration = 160; anim.easing.type = Easing.InCubic; anim.start();
    }

    mainItem: Item {
        id: body
        width: dlg.miniW + 28
        height: dlg.miniH + 56
        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) dlg.left()
        }
        Timer {
            interval: 500; repeat: true
            running: dlg.visible && dlg.reveal > 0.9
            onTriggered: if (!hover.hovered && !dlg.ownerHovered) dlg.hide()
        }

        NumberAnimation {
            id: anim; target: dlg; property: "reveal"
            onFinished: if (dlg.reveal <= 0.001) dlg.visible = false
        }

        TaskManager.ActivityInfo { id: activityInfo }
        TaskManager.TasksModel {
            id: wins
            groupMode: TaskManager.TasksModel.GroupDisabled
            sortMode: TaskManager.TasksModel.SortManual
            filterByVirtualDesktop: true
            virtualDesktop: dlg.desktopId
            filterByScreen: true
            screenGeometry: dlg.screenGeo
            filterByActivity: true
            activity: activityInfo.currentActivity
        }

        Item {
            anchors.fill: parent
            opacity: Math.max(0, Math.min(1, dlg.reveal * 2.2))
            transform: [
                Translate { y: (1 - dlg.reveal) * 34 },
                Scale { origin.x: body.width / 2; origin.y: body.height; xScale: 0.82 + 0.18 * dlg.reveal; yScale: xScale }
            ]

            Rectangle {
                anchors.fill: parent
                radius: 22
                color: dlg.pills.cBase
                border.width: 1
                border.color: Qt.alpha(dlg.pills.accent, 0.35)
            }
            Text {
                x: 16; y: 12
                text: "Workspace " + dlg.number
                color: dlg.pills.cText
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16; y: 13
                text: wins.count === 0 ? "empty" : (wins.count + " windows")
                color: dlg.pills.cDim
                font.pixelSize: 12
            }

            // Mini-Bildschirm
            Rectangle {
                id: mini
                x: 14; y: 40
                width: dlg.miniW; height: dlg.miniH
                radius: 12
                color: dlg.pills.cCard
                clip: true

                Image {
                    anchors.fill: parent
                    source: dlg.pills.wallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 720
                    opacity: 0.9
                }

                Repeater {
                    model: wins
                    delegate: Rectangle {
                        id: w
                        visible: model.IsMinimized !== true
                        readonly property rect g: model.Geometry
                        readonly property string winId: (model.WinIdList && model.WinIdList.length > 0) ? model.WinIdList[0] : ""
                        x: (g.x - dlg.screenGeo.x) * dlg.sc
                        y: (g.y - dlg.screenGeo.y) * dlg.sc
                        width: Math.max(8, g.width * dlg.sc)
                        height: Math.max(8, g.height * dlg.sc)
                        z: model.StackingOrder !== undefined ? model.StackingOrder : index   // echte Stapelreihenfolge
                        radius: 4
                        color: dlg.pills.cCard2
                        border.width: model.IsActive === true ? 2 : 1
                        border.color: model.IsActive === true ? dlg.pills.accent : Qt.alpha("black", 0.4)
                        clip: true

                        TaskManager.ScreencastingRequest { id: cast; uuid: w.winId }
                        PipeWire.PipeWireSourceItem {
                            anchors.fill: parent
                            anchors.margins: 1
                            nodeId: cast.nodeId
                            visible: nodeId > 0
                            enabled: visible
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.min(28, parent.width * 0.5); height: width
                            source: model.decoration
                            visible: cast.nodeId === 0
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { wins.requestActivate(wins.makeModelIndex(index)); dlg.hide(); }
                        }
                    }
                }

                // Klick auf freie Fläche: zur Arbeitsfläche wechseln
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { dlg.pills.switchTo(dlg.number); dlg.hide(); }
                }
            }
        }
    }
}
