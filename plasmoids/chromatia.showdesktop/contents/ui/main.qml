// Chromatia "Show desktop": a click minimizes all windows of the current desktop,
// a second click brings exactly those windows back in their old order.
// Activating a window yourself in between makes it forget the list.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"
    toolTipMainText: shown ? "Restore windows" : "Show desktop"
    toolTipSubText: ""

    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: true
        virtualDesktop: vd.currentDesktop
        filterByActivity: true
        activity: activityInfo.currentActivity
        onVirtualDesktopChanged: root.forget()
    }

    property var hidden: []          // windows we minimized (WinId)
    property string lastActive: ""
    property bool busy: false          // while we minimize/restore ourselves
    readonly property bool shown: hidden.length > 0

    function role(r, name) { return tasks.data(tasks.makeModelIndex(r), TaskManager.AbstractTasksModel[name]); }
    function winId(r) { const l = role(r, "WinIdList"); return (l && l.length > 0) ? String(l[0]) : ""; }
    function forget() { hidden = []; lastActive = ""; }

    function toggle() {
        busy = true; busyTimer.restart();
        if (shown) restore(); else minimizeAll();
    }
    function minimizeAll() {
        const ids = [];
        for (let r = 0; r < tasks.count; r++) {
            if (role(r, "IsMinimized") === true || role(r, "IsMinimizable") === false) continue;
            const id = winId(r);
            if (!id) continue;
            if (role(r, "IsActive") === true) lastActive = id;
            ids.push(id);
            tasks.requestToggleMinimized(tasks.makeModelIndex(r));
        }
        hidden = ids;
    }
    function restore() {
        const rows = [];
        for (let r = 0; r < tasks.count; r++) {
            if (hidden.indexOf(winId(r)) >= 0 && role(r, "IsMinimized") === true)
                rows.push({ r: r, z: role(r, "StackingOrder") || 0, id: winId(r) });
        }
        rows.sort((a, b) => a.z - b.z);              // unterstes zuerst, oberstes zuletzt
        let act = -1;
        rows.forEach(o => { tasks.requestToggleMinimized(tasks.makeModelIndex(o.r)); if (o.id === lastActive) act = o.r; });
        if (act >= 0) tasks.requestActivate(tasks.makeModelIndex(act));
        forget();
    }
    Timer { id: busyTimer; interval: 800; onTriggered: root.busy = false }

    // opened or activated a window yourself? Then the old state no longer applies.
    Repeater {
        model: tasks
        delegate: Item {
            readonly property bool act: model.IsActive === true && model.IsMinimized !== true
            onActChanged: if (act && !root.busy && root.shown) root.forget()
        }
    }

    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)

    // bigger button: a pill with the dog's head, fills the bar height
    fullRepresentation: Item {
        id: rep
        readonly property int bw: 36       // space in the bar
        readonly property int ext: 13      // how far the pill reaches into the gap between the islands
        Layout.preferredWidth: bw
        Layout.minimumWidth: bw
        Layout.maximumWidth: bw
        Layout.fillHeight: true

        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: rep.bw + 2 * rep.ext
            height: Math.min(rep.height, 32)
            radius: height / 2
            color: root.shown ? Qt.hsla(root.hue, 0.45, 0.42, 1)
                 : (area.containsMouse ? Qt.hsla(root.hue, 0.22, 0.27, 1) : Qt.hsla(root.hue, 0.20, 0.22, 1))
            Behavior on color { ColorAnimation { duration: 160 } }
            scale: area.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

            Image {
                anchors.centerIn: parent
                width: 26; height: 26
                sourceSize.width: 52; sourceSize.height: 52
                source: Qt.resolvedUrl("../images/" + (root.shown ? "dog-asleep.svg" : "dog-awake.svg"))
                smooth: true
                scale: area.containsMouse ? 1.1 : 1.0
                rotation: area.containsMouse && !root.shown ? -8 : 0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            }
        }
        MouseArea {
            id: area
            anchors.fill: pill
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }
}
