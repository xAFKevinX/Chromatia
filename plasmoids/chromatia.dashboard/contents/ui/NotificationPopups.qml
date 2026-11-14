// Chromatia notification popups: slide in at the top right, slide out after their time.
// KDE's own popups are hidden by the KWin script "chromatia-notifications" while these are on.
// The popups keep their own list, so KDE's (hidden) popup timer can't cut them short.
import QtQuick
import QtQuick.Shapes
import org.kde.plasma.core as PlasmaCore
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager

PlasmaCore.Dialog {
    id: win

    required property var dash
    required property var source             // NotificationManager.Notifications (the history)
    property rect screenRect: Qt.rect(0, 0, 1920, 1080)
    property bool active: true
    property int seconds: 8                  // Settings → Notifications
    property bool hideInFullscreen: true
    property int fullscreenFocused: 0
    readonly property int cardWidth: 360
    // grows out of the frame: attached to the top and right frame edges, like the dashboard
    readonly property int frameTop: 12
    readonly property int frameRight: 12
    readonly property int inv: 24             // concave corners where it meets the frame
    readonly property int rad: 28             // rounded outer corner
    readonly property int pad: 12
    readonly property int bodyW: cardWidth + 2 * pad
    readonly property int targetH: shown.count > 0 ? list.implicitHeight + 2 * pad : 0
    property real bodyH: targetH
    Behavior on bodyH { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    // no popups while do-not-disturb is on or a fullscreen app (game, video) is focused
    readonly property bool suppressed: NotificationManager.Server.inhibited || (hideInFullscreen && fullscreenFocused > 0)

    title: "chromatia-notifications"          // the KWin script leaves windows with this title alone
    type: PlasmaCore.Dialog.Notification
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    backgroundHints: PlasmaCore.Dialog.NoBackground
    location: PlasmaCore.Types.Floating
    hideOnWindowDeactivate: false
    visible: active && !suppressed && (shown.count > 0 || bodyH > 1)
    x: screenRect.x + screenRect.width - frameRight - (bodyW + inv)
    y: screenRect.y + frameTop

    function role(i, r) { return source.data(source.index(i, 0), r); }
    function addRow(i) {
        const R = NotificationManager.Notifications;
        if (role(i, R.TypeRole) !== R.NotificationType) return;
        const nid = role(i, R.IdRole);
        for (let k = 0; k < shown.count; k++) if (shown.get(k).nid === nid) return;
        const created = role(i, R.CreatedRole);
        if (!created || Date.now() - created.getTime() > 15000) return;   // only new ones
        if (!active || suppressed) return;
        shown.insert(0, {
            nid: nid,
            gone: false,
            app: role(i, R.ApplicationNameRole) || "",
            summary: role(i, R.SummaryRole) || "",
            body: role(i, R.BodyRole) || "",
            icon: role(i, R.IconNameRole) || role(i, R.ApplicationIconNameRole) || "",
            created: created,
            actions: JSON.stringify(Array.from(role(i, R.ActionNamesRole) || [])),
            labels: JSON.stringify(Array.from(role(i, R.ActionLabelsRole) || [])),
            hasDefault: role(i, R.HasDefaultActionRole) === true,
            critical: role(i, R.UrgencyRole) === R.CriticalUrgency,
            timeout: role(i, R.TimeoutRole) || 0
        });
        while (shown.count > 4) shown.remove(shown.count - 1);
    }

    mainItem: Item {
        id: body
        width: win.bodyW + win.inv
        height: Math.max(win.targetH, win.bodyH) + win.inv

        // the frame extension (same color as the frame, seamless)
        Shape {
            anchors.fill: parent
            visible: win.bodyH > 1
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: win.dash.cBase
                strokeColor: "transparent"
                PathSvg {
                    readonly property real w: win.bodyW + win.inv
                    readonly property real bh: Math.max(1, win.bodyH)
                    readonly property real ri: Math.min(win.inv, bh)
                    readonly property real ro: Math.min(win.rad, bh / 2)
                    path: `M0,0 L${w},0 L${w},${bh + ri} A${ri},${ri} 0 0 0 ${w - ri},${bh} L${win.inv + ro},${bh} `
                        + `A${ro},${ro} 0 0 1 ${win.inv},${bh - ro} L${win.inv},${ri} A${ri},${ri} 0 0 0 0,0 Z`
                }
            }
        }

        ListModel { id: shown }
        Timer {          // drops cards once they slid out
            id: dropper
            interval: 320
            onTriggered: { for (let k = shown.count - 1; k >= 0; k--) if (shown.get(k).gone) shown.remove(k); }
        }
        Connections {    // new rows in the history → popups (newest first, so walk last → first)
            target: win.source
            function onRowsInserted(parent, first, last) { for (let i = last; i >= first; i--) win.addRow(i); }
            // the app withdrew it (e.g. Discord when a call is answered or ends) → slide out too
            function onRowsAboutToBeRemoved(parent, first, last) {
                for (let i = first; i <= last; i++)
                    for (let k = 0; k < shown.count; k++)
                        if (shown.get(k).nid === win.role(i, NotificationManager.Notifications.IdRole)) cards.itemAt(k).leave("hide");
            }
        }
        TaskManager.TasksModel { id: tasks; groupMode: TaskManager.TasksModel.GroupDisabled }
        Repeater {
            model: tasks
            delegate: Item {
                readonly property bool fs: model.IsActive === true && model.IsFullScreen === true
                onFsChanged: win.fullscreenFocused += fs ? 1 : -1
                Component.onCompleted: if (fs) win.fullscreenFocused += 1
                Component.onDestruction: if (fs) win.fullscreenFocused -= 1
            }
        }

        Item {           // cards live inside the extension, clipped while it grows/shrinks
            x: win.inv + win.pad
            y: win.pad
            width: win.cardWidth
            height: Math.max(0, win.bodyH - 2 * win.pad)
            clip: true

        Column {
            id: list
            width: win.cardWidth
            spacing: 8

            Repeater {
                id: cards
                model: shown
                delegate: Item {
                    id: slot
                    required property int index
                    required property real nid
                    required property string app
                    required property string summary
                    required property string body
                    required property string icon
                    required property var created
                    required property string actions
                    required property string labels
                    required property bool hasDefault
                    required property bool critical
                    required property int timeout
                    width: win.cardWidth
                    height: pc.height
                    property bool entered: false
                    property bool leaving: false
                    // slide out first, then drop the card (close = also remove it from the history)
                    function leave(how) {
                        if (leaving) return;
                        leaving = true;
                        shown.setProperty(index, "gone", true);
                        dropper.restart();
                        if (how === "close") { const ix = pc.idx(); if (ix.valid) win.source.close(ix); }
                    }
                    Component.onCompleted: Qt.callLater(() => entered = true)

                    NotificationCard {
                        id: pc
                        dash: win.dash
                        nmodel: win.source
                        nid: slot.nid
                        row: -1
                        popup: true
                        width: win.cardWidth
                        y: (slot.entered && !slot.leaving) ? 0 : -12
                        opacity: (slot.entered && !slot.leaving) ? 1 : 0
                        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                        appName: slot.app
                        summary: slot.summary
                        body: slot.body
                        iconSource: slot.icon
                        created: slot.created
                        actionNames: JSON.parse(slot.actions)
                        actionLabels: JSON.parse(slot.labels)
                        hasDefaultAction: slot.hasDefault
                        onActivated: slot.leave("hide")
                        onCloseClicked: slot.leave("close")
                        onActionTriggered: slot.leave("hide")

                        // the chosen time (default 8 s), longer if the app asks for it; critical ones stay
                        readonly property int timeoutMs: slot.critical ? 0 : Math.max(win.seconds * 1000, slot.timeout > 0 ? slot.timeout : 0)
                        Timer {
                            interval: Math.max(1500, pc.timeoutMs)
                            running: pc.timeoutMs > 0 && !pc.hovered && win.visible && !slot.leaving
                            onTriggered: slot.leave("hide")
                        }
                    }
                }
            }
        }
        }
    }
}
