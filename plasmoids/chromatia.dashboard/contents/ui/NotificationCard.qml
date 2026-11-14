// One notification, used by the popups (top right) and the history page in the dashboard.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Rectangle {
    id: card

    required property var dash          // dashboard root: colors
    required property var nmodel        // NotificationManager.Notifications the row belongs to
    required property int row
    property string appName
    property string summary
    property string body
    property var iconSource
    property var created
    property var actionNames: []
    property var actionLabels: []
    property bool hasDefaultAction: false
    property bool popup: false          // popups: bigger shadow, slide animation lives in the ListView
    readonly property bool hovered: hover.hovered
    signal activated()
    signal closeClicked()
    signal actionTriggered()

    property int nid: -1                // popups: notification id (rows move, ids don't)
    function idx() {
        if (nid < 0) return nmodel.index(row, 0);
        for (let i = 0; i < nmodel.count; i++) {
            const ix = nmodel.index(i, 0);
            if (nmodel.data(ix, NotificationManager.Notifications.IdRole) === nid) return ix;
        }
        return nmodel.index(-1, 0);
    }
    function ago(d) {
        if (!d) return "";
        const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + " min ago";
        if (s < 86400) return Math.floor(s / 3600) + " h ago";
        return Qt.locale("en_US").toString(d, "d MMM");
    }

    width: parent ? parent.width : 380
    implicitHeight: content.implicitHeight + 24
    height: implicitHeight
    radius: 18
    color: hover.hovered ? dash.cCard2 : dash.cCard
    border.width: 0
    border.color: Qt.alpha(dash.accent, 0.35)
    Behavior on color { ColorAnimation { duration: 140 } }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        cursorShape: card.hasDefaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (card.hasDefaultAction) card.nmodel.invokeDefaultAction(card.idx());
            card.activated();
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Kirigami.Icon {
                source: card.iconSource || "preferences-desktop-notification-bell"
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }
            Text {
                text: card.appName
                color: card.dash.cDim
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: card.ago(card.created)
                color: card.dash.cDim
                font.pixelSize: 11
            }
            // close
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: 10
                color: closeHover.hovered ? "#e5484d" : "transparent"
                opacity: card.hovered ? 1 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Kirigami.Icon { anchors.centerIn: parent; width: 12; height: 12; source: "window-close-symbolic"; isMask: true; color: card.dash.cText }
                HoverHandler { id: closeHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.popup ? card.closeClicked() : card.nmodel.close(card.idx()) }
            }
        }
        Text {
            visible: text !== ""
            text: card.summary
            color: card.dash.cText
            font.pixelSize: 14
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            visible: text !== ""
            text: card.body
            textFormat: Text.StyledText
            color: card.dash.cText
            opacity: 0.85
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 3 : 4
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Row {
            visible: card.actionNames.filter(a => a !== "default").length > 0
            spacing: 6
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            Layout.topMargin: 2
            Repeater {
                model: card.actionNames.length
                Rectangle {
                    readonly property string actionId: card.actionNames[index]
                    visible: actionId !== "default"
                    width: lbl.implicitWidth + 22
                    height: 26
                    radius: 13
                    color: aHover.hovered ? card.dash.accent : Qt.alpha(card.dash.accent, 0.35)
                    Text { id: lbl; anchors.centerIn: parent; text: card.actionLabels[index] || ""; color: "white"; font.pixelSize: 12 }
                    HoverHandler { id: aHover }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { card.nmodel.invokeAction(card.idx(), parent.actionId); card.actionTriggered(); } }
                }
            }
        }
    }
}
