// Chromatia Dashboard – gleitet vom oberen Bildschirmrand heraus (Caelestia-Stil).
//
// Sitzt in einer 10 px dünnen Leiste oben, die optisch den oberen Rahmen bildet.
// Fährt die Maus an den oberen Rand, gleitet ein eigenes, selbst gezeichnetes Fenster
// heraus. Seine oberen Ecken sind nach innen gewölbt und gehen fließend in den Rahmen über.
// Kategorien: Dashboard, Medien, Leistung, Notizen. Farben folgen der Akzentfarbe.

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

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ---- Farben (aus der Akzentfarbe, wie Leiste und Rahmen) ----
    readonly property color accent: (Plasmoid.configuration.accentColor !== "" ? Plasmoid.configuration.accentColor : Kirigami.Theme.highlightColor)
    readonly property real hue: Math.max(0, accent.hslHue)
    readonly property color cBase: Qt.hsla(hue, 0.25, 0.075, 1)
    readonly property color cCard: Qt.hsla(hue, 0.20, 0.14, 1)
    readonly property color cCard2: Qt.hsla(hue, 0.22, 0.22, 1)
    readonly property color cText: Qt.hsla(hue, 0.55, 0.90, 1)
    readonly property color cDim: Qt.hsla(hue, 0.25, 0.68, 1)
    readonly property color cAccentSoft: Qt.hsla(hue, 0.45, 0.62, 1)

    // ---- Maße ----
    readonly property int dashW: 800
    readonly property int fullH: 400
    readonly property int inv: 24      // nach innen gewölbte Ecke am Rahmen
    readonly property int rad: 28      // abgerundete untere Ecken

    property real reveal: 0            // 0 = eingefahren, 1 = ganz offen
    property int tab: Plasmoid.configuration.lastTab
    property date now: new Date()

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // ---- Daten ----
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing

    Sensors.Sensor { id: sCpu;   sensorId: "cpu/all/usage";                updateRateLimit: 1000 }
    Sensors.Sensor { id: sCpuT;  sensorId: "cpu/all/averageTemperature";   updateRateLimit: 2000 }
    Sensors.Sensor { id: sGpu;   sensorId: "gpu/gpu0/usage";               updateRateLimit: 1000 }
    Sensors.Sensor { id: sGpuT;  sensorId: "gpu/gpu0/temperature";         updateRateLimit: 2000 }
    Sensors.Sensor { id: sVram;  sensorId: "gpu/gpu0/usedPercent";         updateRateLimit: 2000 }
    Sensors.Sensor { id: sGpuW;  sensorId: "gpu/gpu0/power";               updateRateLimit: 2000 }
    Sensors.Sensor { id: sRam;   sensorId: "memory/physical/usedPercent";  updateRateLimit: 2000 }
    Sensors.Sensor { id: sDisk;  sensorId: "disk/all/usedPercent";         updateRateLimit: 10000 }

    function num(s) { const v = Number(s.value); return isNaN(v) ? 0 : v; }

    // Visualizer: holt die Balken vom Helfer io.github.chromatia.Visualizer (startet cava nur bei Bedarf)
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

    // Standby verhindern (wie Plasmas „Standby und Bildschirmsperre blockieren“)
    property int inhibitCookie: -1
    function toggleStandby() {
        if (inhibitCookie >= 0) {
            const r = SessionBus.asyncCall({ "service": "org.kde.Solid.PowerManagement",
                "path": "/org/kde/Solid/PowerManagement/PolicyAgent",
                "iface": "org.kde.Solid.PowerManagement.PolicyAgent",
                "member": "ReleaseInhibition", "signature": "(u)", "arguments": [inhibitCookie] });
            r.finished.connect(() => r.destroy());
            inhibitCookie = -1;
        } else {
            const r = SessionBus.asyncCall({ "service": "org.kde.Solid.PowerManagement",
                "path": "/org/kde/Solid/PowerManagement/PolicyAgent",
                "iface": "org.kde.Solid.PowerManagement.PolicyAgent",
                "member": "AddInhibition", "signature": "(uss)",
                "arguments": [5, "Chromatia Dashboard", "Sleep inhibited manually"] });
            r.finished.connect(() => { if (!r.isError) root.inhibitCookie = Number(r.value); r.destroy(); });
        }
    }

    // ---- Programme mit Ton: Streams pro Programm zusammenfassen ----
    property var streams: ({})          // key -> {name, icon, obj, corked}
    property var appGroups: []          // [{name, icon, objs:[...]}]
    function streamName(m) {
        const props = m.Properties || {};
        const bin = String(props["application.process.binary"] || "");
        let n = (m.Client && m.Client.name) ? m.Client.name : String(m.Name || "");
        if (n === "Chromium" && bin) n = bin;
        return root.aliasFor(n + " " + bin, n);
    }

    // ---- Optional device/app filters and nicer names (Chromatia settings) ----
    // aliases: JSON list of [regex, name], e.g. [["sharkoon","Headset"],["whispr","OpenWhispr"]]
    function rx(t) { try { return t ? new RegExp(t, "i") : null; } catch (e) { return null; } }
    readonly property var aliasList: { try { return JSON.parse(Plasmoid.configuration.aliases || "[]"); } catch (e) { return []; } }
    function aliasFor(text, fallback) {
        for (const a of aliasList) { const r = rx(a[0]); if (r && r.test(text)) return a[1]; }
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

    // Lesbare Gerätenamen
    function niceName(desc, mic) {
        const d = desc || "";
        return aliasFor(d, d);
    }

    // Mission Center öffnen (Flatpak)
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

        // ---- Auslöser am oberen Rand ----
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

        function open() {
            closeTimer.stop();
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
            onTriggered: {
                if (trigger.containsMouse || bodyHover.hovered || notesArea.activeFocus) return;
                rep.close();
            }
        }

        // ---- Das herausgleitende Fenster ----
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

                // Form mit nach innen gewölbten oberen Ecken
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

                // Inhalt, der mit dem Fenster herausgleitet
                Item {
                    x: root.inv
                    width: root.dashW
                    height: body.bh
                    clip: true

                    Item {
                        id: content
                        width: root.dashW
                        height: root.fullH
                        y: -(1 - root.reveal) * 40
                        opacity: Math.min(1, root.reveal * 1.8)

                        // Kategorien
                        Row {
                            id: tabs
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            spacing: 8

                            Repeater {
                                model: [
                                    { icon: "view-app-grid-symbolic", name: "Dashboard" },
                                    { icon: "audio-volume-high-symbolic", name: "Audio" },
                                    { icon: "speedometer", name: "System" },
                                    { icon: "document-edit-symbolic", name: "Notes" }
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
                            RowLayout {
                                spacing: 12

                                // Uhr und Datum
                                Rectangle {
                                    Layout.preferredWidth: 220
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: root.cCard

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 30
                                        spacing: 4
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.locale("en_US").toString(root.now, "hh:mm")
                                            color: root.cText
                                            font.pixelSize: 62
                                            font.bold: true
                                        }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 40; height: 4; radius: 2
                                            color: root.accent
                                        }
                                        Item { width: 1; height: 4 }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.locale("en_US").toString(root.now, "dddd")
                                            color: root.cAccentSoft
                                            font.pixelSize: 18
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.locale("en_US").toString(root.now, "d MMMM yyyy")
                                            color: root.cDim
                                            font.pixelSize: 14
                                        }
                                    }
                                    // Spielende Katze: „Cat playing animation“ von Abdul Latif (LottieFiles, freie Lizenz)
                                    AnimatedImage {
                                        source: Qt.resolvedUrl("../images/cat-playing.webp")
                                        width: 200; height: 63
                                        fillMode: Image.PreserveAspectFit
                                        playing: root.reveal > 0
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 14
                                    }
                                }

                                // Kalender
                                Rectangle {
                                    Layout.preferredWidth: 236
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: root.cCard

                                    readonly property int year: root.now.getFullYear()
                                    readonly property int month: root.now.getMonth()
                                    readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7
                                    readonly property int days: new Date(year, month + 1, 0).getDate()

                                    Text {
                                        id: monthTitle
                                        x: 16; y: 14
                                        text: Qt.locale("en_US").toString(root.now, "MMMM yyyy")
                                        color: root.cText
                                        font.pixelSize: 15
                                        font.bold: true
                                    }
                                    Grid {
                                        id: cal
                                        anchors.top: monthTitle.bottom
                                        anchors.topMargin: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        columns: 7
                                        rowSpacing: 3
                                        columnSpacing: 2
                                        readonly property int cell: 29

                                        Repeater {
                                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                            Text {
                                                width: cal.cell; height: 20
                                                horizontalAlignment: Text.AlignHCenter
                                                text: modelData
                                                color: root.cDim
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }
                                        Repeater {
                                            model: 42
                                            Rectangle {
                                                readonly property int day: index - cal.parent.offset + 1
                                                readonly property bool valid: day >= 1 && day <= cal.parent.days
                                                readonly property bool today: valid && day === root.now.getDate()
                                                width: cal.cell; height: 28
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
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12

                                    // Medien: rundes Bild mit Visualizer-Ring
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 168
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
                                                innerRadius: miniArt.width / 2 + 4
                                                maxLength: 20
                                                barWidth: 3
                                                color: root.cAccentSoft
                                            }
                                            Kirigami.ShadowedImage {
                                                id: miniArt
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
                                            anchors.left: artBox.right
                                            anchors.leftMargin: 2
                                            anchors.right: parent.right
                                            anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Text {
                                                width: parent.width
                                                text: root.player && root.player.track ? root.player.track : "Nothing playing"
                                                color: root.cText
                                                font.pixelSize: 14
                                                font.bold: true
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                width: parent.width
                                                text: root.player ? root.player.artist : ""
                                                color: root.cDim
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                            Row {
                                                spacing: 6
                                                topPadding: 8
                                                MediaButton { icon: "media-skip-backward"; onClicked: root.player && root.player.Previous() }
                                                MediaButton { icon: root.playing ? "media-playback-pause" : "media-playback-start"; big: true; size: 36; onClicked: root.player && root.player.PlayPause() }
                                                MediaButton { icon: "media-skip-forward"; onClicked: root.player && root.player.Next() }
                                            }
                                        }
                                    }

                                    // Standby + Leistung kurz
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 20
                                        color: root.cCard

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            Rectangle {
                                                width: parent.width
                                                height: 32
                                                radius: height / 2
                                                color: root.inhibitCookie >= 0 ? root.accent : (sbMouse.containsMouse ? root.cCard2 : Qt.alpha(root.cCard2, 0.6))
                                                Behavior on color { ColorAnimation { duration: 160 } }
                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 8
                                                    Kirigami.Icon {
                                                        source: root.inhibitCookie >= 0 ? "system-suspend-inhibited" : "system-suspend"
                                                        width: 16; height: 16
                                                        isMask: true
                                                        color: root.inhibitCookie >= 0 ? "white" : root.cText
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Text {
                                                        text: root.inhibitCookie >= 0 ? "Sleep inhibited" : "Sleep allowed"
                                                        color: root.inhibitCookie >= 0 ? "white" : root.cText
                                                        font.pixelSize: 13
                                                        font.bold: root.inhibitCookie >= 0
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                                MouseArea {
                                                    id: sbMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.toggleStandby()
                                                }
                                            }
                                            Bar { label: "CPU"; value: root.num(sCpu) }
                                            Bar { label: "GPU"; value: root.num(sGpu) }
                                            Bar { label: "RAM"; value: root.num(sRam) }
                                        }
                                    }
                                }
                            }

                            // ===== Audio =====
                            RowLayout {
                                spacing: 12

                                // Ausgabe und Mikrofon
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

                                // Programme, die gerade Ton abspielen
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 20
                                    color: root.cCard

                                    SectionTitle {
                                        id: appsTitle
                                        x: 14; y: 14
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

                            // ===== Leistung =====
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

                            // ===== Notizen =====
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
                        }
                    }
                }
            }
        }
    }

    // ---- kleine Bausteine ----
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

    component SectionTitle: Text {
        color: root.cText
        font.pixelSize: 14
        font.bold: true
    }

    // Lautstärkeregler mit Stumm-Knopf und Prozentanzeige
    component VolSlider: Item {
        id: vs
        property real value: 0          // 0..1
        property bool muted: false
        property bool mic: false
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
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 6; radius: 3
                color: root.cCard2
                Rectangle {
                    height: parent.height; radius: 3
                    width: parent.width * Math.max(0, Math.min(1, vs.shown))
                    color: vs.muted ? root.cDim : root.accent
                }
            }
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(1, vs.shown)) * (parent.width - width)
                color: "white"
                visible: drag.containsMouse || drag.pressed
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

    // Ausgabegerät oder Mikrofon: Klick macht es zum Standard, darunter Lautstärke
    component DeviceRow: Rectangle {
        id: dr
        property bool mic: false
        readonly property bool isMonitor: String(model.Name || "").indexOf(".monitor") >= 0
        // optional filters: outputs matching outputExclude are hidden, only mics matching inputInclude are shown
        readonly property string desc: String(model.Description || "")
        readonly property var ex: root.rx(Plasmoid.configuration.outputExclude)
        readonly property var inc: root.rx(Plasmoid.configuration.inputInclude)
        readonly property bool wanted: mic ? (!inc || inc.test(desc)) : (!ex || !ex.test(desc))
        visible: !isMonitor && wanted
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
            text: root.niceName(model.Description, dr.mic)
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
            value: model.Volume / 65536
            muted: model.Muted
            onMoved: v => model.PulseObject.volume = Math.round(v * 65536)
            onMuteToggled: model.PulseObject.muted = !model.Muted
        }
    }

    // Programm, das gerade Ton abspielt (alle seine Streams gemeinsam)
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
