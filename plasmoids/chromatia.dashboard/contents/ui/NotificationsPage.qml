// Dashboard tab "Notifications": everything that came in, newest first.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Rectangle {
    id: page

    required property var dash
    required property var history        // NotificationManager.Notifications (history)

    radius: 20
    color: dash.cCard

    // header: count, do-not-disturb, clear all
    Text {
        id: head
        x: 16; y: 12
        text: page.history.count === 0 ? "No notifications" : (page.history.count + (page.history.count === 1 ? " notification" : " notifications"))
        color: page.dash.cText
        font.pixelSize: 15
        font.bold: true
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 8
        spacing: 8
        Rectangle {          // do not disturb (KDE's own switch)
            readonly property bool on: NotificationManager.Server.inhibited
            width: dndRow.implicitWidth + 22; height: 30; radius: 15
            color: on ? page.dash.accent : (dndHover.hovered ? page.dash.cCard2 : Qt.alpha(page.dash.cText, 0.08))
            Row {
                id: dndRow
                anchors.centerIn: parent
                spacing: 6
                Kirigami.Icon { width: 14; height: 14; source: "notifications-disabled-symbolic"; isMask: true; color: parent.parent.on ? "white" : page.dash.cText; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Do not disturb"; color: parent.parent.on ? "white" : page.dash.cText; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            HoverHandler { id: dndHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: page.dash.toggleDnd()
            }
        }
        Rectangle {          // clear all
            visible: page.history.count > 0
            width: clrText.implicitWidth + 22; height: 30; radius: 15
            color: clrHover.hovered ? page.dash.cCard2 : Qt.alpha(page.dash.cText, 0.08)
            Text { id: clrText; anchors.centerIn: parent; text: "Clear all"; color: page.dash.cText; font.pixelSize: 12 }
            HoverHandler { id: clrHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    for (let i = page.history.count - 1; i >= 0; i--) page.history.close(page.history.index(i, 0));
                }
            }
        }
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        clip: true
        spacing: 8
        model: page.history
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 200 } }
        displaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }

        delegate: NotificationCard {
            required property int index
            required property var model
            width: list.width - 6
            dash: page.dash
            nmodel: page.history
            row: index
            color: hovered ? page.dash.cCard2 : Qt.alpha(page.dash.cBase, 0.55)
            appName: model.applicationName || ""
            summary: model.summary || ""
            body: model.body || ""
            iconSource: model.image ? model.image : (model.iconName || model.applicationIconName || "")
            created: model.created
            actionNames: Array.from(model.actionNames || [])
            actionLabels: Array.from(model.actionLabels || [])
            hasDefaultAction: model.hasDefaultAction === true
        }

        Kirigami.Icon {
            visible: page.history.count === 0
            anchors.centerIn: parent
            width: 64; height: 64
            source: "preferences-desktop-notification-bell"
            opacity: 0.25
        }
    }
}
