// Vorschaufenster eines Dock-Eintrags: Live-Bilder aller Fenster des Programms.
import QtQuick
import QtQml.Models
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire

PlasmaCore.Dialog {
    id: dlg

    required property var dock          // Hauptobjekt (Farben, Modell, Funktionen)
    property Item target: null          // Dock-Symbol, über dem die Vorschau steht
    property int row: -1                // Zeile im Fenstermodell
    property bool isGroup: false
    property real reveal: 0
    readonly property bool hovered: hover.hovered
    property bool ownerHovered: false     // vom Dock bzw. den Pillen gesetzt
    signal left()

    visualParent: target
    location: PlasmaCore.Types.BottomEdge
    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: false
    visible: false

    function show(item, r, group) {
        target = item; row = r; isGroup = group;
        visible = true;
        anim.stop(); anim.to = 1; anim.duration = 380; anim.easing.type = Easing.OutBack; anim.easing.overshoot = 1.15; anim.start();
    }
    function hide() {
        anim.stop(); anim.to = 0; anim.duration = 160; anim.easing.type = Easing.InCubic; anim.start();
    }
    mainItem: Item {
        id: body
        readonly property int n: dlg.isGroup ? Math.max(1, kids.count) : 1
        width: n * 240 + (n - 1) * 10 + 24
        height: 196
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
            onFinished: if (dlg.reveal <= 0.001) { dlg.visible = false; dlg.row = -1; }
        }

        DelegateModel {
            id: top
            model: dlg.dock.tasks
            delegate: Card {
                visible: index === dlg.row
                winId: (model.WinIdList && model.WinIdList.length > 0) ? model.WinIdList[0] : ""
                title: model.display || ""
                icon: model.decoration
                active: model.IsActive === true
                minimized: model.IsMinimized === true
                modelIndex: dlg.dock.tasks.makeModelIndex(index)
            }
        }
        DelegateModel {
            id: kids
            model: dlg.dock.tasks
            rootIndex: dlg.isGroup && dlg.row >= 0 ? dlg.dock.tasks.makeModelIndex(dlg.row) : dlg.dock.tasks.makeModelIndex(-1)
            delegate: Card {
                winId: (model.WinIdList && model.WinIdList.length > 0) ? model.WinIdList[0] : ""
                title: model.display || ""
                icon: model.decoration
                active: model.IsActive === true
                minimized: model.IsMinimized === true
                modelIndex: dlg.dock.tasks.makeModelIndex(dlg.row, index)
            }
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
                color: dlg.dock.cBase
                border.width: 1
                border.color: Qt.alpha(dlg.dock.accent, 0.35)
            }

            Row {
                anchors.centerIn: parent
                spacing: 10
                Repeater { model: dlg.isGroup ? kids : top }
            }
        }
    }

    component Card: Rectangle {
        id: card
        property string winId
        property string title
        property var icon
        property bool active
        property bool minimized
        property var modelIndex
        width: 240
        height: 172
        radius: 16
        color: active ? Qt.alpha(dlg.dock.accent, 0.30) : (cardHover.hovered ? dlg.dock.cCard2 : dlg.dock.cCard)
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: cardHover.hovered ? 1.03 : 1.0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        HoverHandler { id: cardHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { dlg.dock.tasks.requestActivate(card.modelIndex); dlg.hide(); }
        }

        Kirigami.Icon {
            id: ic
            x: 10; y: 9
            width: 18; height: 18
            source: card.icon
        }
        Text {
            anchors.left: ic.right; anchors.leftMargin: 7
            anchors.right: closeBtn.left; anchors.rightMargin: 6
            anchors.verticalCenter: ic.verticalCenter
            text: card.title
            color: dlg.dock.cText
            font.pixelSize: 12
            font.bold: card.active
            elide: Text.ElideRight
        }
        Rectangle {
            id: closeBtn
            width: 22; height: 22; radius: 11
            anchors.right: parent.right; anchors.rightMargin: 7
            anchors.verticalCenter: ic.verticalCenter
            color: closeHover.hovered ? "#e5484d" : "transparent"
            opacity: cardHover.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Kirigami.Icon { anchors.centerIn: parent; width: 14; height: 14; source: "window-close-symbolic"; isMask: true; color: dlg.dock.cText }
            HoverHandler { id: closeHover }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dlg.dock.tasks.requestClose(card.modelIndex) }
        }

        // Live-Bild des Fensters
        Rectangle {
            x: 8; y: 34
            width: parent.width - 16
            height: parent.height - 42
            radius: 10
            color: dlg.dock.cCard2
            clip: true

            TaskManager.ScreencastingRequest { id: cast; uuid: card.winId }
            PipeWire.PipeWireSourceItem {
                anchors.fill: parent
                nodeId: cast.nodeId
                visible: nodeId > 0
                enabled: visible
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 48; height: 48
                source: card.icon
                visible: cast.nodeId === 0
                opacity: 0.8
            }
            Rectangle {
                visible: card.minimized
                anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: minText.implicitWidth + 14; height: 18; radius: 9
                color: Qt.alpha(dlg.dock.cBase, 0.85)
                Text { id: minText; anchors.centerIn: parent; text: "minimized"; color: dlg.dock.cText; font.pixelSize: 11 }
            }
        }

    }
}
