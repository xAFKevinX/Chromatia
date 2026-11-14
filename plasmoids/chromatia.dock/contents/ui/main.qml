// Chromatia dock – apps and open windows, Caelestia style.
//
// Left click: start / raise / minimize (several windows: cycle through them)
// Middle click: new window.  Right click: menu (new window, pin, close).
// Hover: live preview of all windows of the app.
// For the Magic Lamp minimize animation every icon tells KWin where it is on screen.

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ---- Colors (set by chromatia-sync, otherwise the system color) ----
    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cBase: Qt.hsla(hue, 0.25, 0.075, 1)
    readonly property color cCard: Qt.hsla(hue, 0.20, 0.14, 1)
    readonly property color cCard2: Qt.hsla(hue, 0.22, 0.22, 1)
    readonly property color cText: Qt.hsla(hue, 0.55, 0.90, 1)
    readonly property color cDim: Qt.hsla(hue, 0.25, 0.68, 1)

    property alias tasks: tasksModel

    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: activityInfo }

    property var currentDesk: vd.currentDesktop
    function refreshDesk() {
        const d = vd.currentDesktopByScreenName(Screen.name);
        currentDesk = (d !== undefined && d !== null && d !== "") ? d : vd.currentDesktop;
    }
    Connections {
        target: vd
        function onCurrentDesktopChanged() { root.refreshDesk(); }
        function onCurrentDesktopForScreenChanged(name) { root.refreshDesk(); }
    }
    Component.onCompleted: refreshDesk()

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        groupInline: false
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true
        filterByVirtualDesktop: true
        virtualDesktop: root.currentDesk
        filterByActivity: true
        activity: activityInfo.currentActivity
        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: {
            if (JSON.stringify(launcherList) !== JSON.stringify(Plasmoid.configuration.launchers))
                Plasmoid.configuration.launchers = launcherList;
        }
    }

    // ---- Actions ----
    function leftClick(row, isLauncher, isActive, childCount) {
        const idx = tasksModel.makeModelIndex(row);
        if (isLauncher) { tasksModel.requestActivate(idx); return; }
        if (childCount > 1) {
            // several windows: raise the next one
            let next = 0;
            for (let i = 0; i < childCount; i++) {
                if (tasksModel.data(tasksModel.makeModelIndex(row, i), TaskManager.AbstractTasksModel.IsActive) === true) { next = (i + 1) % childCount; break; }
            }
            tasksModel.requestActivate(tasksModel.makeModelIndex(row, next));
            return;
        }
        if (isActive) tasksModel.requestToggleMinimized(idx);
        else tasksModel.requestActivate(idx);
    }

    Preview { id: preview; dock: root; ownerHovered: root.anyHovered; onLeft: closeTimer.restart(); onHoveredChanged: if (hovered) closeTimer.stop() }

    Timer {
        id: openTimer
        interval: 420
        property Item item: null
        property int row: -1
        property bool group: false
        onTriggered: if (item) preview.show(item, row, group)
    }
    Timer {
        id: closeTimer
        interval: 300
        onTriggered: if (!preview.hovered && !root.anyHovered) preview.hide()
    }
    // mouse anywhere over the dock? (one handler for the whole dock, no counter that can get stuck)
    property bool anyHovered: false

    PlasmaExtras.Menu {
        id: menu
        property int row: -1
        property string launcher: ""
        property bool pinned: false
        property bool isWindow: false
        property bool canNew: false

        PlasmaExtras.MenuItem {
            text: "New window"
            icon: "window-new"
            visible: menu.canNew
            onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(menu.row))
        }
        PlasmaExtras.MenuItem {
            text: menu.pinned ? "Unpin from dock" : "Pin to dock"
            icon: menu.pinned ? "window-unpin" : "window-pin"
            visible: menu.launcher !== ""
            onClicked: menu.pinned ? tasksModel.requestRemoveLauncher(menu.launcher) : tasksModel.requestAddLauncher(menu.launcher)
        }
        PlasmaExtras.MenuItem {
            text: "Close"
            icon: "window-close"
            visible: menu.isWindow
            onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(menu.row))
        }
    }

    fullRepresentation: Item {
        id: rep
        readonly property int cell: Math.round(root.height * 1.0)
        Layout.preferredWidth: row.implicitWidth + 8
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        HoverHandler {
            onHoveredChanged: {
                root.anyHovered = hovered;
                if (!hovered) closeTimer.restart();
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: tasksModel

                delegate: Item {
                    id: task
                    readonly property bool isActive: model.IsActive === true
                    readonly property bool isLauncher: model.IsLauncher === true
                    readonly property bool isStartup: model.IsStartup === true
                    readonly property bool attention: model.IsDemandingAttention === true
                    readonly property int windows: isLauncher ? 0 : Math.max(1, model.ChildCount || 0)
                    readonly property string launcherUrl: model.LauncherUrlWithoutIcon ? model.LauncherUrlWithoutIcon.toString() : ""

                    width: rep.cell
                    height: rep.cell
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    // tell KWin the icon position for the minimize animation
                    function publish() {
                        if (isLauncher) return;
                        const p = task.mapToGlobal(0, 0);
                        tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(index),
                            Qt.rect(p.x, p.y, task.width, task.height), task);
                    }
                    onXChanged: pubTimer.restart()
                    Component.onCompleted: pubTimer.restart()
                    onIsLauncherChanged: pubTimer.restart()
                    Timer { id: pubTimer; interval: 200; onTriggered: task.publish() }

                    // background: active pill in the accent color, otherwise subtle on hover
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 12
                        color: task.isActive ? Qt.alpha(root.accent, 0.42)
                                             : (hover.hovered ? Qt.alpha(root.cText, 0.10) : "transparent")
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    Kirigami.Icon {
                        id: icon
                        anchors.centerIn: parent
                        width: Math.round(rep.cell * 0.84)
                        height: width
                        source: model.decoration
                        scale: hover.hovered ? 1.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        opacity: task.isStartup ? 0.6 : 1.0
                        SequentialAnimation on opacity {
                            running: task.isStartup
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 450 }
                            NumberAnimation { to: 1.0; duration: 450 }
                        }
                    }

                    // dots for open windows (max. 3)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        spacing: 3
                        visible: !task.isLauncher
                        Repeater {
                            model: Math.min(3, task.windows)
                            Rectangle {
                                width: task.isActive ? 10 : 4
                                height: 4; radius: 2
                                color: task.attention ? "#f5a623" : (task.isActive ? root.accent : root.cDim)
                                Behavior on width { NumberAnimation { duration: 160 } }
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        onHoveredChanged: {
                            if (hovered && !task.isLauncher) {
                                closeTimer.stop();
                                if (preview.visible && preview.reveal > 0.5) {
                                    preview.show(task, index, task.windows > 1);
                                } else {
                                    openTimer.item = task; openTimer.row = index; openTimer.group = task.windows > 1;
                                    openTimer.restart();
                                }
                            } else {
                                openTimer.stop();
                                closeTimer.restart();
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            openTimer.stop();
                            if (mouse.button === Qt.LeftButton) {
                                preview.hide();
                                root.leftClick(index, task.isLauncher, task.isActive, model.ChildCount || 0);
                            } else if (mouse.button === Qt.MiddleButton) {
                                tasksModel.requestNewInstance(tasksModel.makeModelIndex(index));
                            } else {
                                preview.hide();
                                menu.row = index;
                                menu.launcher = task.launcherUrl;
                                menu.pinned = model.HasLauncher === true || task.isLauncher;
                                menu.isWindow = !task.isLauncher;
                                menu.canNew = model.CanLaunchNewInstance === true || task.isLauncher;
                                menu.visualParent = task;
                                menu.openRelative();
                            }
                        }
                    }
                }
            }
        }
    }
}
