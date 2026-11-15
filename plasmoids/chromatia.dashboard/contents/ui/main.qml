// Chromatia dashboard – slides out of the top screen edge (Caelestia style).
//
// Lives in a thin panel at the top that forms the top part of the frame.
// When the mouse reaches the top edge, a self-drawn window slides out.
// Its top corners curve inwards and flow into the frame.
// Tabs: Dashboard, Audio, System, Notes, Notifications. Colors follow the accent color.

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.workspace.dbus
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ---- Colors (from the accent color, like the bar and the frame) ----
    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cBase: Qt.hsla(hue, 0.25, 0.075, 1)
    readonly property color cCard: Qt.hsla(hue, 0.20, 0.14, 1)
    readonly property color cCard2: Qt.hsla(hue, 0.22, 0.22, 1)
    readonly property color cText: Qt.hsla(hue, 0.55, 0.90, 1)
    readonly property color cDim: Qt.hsla(hue, 0.25, 0.68, 1)
    readonly property color cAccentSoft: Qt.hsla(hue, 0.45, 0.62, 1)
    // signal colour for unread: split-complement (+150°), brighter; skips the lime/green zone (50–170°)
    readonly property real alertHue: { const h = (hue + 150 / 360) % 1; return h > 50 / 360 && h < 170 / 360 ? (h < 110 / 360 ? 45 / 360 : 185 / 360) : h; }
    readonly property color cAlert: Qt.hsla(alertHue, 0.85, 0.70, 1)

    // ---- Sizes ----
    readonly property int dashW: 800
    readonly property int fullH: 400
    readonly property int inv: 24      // inward curved corner at the frame
    readonly property int rad: 28      // rounded bottom corners

    property real reveal: 0            // 0 = eingefahren, 1 = ganz offen
    property int tab: Plasmoid.configuration.lastTab
    property date now: new Date()

    readonly property bool isOpen: reveal > 0         // clock and sensors only run while the dashboard is open
    Timer { interval: 1000; running: root.isOpen; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // ---- Data ----
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    // track position: Plasma only refreshes it on request, once per second while a player tab is open
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0
    function timeText(f) { return Qt.locale("en_US").toString(now, f); }
    readonly property bool waveMedia: Plasmoid.configuration.waveMedia      // wavy media progress (settings → Audio)
    readonly property bool waveVolume: Plasmoid.configuration.waveVolume    // wavy volume sliders
    readonly property bool mediaVisible: reveal > 0.5 && (tab === 0 || tab === 1)
    Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: root.mediaVisible && !!root.player; onTriggered: root.player.updatePosition() }
    function fmt(us) { const s = Math.max(0, Math.floor(us / 1e6)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    function seekTo(v) { if (player && player.canSeek && player.length > 0) player.position = v * player.length; }

    Sensors.Sensor { id: sCpu;   sensorId: "cpu/all/usage";                updateRateLimit: 1000; enabled: root.isOpen }
    Sensors.Sensor { id: sCpuT;  sensorId: "cpu/all/averageTemperature";   updateRateLimit: 2000; enabled: root.isOpen }
    Sensors.Sensor { id: sGpu;   sensorId: "gpu/gpu0/usage";               updateRateLimit: 1000; enabled: root.isOpen }
    Sensors.Sensor { id: sGpuT;  sensorId: "gpu/gpu0/temperature";         updateRateLimit: 2000; enabled: root.isOpen }
    Sensors.Sensor { id: sVram;  sensorId: "gpu/gpu0/usedPercent";         updateRateLimit: 2000; enabled: root.isOpen }
    Sensors.Sensor { id: sGpuW;  sensorId: "gpu/gpu0/power";               updateRateLimit: 2000; enabled: root.isOpen }
    Sensors.Sensor { id: sRam;   sensorId: "memory/physical/usedPercent";  updateRateLimit: 2000; enabled: root.isOpen }
    Sensors.Sensor { id: sDisk;  sensorId: "disk/all/usedPercent";         updateRateLimit: 10000; enabled: root.isOpen }

    function num(s) { const v = Number(s.value); return isNaN(v) ? 0 : v; }

    // Visualizer: gets the bars from the helper io.github.chromatia.Visualizer (starts cava only when needed)
    property var vizValues: []
    Timer {
        interval: 40
        repeat: true
        running: root.tab === 0 && root.reveal > 0.5 && root.playing
        onRunningChanged: if (!running) root.vizValues = []
        onTriggered: {
            const reply = SessionBus.asyncCall({
                "service": "io.github.chromatia.Visualizer",
                "path": "/io/github/chromatia/Visualizer",
                "iface": "io.github.chromatia.Visualizer",
                "member": "Bars",
                "signature": "()",
                "arguments": []
            });
            reply.finished.connect(() => {
                if (!reply.isError) root.vizValues = Array.from(reply.value);
                reply.destroy();
            });
        }
    }

    // Inhibit sleep (like Plasma's "Block sleep and screen locking")
    property int inhibitCookie: -1
    function policyAgent(member, sig, args, done) {
        const r = SessionBus.asyncCall({ "service": "org.kde.Solid.PowerManagement", "path": "/org/kde/Solid/PowerManagement/PolicyAgent",
            "iface": "org.kde.Solid.PowerManagement.PolicyAgent", "member": member, "signature": sig, "arguments": args });
        r.finished.connect(() => { if (done && !r.isError) done(r.value); r.destroy(); });
    }
    function toggleStandby() {
        if (inhibitCookie < 0) policyAgent("AddInhibition", "(uss)", [5, "Chromatia Dashboard", "Sleep inhibited manually"], v => root.inhibitCookie = Number(v));
        else { policyAgent("ReleaseInhibition", "(u)", [inhibitCookie]); inhibitCookie = -1; }
    }

    // ---- Apps playing audio: one entry per app ----
    property var streams: ({})          // key -> {name, icon, obj, corked}
    property var appGroups: []          // [{name, icon, objs:[...]}]
    function streamName(m) {
        const props = m.Properties || {};
        const bin = String(props["application.process.binary"] || "");
        let n = (m.Client && m.Client.name) ? m.Client.name : String(m.Name || "");
        if (n === "Chromium" && bin) n = bin;
        return root.aliasFor(n + " " + bin, n);
    }

    // ---- Nicer app and device names (optional, no settings page) ----
    // aliases: JSON list of [regex, name], e.g. [["whispr","OpenWhispr"]]
    readonly property var aliasList: jsonOr(Plasmoid.configuration.aliases, [])
    function aliasFor(text, fallback) {
        for (const a of aliasList) { try { if (a[0] && new RegExp(a[0], "i").test(text)) return a[1]; } catch (e) {} }
        return fallback;
    }
    function regroup() {
        const g = {};
        for (const k in streams) {
            const st = streams[k];
            if (!st || st.corked) continue;
            if (!g[st.name]) g[st.name] = { name: st.name, icon: st.icon, objs: [] };
            g[st.name].objs.push(st.obj);
        }
        appGroups = Object.keys(g).sort().map(k => g[k]);
    }
    Timer { id: regroupTimer; interval: 150; onTriggered: root.regroup() }
    Repeater {
        model: Vol.SinkInputModel {}
        delegate: Item {
            readonly property string key: (model.Index !== undefined) ? String(model.Index) : String(Math.random())
            readonly property var info: ({ name: root.streamName(model),
                                           icon: (model.IconName && model.IconName.length > 0) ? model.IconName : "audio-volume-high",
                                           obj: model.PulseObject, corked: !!model.Corked })
            onInfoChanged: { root.streams[key] = info; regroupTimer.restart(); }
            Component.onCompleted: { root.streams[key] = info; regroupTimer.restart(); }
            Component.onDestruction: { delete root.streams[key]; regroupTimer.restart(); }
        }
    }

    // ---- Notifications: history for the dashboard tab, popups at the top right ----
    NotificationManager.Notifications {
        id: notifHistory
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
    }
    NotificationManager.Settings { id: notifSettings; live: true }
    function toggleDnd() {
        if (NotificationManager.Server.inhibited) {
            notifSettings.notificationsInhibitedUntil = undefined;
            notifSettings.revokeApplicationInhibitions();
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);          // "until I turn it off"
            notifSettings.notificationsInhibitedUntil = d;
        }
        notifSettings.save();
    }
    // opening the Notifications tab marks everything as read
    readonly property bool notifTabOpen: root.tab === 4 && root.reveal > 0.5
    onNotifTabOpenChanged: if (notifTabOpen) notifHistory.lastRead = new Date()
    NotificationPopups {
        dash: root
        source: notifHistory
        active: Plasmoid.configuration.chromatiaPopups
        seconds: Math.max(3, Plasmoid.configuration.popupSeconds)
        hideInFullscreen: Plasmoid.configuration.hideInFullscreen
        screenRect: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 1920, 1080)
    }

    // ---- Updates (chromatia-update): check at start and every 6 hours, install only on click ----
    property var update: ({ available: false, installed: "", latest: "", changes: [], error: "" })
    property bool showUpdate: false
    property string updateState: ""          // "", "running", "error"
    property string updateError: ""
    readonly property string updater: "\"$HOME/.local/bin/chromatia-update\""
    P5Support.DataSource {
        id: updateRunner
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            let r = null;
            try { r = JSON.parse(data.stdout); } catch (e) { return; }
            if (source.indexOf("--check") >= 0) root.update = r;
            else if (!r.ok) { root.updateState = "error"; root.updateError = r.error; }
        }
    }
    function checkUpdates() { updateRunner.connectSource(root.updater + " --check"); }
    function applyUpdate() { root.updateState = "running"; updateRunner.connectSource(root.updater + " --apply"); }
    Timer { interval: 6 * 3600 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.checkUpdates() }

    // Device choice and names from Chromatia Settings (Audio page)
    function jsonOr(t, d) { try { return JSON.parse(t); } catch (e) { return d; } }
    readonly property var hiddenOutputs: jsonOr(Plasmoid.configuration.hiddenOutputs, [])
    readonly property var hiddenInputs: jsonOr(Plasmoid.configuration.hiddenInputs, [])
    readonly property var deviceNames: jsonOr(Plasmoid.configuration.deviceNames, ({}))
    function niceName(desc, name) {
        if (name && deviceNames[name]) return deviceNames[name];
        const d = desc || "";
        return aliasFor(d, d);
    }

    // open Mission Center (Flatpak)
    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }
    signal requestClose()
    function openMissionCenter() {
        runner.connectSource("gtk-launch io.missioncenter.MissionCenter");
        root.requestClose();
    }

    fullRepresentation: Item {
        id: rep
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: root.dashW

        // ---- Trigger at the top edge ----
        MouseArea {
            id: trigger
            width: root.dashW
            height: parent.height
            anchors.centerIn: parent
            hoverEnabled: true
            onEntered: rep.open()
            onExited: closeTimer.restart()
            onClicked: root.reveal > 0.5 ? rep.close() : rep.open()
        }

        // unread notifications: a glowing pill in the notch, clearly pulsing
        Item {
            id: notchPill
            visible: notifHistory.unreadNotificationsCount > 0 && root.reveal < 0.05
            anchors.centerIn: parent
            width: 70; height: Math.min(10, parent.height)
            Rectangle {            // soft glow behind
                anchors.centerIn: parent
                width: parent.width + 16; height: parent.height + 4; radius: height / 2
                color: root.cAlert
                opacity: pill.opacity * 0.35
            }
            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                color: root.cAlert
                SequentialAnimation on opacity {
                    running: notchPill.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }

        function open() {
            closeTimer.stop();
            if (!drawer.visible && Plasmoid.configuration.openNotificationsFirst && notifHistory.unreadNotificationsCount > 0) root.tab = 4;   // optional: unread first
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

        Connections {
            target: root
            function onRequestClose() { rep.close(); }
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
            // keeps checking while something holds the dashboard open: focus and hover can end without
            // an event that restarts this timer (e.g. a click elsewhere), then it used to stay open
            repeat: true
            onTriggered: {
                if (trigger.containsMouse || bodyHover.hovered || (root.tab === 3 && notesArea.activeFocus)) return;
                stop();
                rep.close();
            }
        }

        // ---- The sliding window ----
        PlasmaCore.Dialog {
            id: drawer
            visualParent: trigger
            location: PlasmaCore.Types.TopEdge
            type: PlasmaCore.Dialog.Normal
            flags: Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: false
            visible: false

            mainItem: Item {
                id: body
                width: root.dashW + 2 * root.inv
                height: root.fullH

                HoverHandler {
                    id: bodyHover
                    onHoveredChanged: if (!hovered) closeTimer.restart(); else closeTimer.stop()
                }

                readonly property real bw: width
                readonly property real bh: Math.max(root.inv + root.rad + 2, root.fullH * root.reveal)

                // shape with inward curved top corners
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
                            readonly property real ro: root.rad
                            path: `M0,0 L${w},0 A${ri},${ri} 0 0 0 ${w - ri},${ri} L${w - ri},${h - ro} `
                                + `A${ro},${ro} 0 0 1 ${w - ri - ro},${h} L${ri + ro},${h} `
                                + `A${ro},${ro} 0 0 1 ${ri},${h - ro} L${ri},${ri} A${ri},${ri} 0 0 0 0,0 Z`
                        }
                    }
                }

                // content that slides out with the window
                Item {
                    x: root.inv
                    width: root.dashW
                    height: body.bh
                    clip: true

                    Item {
                        width: root.dashW
                        height: root.fullH
                        y: -(1 - root.reveal) * 40
                        opacity: Math.min(1, root.reveal * 1.8)

                        // tabs: centered, moved left by half the quick toggles (and further if the update pill needs room)
                        Row {
                            id: tabs
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.horizontalCenterOffset: Math.min(quick.width > 0 ? -(quick.width + 8) / 2 : 0,
                                                                     rightPills.x - 16 - (root.dashW + width) / 2)
                            Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            y: 12
                            spacing: 8

                            Repeater {
                                model: [
                                    { icon: "view-app-grid-symbolic", name: "Dashboard" },
                                    { icon: "audio-volume-high-symbolic", name: "Audio" },
                                    { icon: "speedometer", name: "System" },
                                    { icon: "document-edit-symbolic", name: "Notes" },
                                    { icon: "notifications-symbolic", name: "Notifications" }
                                ]
                                Rectangle {
                                    readonly property bool active: root.tab === index
                                    width: tabRow.implicitWidth + 28
                                    height: 34
                                    radius: height / 2
                                    color: active ? root.accent : (tabMouse.containsMouse ? root.cCard2 : root.cCard)
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    Row {
                                        id: tabRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Kirigami.Icon {
                                            source: modelData.icon
                                            width: 16; height: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            isMask: true
                                            color: parent.parent.active ? "white" : root.cText
                                        }
                                        Text {
                                            text: modelData.name
                                            color: parent.parent.active ? "white" : root.cText
                                            font.pixelSize: 13
                                            font.bold: parent.parent.active
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Rectangle {          // unread notifications
                                        visible: index === 4 && notifHistory.unreadNotificationsCount > 0 && !parent.active
                                        anchors.right: parent.right; anchors.top: parent.top
                                        anchors.rightMargin: 4; anchors.topMargin: 2
                                        width: 16; height: 16; radius: 8
                                        color: root.cAlert
                                        Text { anchors.centerIn: parent; text: Math.min(9, notifHistory.unreadNotificationsCount); color: root.cBase; font.pixelSize: 10; font.bold: true }
                                    }
                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.tab = index; Plasmoid.configuration.lastTab = index; }
                                    }
                                }
                            }
                        }

                        // right: update pill, Wi-Fi/Bluetooth toggles, gear
                        Row {
                            id: rightPills
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            y: 12
                            spacing: 8

                            // Update available: glowing pill left of the gear
                            Rectangle {
                                visible: root.update.available === true
                                height: 34
                                width: updRow.implicitWidth + 24
                                radius: 17
                                color: root.accent
                                SequentialAnimation on opacity {
                                    running: root.update.available === true && !root.showUpdate
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.65; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                }
                                Row {
                                    id: updRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Kirigami.Icon { width: 16; height: 16; source: "update-none-symbolic"; isMask: true; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Update"; color: "white"; font.pixelSize: 13; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showUpdate = !root.showUpdate }
                            }

                            Loader { id: quick; Component.onCompleted: setSource("QuickToggles.qml", { dash: root }) }

                            // Settings: opens the widget's configuration dialog (= Chromatia Settings)
                            Rectangle {
                                id: gearButton
                                width: 34; height: 34; radius: 17
                                color: gearMouse.containsMouse ? root.cCard2 : root.cCard
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    source: "configure-symbolic"
                                    isMask: true
                                    color: root.cText
                                }
                                MouseArea {
                                    id: gearMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.requestClose(); Plasmoid.internalAction("configure").trigger(); }
                                }
                            }
                        }

                        // Update card: what's new + install button
                        Rectangle {
                            visible: root.showUpdate
                            anchors.fill: pages
                            z: 20
                            radius: 18
                            color: root.cCard
                            Column {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 8
                                Text {
                                    text: "Chromatia " + root.update.latest + " is available"
                                    color: root.cText; font.pixelSize: 17; font.bold: true
                                }
                                Text {
                                    text: "You have " + root.update.installed + ".  What's new:"
                                    color: root.cDim; font.pixelSize: 12
                                }
                                Flickable {
                                    width: parent.width
                                    height: parent.height - 120
                                    clip: true
                                    contentHeight: changeCol.implicitHeight
                                    Column {
                                        id: changeCol
                                        width: parent.width
                                        spacing: 4
                                        Repeater {
                                            model: root.update.changes || []
                                            Column {
                                                width: changeCol.width
                                                spacing: 2
                                                Text { text: modelData.version; color: root.accent; font.pixelSize: 13; font.bold: true }
                                                Repeater {
                                                    model: modelData.items
                                                    Text { width: changeCol.width; text: "•  " + modelData; color: root.cText; font.pixelSize: 12; wrapMode: Text.Wrap }
                                                }
                                            }
                                        }
                                    }
                                }
                                Text {
                                    visible: root.updateState !== ""
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: root.updateState === "running" ? "Updating… Plasma restarts in a moment."
                                                                         : ("Update failed: " + root.updateError)
                                    color: root.updateState === "error" ? "#e5484d" : root.cText
                                    font.pixelSize: 12
                                }
                                Row {
                                    spacing: 10
                                    Rectangle {
                                        width: nowText.implicitWidth + 32; height: 34; radius: 17
                                        color: root.updateState === "running" ? root.cCard2 : root.accent
                                        Text { id: nowText; anchors.centerIn: parent; text: "Update now"; color: "white"; font.pixelSize: 13; font.bold: true }
                                        MouseArea { anchors.fill: parent; enabled: root.updateState !== "running"; cursorShape: Qt.PointingHandCursor; onClicked: root.applyUpdate() }
                                    }
                                    Rectangle {
                                        width: laterText.implicitWidth + 32; height: 34; radius: 17
                                        color: root.cCard2
                                        Text { id: laterText; anchors.centerIn: parent; text: "Later"; color: root.cText; font.pixelSize: 13 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.showUpdate = false }
                                    }
                                }
                            }
                        }

                        StackLayout {
                            id: pages
                            anchors.top: tabs.bottom
                            anchors.topMargin: 14
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            anchors.bottomMargin: 18
                            currentIndex: root.tab

                            // ===== Dashboard =====
                            // clock above the calendar on the left, media and stats get the rest
                            RowLayout {
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 250
                                    Layout.fillHeight: true
                                    spacing: 12
                                    Card {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 96
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 14
                                            Text { text: root.timeText("hh:mm"); color: root.cText; font.pixelSize: 50; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3
                                                Rectangle { width: 28; height: 4; radius: 2; color: root.accent }
                                                Text { text: root.timeText("dddd"); color: root.cAccentSoft; font.pixelSize: 15; font.bold: true }
                                                Text { text: root.timeText("d MMMM"); color: root.cDim; font.pixelSize: 12 }
                                            }
                                        }
                                    }
                                    Card {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        MonthTitle { id: mt1; x: 16; y: 12 }
                                        CalendarGrid { cellW: 31; cellH: 21; anchors.top: mt1.bottom; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12
                                    MediaCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 182
                                        Cat { width: 180; height: 57; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12 }
                                    }
                                    Card {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6
                                            SleepPill { width: parent.width }
                                            Grid {
                                                columns: 2; columnSpacing: 20; rowSpacing: 2
                                                Bar { width: 229; label: "CPU"; value: root.num(sCpu) }
                                                Bar { width: 229; label: "GPU"; value: root.num(sGpu) }
                                                Bar { width: 229; label: "RAM"; value: root.num(sRam) }
                                                Bar { width: 229; label: "VRAM"; value: root.num(sVram) }
                                            }
                                        }
                                    }
                                }
                            }

                            // ===== Audio =====
                            RowLayout {
                                spacing: 12

                                // outputs and microphones
                                Rectangle {
                                    Layout.preferredWidth: 380
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: root.cCard

                                    Flickable {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        contentHeight: devCol.implicitHeight
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        Column {
                                            id: devCol
                                            width: parent.width
                                            spacing: 6

                                            SectionTitle { text: "Output" }
                                            Repeater {
                                                model: Vol.SinkModel {}
                                                DeviceRow {}
                                            }
                                            Item { width: 1; height: 6 }
                                            SectionTitle { text: "Microphone" }
                                            Repeater {
                                                model: Vol.SourceModel {}
                                                DeviceRow { mic: true }
                                            }
                                        }
                                    }
                                }

                                // apps that are playing audio right now
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: root.cCard

                                    // now playing: cover, title, buttons, wavy progress
                                    Rectangle {
                                        id: nowPlaying
                                        visible: !!root.player
                                        x: 8; y: 8
                                        width: parent.width - 16
                                        height: visible ? 104 : 0
                                        radius: 14
                                        color: root.cCard2
                                        Kirigami.ShadowedImage {
                                            id: npArt
                                            x: 12; y: 12
                                            width: 48; height: 48
                                            radius: width / 2
                                            color: root.cCard
                                            source: root.player ? root.player.artUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                        }
                                        Column {
                                            anchors.left: npArt.right; anchors.leftMargin: 12
                                            anchors.right: npButtons.left; anchors.rightMargin: 8
                                            anchors.verticalCenter: npArt.verticalCenter
                                            spacing: 2
                                            Text { width: parent.width; text: root.player ? root.player.track : ""; color: root.cText; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                                            Text { width: parent.width; text: root.player ? root.player.artist : ""; color: root.cDim; font.pixelSize: 11; elide: Text.ElideRight }
                                        }
                                        Row {
                                            id: npButtons
                                            anchors.right: parent.right; anchors.rightMargin: 10
                                            anchors.verticalCenter: npArt.verticalCenter
                                            spacing: 2
                                            MediaButton { icon: "media-skip-backward"; size: 28; onClicked: root.player && root.player.Previous() }
                                            MediaButton { icon: root.playing ? "media-playback-pause" : "media-playback-start"; big: true; size: 32; onClicked: root.player && root.player.PlayPause() }
                                            MediaButton { icon: "media-skip-forward"; size: 28; onClicked: root.player && root.player.Next() }
                                        }
                                        TimedWave {
                                            track: root.cCard
                                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                            anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 10
                                        }
                                    }
                                    SectionTitle {
                                        id: appsTitle
                                        x: 14; y: nowPlaying.visible ? nowPlaying.height + 20 : 14
                                        text: "Apps"
                                    }
                                    ListView {
                                        id: appList
                                        anchors.top: appsTitle.bottom
                                        anchors.topMargin: 8
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 14
                                        clip: true
                                        spacing: 6
                                        boundsBehavior: Flickable.StopAtBounds
                                        model: root.appGroups
                                        delegate: StreamRow {}
                                        Text {
                                            visible: appList.count === 0
                                            anchors.centerIn: parent
                                            text: "No app is playing audio right now"
                                            color: root.cDim
                                            font.pixelSize: 13
                                        }
                                    }
                                }
                            }

                            // ===== System =====
                            Rectangle {
                                radius: 20
                                color: root.cCard
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openMissionCenter()
                                }
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Ring { label: "CPU";        value: root.num(sCpu);  barColor: root.accent; trackColor: root.cCard2; textColor: root.cText }
                                    Ring { label: "CPU temp";   value: root.num(sCpuT); valueText: Math.round(value) + " °C"; barColor: root.cAccentSoft; trackColor: root.cCard2; textColor: root.cText }
                                    Ring { label: "GPU";        value: root.num(sGpu);  barColor: root.accent; trackColor: root.cCard2; textColor: root.cText }
                                    Ring { label: "GPU temp";   value: root.num(sGpuT); valueText: Math.round(value) + " °C"; barColor: root.cAccentSoft; trackColor: root.cCard2; textColor: root.cText }
                                    Ring { label: "VRAM"; value: root.num(sVram); barColor: root.accent; trackColor: root.cCard2; textColor: root.cText }
                                    Ring { label: "Memory"; value: root.num(sRam); barColor: root.accent; trackColor: root.cCard2; textColor: root.cText }
                                    Ring { label: "Disk"; value: root.num(sDisk); barColor: root.cAccentSoft; trackColor: root.cCard2; textColor: root.cText }
                                }
                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "GPU power: " + Math.round(root.num(sGpuW)) + " W   ·   click to open Mission Center"
                                    color: root.cDim
                                    font.pixelSize: 12
                                }
                            }

                            // ===== Notes =====
                            Rectangle {
                                radius: 20
                                color: root.cCard

                                QQC2.ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    anchors.bottomMargin: 90
                                    QQC2.TextArea {
                                        id: notesArea
                                        text: Plasmoid.configuration.notes
                                        placeholderText: "Notes …"
                                        color: root.cText
                                        placeholderTextColor: root.cDim
                                        wrapMode: TextEdit.Wrap
                                        font.pixelSize: 15
                                        background: null
                                        onTextChanged: saveTimer.restart()
                                        Timer {
                                            id: saveTimer
                                            interval: 1500
                                            onTriggered: Plasmoid.configuration.notes = notesArea.text
                                        }
                                    }
                                }
                                AnimatedImage {
                                    source: Qt.resolvedUrl("../images/cat-playing.webp")
                                    width: 220; height: 69
                                    fillMode: Image.PreserveAspectFit
                                    playing: root.reveal > 0 && root.tab === 3
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 14
                                }
                            }

                            // ===== Notifications =====
                            NotificationsPage {
                                dash: root
                                history: notifHistory
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- small building blocks ----
    component Card: Rectangle { radius: 20; color: root.cCard }

    component MonthTitle: Text { text: root.timeText("MMMM yyyy"); color: root.cText; font.pixelSize: 15; font.bold: true }

    // playing cat: "Cat playing animation" by Abdul Latif (LottieFiles, Lottie Simple License)
    component Cat: AnimatedImage {
        source: Qt.resolvedUrl("../images/cat-playing.webp")
        fillMode: Image.PreserveAspectFit
        playing: root.reveal > 0
    }

    // month grid, only as many weeks as the month needs
    component CalendarGrid: Grid {
        id: cg
        property int cellW: 29
        property int cellH: 28
        readonly property int year: root.now.getFullYear()
        readonly property int month: root.now.getMonth()
        readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7
        readonly property int days: new Date(year, month + 1, 0).getDate()
        columns: 7
        rowSpacing: 3
        columnSpacing: 2
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text { width: cg.cellW; height: 18; horizontalAlignment: Text.AlignHCenter; text: modelData; color: root.cDim; font.pixelSize: 11; font.bold: true }
        }
        Repeater {
            model: Math.ceil((cg.offset + cg.days) / 7) * 7
            Rectangle {
                readonly property int day: index - cg.offset + 1
                readonly property bool valid: day >= 1 && day <= cg.days
                readonly property bool today: valid && day === root.now.getDate()
                width: cg.cellW; height: cg.cellH
                radius: height / 2
                color: today ? root.accent : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.valid ? parent.day : ""
                    color: parent.today ? "white" : root.cText
                    font.pixelSize: 12
                    font.bold: parent.today
                }
            }
        }
    }

    // round cover with a visualizer ring; title, wavy progress and buttons beside it
    component MediaCard: Rectangle {
        id: mc
        radius: 20
        color: root.cCard
        Item {
            id: artBox
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 156; height: 156
            VisualizerRing {
                anchors.fill: parent
                values: root.vizValues
                count: 40
                innerRadius: art.width / 2 + 4
                maxLength: 20
                barWidth: 3
                color: root.cAccentSoft
            }
            Kirigami.ShadowedImage {
                id: art
                anchors.centerIn: parent
                width: 88; height: 88
                radius: width / 2
                color: root.cCard2
                source: root.player ? root.player.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                Image {
                    visible: !root.player || !root.player.artUrl
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("../images/cat.svg")
                    width: 56; height: 48
                    sourceSize.width: 112
                }
            }
        }
        Column {
            x: artBox.x + artBox.width + 2
            width: mc.width - x - 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: root.player && root.player.track ? root.player.track : "Nothing playing"
                color: root.cText
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.player ? root.player.artist : ""
                color: root.cDim
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            TimedWave { visible: !!root.player; width: parent.width; height: 26 }
            Row {
                spacing: 6
                topPadding: 8
                MediaButton { icon: "media-skip-backward"; onClicked: root.player && root.player.Previous() }
                MediaButton { icon: root.playing ? "media-playback-pause" : "media-playback-start"; big: true; size: 36; onClicked: root.player && root.player.PlayPause() }
                MediaButton { icon: "media-skip-forward"; onClicked: root.player && root.player.Next() }
            }
        }
    }

    // sleep switch (like Plasma's "Block sleep and screen locking")
    component SleepPill: Rectangle {
        readonly property bool on: root.inhibitCookie >= 0
        height: 32
        radius: height / 2
        color: on ? root.accent : (spMouse.containsMouse ? root.cCard2 : Qt.alpha(root.cCard2, 0.6))
        Behavior on color { ColorAnimation { duration: 160 } }
        Row {
            anchors.centerIn: parent
            spacing: 8
            Kirigami.Icon {
                source: parent.parent.on ? "system-suspend-inhibited" : "system-suspend"
                width: 16; height: 16
                isMask: true
                color: parent.parent.on ? "white" : root.cText
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: parent.parent.on ? "Sleep inhibited" : "Sleep allowed"
                color: parent.parent.on ? "white" : root.cText
                font.pixelSize: 13
                font.bold: parent.parent.on
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: spMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleStandby()
        }
    }

    component MediaButton: Rectangle {
        id: mb
        property string icon
        property bool big: false
        property int size: 30
        signal clicked()
        width: size; height: size
        radius: size / 2
        color: big ? root.accent : (mbMouse.containsMouse ? root.cCard2 : "transparent")
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(mb.size * 0.5); height: width
            source: mb.icon
            isMask: true
            color: mb.big ? "white" : root.cText
        }
        MouseArea {
            id: mbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }

    // wavy progress with elapsed time left and track length right
    component TimedWave: Item {
        property color track: root.cCard2
        height: 20
        Text { id: twPos; width: 34; anchors.verticalCenter: parent.verticalCenter; text: root.fmt(root.player ? root.player.position : 0); color: root.cDim; font.pixelSize: 11 }
        WaveProgress {
            anchors.left: twPos.right; anchors.right: twLen.left; anchors.leftMargin: 6; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            value: root.progress
            playing: root.playing
            running: root.mediaVisible && parent.visible
            amplitude: root.waveMedia ? 3 : 0
            color: root.accent
            trackColor: parent.track
            seekable: !!root.player && root.player.canSeek
            onSeek: v => root.seekTo(v)
        }
        Text { id: twLen; width: 34; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: root.fmt(root.player ? root.player.length : 0); color: root.cDim; font.pixelSize: 11 }
    }

    component SectionTitle: Text {
        color: root.cText
        font.pixelSize: 14
        font.bold: true
    }

    // volume slider with mute button and percentage
    component VolSlider: Item {
        id: vs
        property real value: 0          // 0..1
        property bool muted: false
        property bool mic: false
        property bool moving: false
        signal moved(real v)
        signal muteToggled()
        height: 26
        property real shown: drag.pressed ? drag.live : value

        Kirigami.Icon {
            id: muteIcon
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            isMask: true
            color: vs.muted ? root.cDim : root.cText
            source: vs.mic ? (vs.muted ? "microphone-sensitivity-muted" : "audio-input-microphone")
                           : (vs.muted ? "audio-volume-muted" : (vs.shown < 0.34 ? "audio-volume-low" : (vs.shown < 0.67 ? "audio-volume-medium" : "audio-volume-high")))
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: vs.muteToggled() }
        }
        Item {
            id: track
            anchors.left: muteIcon.right; anchors.leftMargin: 10
            anchors.right: pct.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            WaveProgress {      // wavy when audible, flat when muted; moves while sound is playing
                anchors.fill: parent
                value: vs.shown
                playing: !vs.muted
                running: vs.moving
                seekable: false
                amplitude: root.waveVolume ? 2.5 : 0; wavelength: 18
                color: vs.muted ? root.cDim : root.accent
                trackColor: Qt.alpha(root.cText, 0.14)      // visible on card and on the highlighted default row
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property real live: 0
                function upd(mx) { live = Math.max(0, Math.min(1, (mx - 6) / track.width)); vs.moved(live); }
                onPressed: mouse => upd(mouse.x)
                onPositionChanged: mouse => { if (pressed) upd(mouse.x); }
                onWheel: wheel => vs.moved(Math.max(0, Math.min(1, vs.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Text {
            id: pct
            width: 38
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(vs.shown * 100) + " %"
            color: root.cText
            font.pixelSize: 12
        }
    }

    // output or microphone: a click makes it the default, volume below
    component DeviceRow: Rectangle {
        id: dr
        property bool mic: false
        readonly property bool isMonitor: String(model.Name || "").indexOf(".monitor") >= 0
        readonly property bool hiddenBySettings: (mic ? root.hiddenInputs : root.hiddenOutputs).indexOf(String(model.Name || "")) >= 0
        visible: !isMonitor && !hiddenBySettings
        width: parent ? parent.width : 300
        height: visible ? 64 : 0
        radius: 14
        color: model.Default ? Qt.alpha(root.accent, 0.30) : (drHover.hovered ? root.cCard2 : "transparent")
        Behavior on color { ColorAnimation { duration: 150 } }
        HoverHandler { id: drHover }

        Rectangle {
            id: dot
            x: 12; y: 12
            width: 14; height: 14; radius: 7
            color: model.Default ? root.accent : "transparent"
            border.width: 2
            border.color: model.Default ? root.accent : root.cDim
        }
        Text {
            anchors.left: dot.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: dot.verticalCenter
            text: root.niceName(model.Description, String(model.Name || ""))
            color: root.cText
            font.pixelSize: 13
            font.bold: model.Default
            elide: Text.ElideRight
        }
        MouseArea {
            x: 0; y: 0; width: parent.width; height: 34
            cursorShape: Qt.PointingHandCursor
            onClicked: model.PulseObject.default = true
        }
        VolSlider {
            x: 12; y: 34
            width: parent.width - 24
            mic: dr.mic
            moving: !dr.mic && model.Default && root.playing && root.reveal > 0.5 && root.tab === 1
            value: model.Volume / 65536
            muted: model.Muted
            onMoved: v => model.PulseObject.volume = Math.round(v * 65536)
            onMuteToggled: model.PulseObject.muted = !model.Muted
        }
    }

    // app that is playing audio (all its streams together)
    component StreamRow: Rectangle {
        id: sr
        required property var modelData
        readonly property var first: modelData.objs.length > 0 ? modelData.objs[0] : null
        width: ListView.view ? ListView.view.width : 300
        height: 58
        radius: 14
        color: srHover.hovered ? root.cCard2 : "transparent"
        HoverHandler { id: srHover }
        Kirigami.Icon {
            id: appIcon
            x: 10; y: 8
            width: 20; height: 20
            source: sr.modelData.icon
        }
        Text {
            anchors.left: appIcon.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: appIcon.verticalCenter
            text: sr.modelData.name + (sr.modelData.objs.length > 1 ? "  ·  " + sr.modelData.objs.length + " sources" : "")
            color: root.cText
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }
        VolSlider {
            x: 10; y: 30
            width: parent.width - 22
            moving: root.reveal > 0.5 && root.tab === 1
            value: sr.first ? sr.first.volume / 65536 : 0
            muted: sr.first ? sr.first.muted : false
            onMoved: v => sr.modelData.objs.forEach(o => o.volume = Math.round(v * 65536))
            onMuteToggled: { const m = !(sr.first && sr.first.muted); sr.modelData.objs.forEach(o => o.muted = m); }
        }
    }

    component Bar: Item {
        id: bar
        property string label
        property real value: 0
        width: parent ? parent.width : 200
        height: 22
        Text { id: bl; width: 38; text: bar.label; color: root.cDim; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            anchors.left: bl.right; anchors.right: bv.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 8; radius: 4
            color: root.cCard2
            Rectangle {
                height: parent.height; radius: 4
                width: parent.width * Math.max(0, Math.min(1, bar.value / 100))
                color: root.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        Text { id: bv; width: 40; anchors.right: parent.right; horizontalAlignment: Text.AlignRight; text: Math.round(bar.value) + " %"; color: root.cText; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }
}
