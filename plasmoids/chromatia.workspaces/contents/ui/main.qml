// Workspace pills – virtual desktops, Caelestia style.
// Every desktop is a numbered pill, the active one wider and in the
// accent color. Click switches, the mouse wheel scrolls through them.
// Optional launcher button in front (Chromatia Settings → Bar, passed on by chromatia-sync).

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus

PlasmoidItem {
    id: root

    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)

    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cBase: Qt.hsla(hue, 0.25, 0.075, 1)
    readonly property color cCard: Qt.hsla(hue, 0.20, 0.14, 1)
    readonly property color cCard2: Qt.hsla(hue, 0.22, 0.22, 1)
    readonly property color cText: Qt.hsla(hue, 0.55, 0.90, 1)
    readonly property color cDim: Qt.hsla(hue, 0.25, 0.68, 1)
    readonly property string wallpaper: Plasmoid.configuration.wallpaper !== "" ? "file://" + Plasmoid.configuration.wallpaper : ""

    DeskPreview { id: preview; pills: root; ownerHovered: root.pillHovered; onLeft: closeTimer.restart(); onHoveredChanged: if (hovered) closeTimer.stop() }
    property int hoverCount: 0
    readonly property bool pillHovered: hoverCount > 0
    Timer {
        id: openTimer
        interval: 380
        property Item item: null
        property var deskId: ""
        property int num: 0
        property rect geo
        onTriggered: if (item) preview.show(item, deskId, num, geo)
    }
    Timer {
        id: closeTimer
        interval: 300
        onTriggered: if (!preview.hovered && !root.pillHovered) preview.hide()
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    TaskManager.VirtualDesktopInfo { id: vd }

    // Plasma can have desktops per screen, so use the one of our own screen.
    property string screenName: Screen.name
    property var current: vd.currentDesktop

    function refresh() {
        const byScreen = vd.currentDesktopByScreenName(screenName);
        current = (byScreen !== undefined && byScreen !== null && byScreen !== "") ? byScreen : vd.currentDesktop;
    }

    Connections {
        target: vd
        function onCurrentDesktopChanged() { root.refresh(); }
        function onCurrentDesktopForScreenChanged(name) { if (name === root.screenName) root.refresh(); }
        function onDesktopIdsChanged() { root.refresh(); }
    }
    onScreenNameChanged: refresh()
    Component.onCompleted: refresh()

    function call(service, path, iface, member, sig, args) {
        const r = SessionBus.asyncCall({ "service": service, "path": path, "iface": iface, "member": member, "signature": sig, "arguments": args });
        r.finished.connect(() => r.destroy());
    }
    function switchTo(number) { call("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component", "invokeShortcut", "(s)", ["Switch to Desktop " + number]); }
    function kwinDesk(member, sig, args) { call("org.kde.KWin", "/VirtualDesktopManager", "org.kde.KWin.VirtualDesktopManager", member, sig, args); }
    function addDesktop() { kwinDesk("createDesktop", "(us)", [vd.numberOfDesktops, ""]); }
    function removeDesktop(id) { if (vd.numberOfDesktops > 1) kwinDesk("removeDesktop", "(s)", [id]); }

    // pill size follows the bar height so the pills are easy to hit
    readonly property int pillH: Math.max(18, Math.round(root.height * 0.62))
    readonly property int pillW: Math.round(pillH * 1.45)

    fullRepresentation: Item {
        Layout.preferredWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(root.pillH * 0.25)

            // application launcher: opens the same launcher as the bottom-left hot corner
            Rectangle {
                id: launcher
                visible: Plasmoid.configuration.launcherButton
                width: root.pillH; height: root.pillH
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: launchMouse.containsMouse ? root.accent : Qt.alpha(Kirigami.Theme.textColor, 0.10)
                Behavior on color { ColorAnimation { duration: 150 } }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(root.pillH * 0.6); height: width
                    source: "view-app-grid-symbolic"
                    isMask: true
                    color: launchMouse.containsMouse ? "white" : Qt.alpha(Kirigami.Theme.textColor, 0.85)
                }
                MouseArea {
                    id: launchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.call("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "activateLauncherMenu", "()", [])
                }
            }
            Item { visible: launcher.visible; width: Math.round(root.pillH * 0.15); height: 1 }   // a little extra gap

            Repeater {
                model: vd.desktopIds

                Rectangle {
                    readonly property bool active: modelData === root.current
                    width: active ? Math.round(root.pillW * 1.35) : root.pillW
                    height: root.pillH
                    radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: active ? root.accent
                                  : Qt.alpha(Kirigami.Theme.textColor, hover.containsMouse ? 0.22 : 0.10)

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        font.bold: true
                        font.pixelSize: Math.round(root.pillH * 0.55)
                        color: parent.active ? "white"
                                             : Qt.alpha(Kirigami.Theme.textColor, 0.85)
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            openTimer.stop(); preview.hide();
                            if (mouse.button === Qt.RightButton) root.removeDesktop(modelData);
                            else root.switchTo(index + 1);
                        }
                        onContainsMouseChanged: {
                            root.hoverCount = Math.max(0, root.hoverCount + (containsMouse ? 1 : -1));
                            if (containsMouse) {
                                closeTimer.stop();
                                const geo = Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height);
                                if (preview.visible && preview.reveal > 0.5) {
                                    preview.show(parent, modelData, index + 1, geo);
                                } else {
                                    openTimer.item = parent; openTimer.deskId = modelData; openTimer.num = index + 1; openTimer.geo = geo;
                                    openTimer.restart();
                                }
                            } else {
                                openTimer.stop();
                                closeTimer.restart();
                            }
                        }
                    }
                }
            }
            // add a desktop
            Rectangle {
                width: root.pillH; height: root.pillH
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Kirigami.Theme.textColor, plusMouse.containsMouse ? 0.22 : 0.06)
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, plusMouse.containsMouse ? 0.0 : 0.18)
                Behavior on color { ColorAnimation { duration: 150 } }
                // plus sign from two bars, exactly centered
                Repeater {
                    model: 2
                    Rectangle {
                        anchors.centerIn: parent
                        width: index === 0 ? Math.round(root.pillH * 0.46) : 2
                        height: index === 0 ? 2 : Math.round(root.pillH * 0.46)
                        radius: 1
                        color: plusMouse.containsMouse ? root.accent : Qt.alpha(Kirigami.Theme.textColor, 0.8)
                    }
                }
                MouseArea {
                    id: plusMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addDesktop()
                }
            }
        }

        WheelHandler {
            property real acc: 0
            onWheel: event => {
                acc += event.angleDelta.y;
                if (Math.abs(acc) < 120) return;
                const ids = vd.desktopIds;
                let i = ids.indexOf(root.current);
                i = acc > 0 ? Math.max(0, i - 1) : Math.min(ids.length - 1, i + 1);
                acc = 0;
                root.switchTo(i + 1);
            }
        }
    }
}
