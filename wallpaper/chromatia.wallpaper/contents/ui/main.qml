// Bild mit Visualizer – Hintergrundbild plus Audio-Balken entlang der unteren Leiste.
// Die Balken liegen auf der Hintergrundebene, also unter den Desktop-Symbolen.
// Sie erscheinen nur, wenn etwas abgespielt wird. Die Werte liefert der Helfer
// io.github.chromatia.Visualizer (cava), Farbe ist die Akzentfarbe des Systems.

import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtMultimedia
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.workspace.dbus

WallpaperItem {
    id: root

    readonly property color accent: (root.configuration.AccentColor !== "" ? root.configuration.AccentColor : Kirigami.Theme.highlightColor)

    // ---- Wechsel ohne sichtbares Ruckeln ----
    // Beim Wechsel bleibt das alte Video als Standbild stehen. Das neue lädt unsichtbar und läuft
    // schon an. Erst wenn das Skript fertig umgefärbt hat (SwitchGo == Image) und Plasma wieder
    // ruhig ist, blendet es weich über. Alle kurzen Hänger fallen so in eine Phase ohne Bewegung.
    property string shownSource: ""
    property bool frontIsA: true
    readonly property Item frontLayer: frontIsA ? imgA : imgB
    readonly property Item backLayer: frontIsA ? imgB : imgA
    property bool switching: false
    property string pendingSrc: ""
    property Item incoming: null
    readonly property string cfgImage: root.configuration.Image
    readonly property string cfgGo: root.configuration.SwitchGo
    onCfgImageChanged: showImage(cfgImage)
    onCfgGoChanged: tryGo()
    Component.onCompleted: {
        refreshDesk();
        imgA.live = true;
        if (root.configuration.Image) {
            root.loading = true;
            imgA.source = root.configuration.Image;
        }
        // Never block Plasma's startup: Plasma waits until the wallpaper reports "loaded".
        // Without an image (fresh install) or with a broken file we report "done" right away.
    }
    Timer { interval: 5000; running: root.loading; onTriggered: root.loading = false }   // safety net

    // Fallback when no wallpaper is set or it fails to load: soft gradient in the accent color
    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.hsla(Math.max(0, root.accent.hslHue), 0.35, 0.22, 1) }
            GradientStop { position: 1.0; color: Qt.hsla(Math.max(0, root.accent.hslHue), 0.30, 0.08, 1) }
        }
    }

    function showImage(src) {
        if (!src) return;
        if (fade.running || goTimer.running) { pendingSrc = src; return; }
        if (src === shownSource) {                 // zurück zum aktuellen Bild: einfach weiterlaufen
            switching = false; fallbackTimer.stop(); frontLayer.live = true; return;
        }
        switching = true;
        frontLayer.live = false;                   // altes Video als Standbild anhalten
        fallbackTimer.restart();
        const back = backLayer;
        back.live = false;
        back.opacity = 0;
        if (back.source === src && back.isReady) { tryGo(); return; }
        back.source = src;
    }
    function layerReady(layer, ok) {
        root.loading = false;
        if (layer === frontLayer) { shownSource = layer.source; return; }   // erster Start
        if (!ok) { switching = false; frontLayer.live = true; return; }
        tryGo();
    }
    function tryGo() {
        if (!switching || fade.running || goTimer.running) return;
        const back = backLayer;
        if (back.source !== cfgImage || !back.isReady) return;
        if (cfgGo !== cfgImage && fallbackTimer.running) return;     // Skript färbt noch um
        fallbackTimer.stop();
        incoming = back;
        incoming.live = true;                      // neues Video läuft unsichtbar an
        goTimer.restart();
    }
    Timer { id: fallbackTimer; interval: 4000; onTriggered: root.tryGo() }   // falls kein SwitchGo kommt
    Timer { id: goTimer; interval: 450; onTriggered: { fade.target = root.incoming; fade.start(); } }
    NumberAnimation {
        id: fade
        property: "opacity"
        from: 0; to: 1
        duration: 700
        easing.type: Easing.InOutQuad
        onFinished: {
            const old = root.frontLayer;
            root.frontIsA = (root.incoming === imgA);
            old.opacity = 0;
            old.live = false;
            root.shownSource = root.incoming.source;
            root.switching = false;
            if (root.pendingSrc !== "") { const s2 = root.pendingSrc; root.pendingSrc = ""; root.showImage(s2); }
        }
    }

    // ---- Verdeckt? (maximiertes oder Vollbild-Fenster auf diesem Bildschirm) ----
    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: activityInfo }
    property var deskId: vd.currentDesktop
    readonly property string myScreen: Screen.name
    readonly property rect myScreenRect: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
    onMyScreenChanged: refreshDesk()
    function refreshDesk() {
        const d = vd.currentDesktopByScreenName(root.myScreen);
        deskId = (d !== undefined && d !== null && d !== "") ? d : vd.currentDesktop;
    }
    Connections {
        target: vd
        function onCurrentDesktopChanged() { root.refreshDesk(); }
        function onCurrentDesktopForScreenChanged(name) { root.refreshDesk(); }
    }
    TaskManager.TasksModel {
        id: onScreen
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: true
        screenGeometry: root.myScreenRect
        filterByVirtualDesktop: true
        virtualDesktop: root.deskId
        filterByActivity: true
        activity: activityInfo.currentActivity
    }
    property int coverCount: 0
    Timer { id: coverTimer; interval: 250; onTriggered: {
        let n = 0;
        for (let i = 0; i < coverRep.count; i++) { const it = coverRep.itemAt(i); if (it && it.cov) n++; }
        root.coverCount = n;
    } }
    Repeater {
        id: coverRep
        model: onScreen
        delegate: Item {
            readonly property bool cov: model.IsMinimized !== true && (model.IsMaximized === true || model.IsFullScreen === true)
            onCovChanged: coverTimer.restart()
            Component.onCompleted: coverTimer.restart()
            Component.onDestruction: coverTimer.restart()
        }
    }
    readonly property bool covered: root.configuration.PauseWhenCovered && coverCount > 0

    // Eine Ebene zeigt entweder ein Bild oder ein Video (stumm, in Endlosschleife)
    component Layer: Item {
        id: lay
        anchors.fill: parent
        property string source: ""
        property bool live: false          // darf das Video laufen?
        property bool isReady: false
        readonly property bool isVideo: /\.(mp4|webm|mkv|mov|m4v)$/i.test(source)
        signal done(bool ok)
        onSourceChanged: isReady = false

        Image {
            anchors.fill: parent
            visible: !lay.isVideo
            source: lay.isVideo ? "" : lay.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            onStatusChanged: {
                if (status === Image.Ready) { lay.isReady = true; lay.done(true); }
                else if (status === Image.Error) lay.done(false);
            }
        }
        Loader {
            anchors.fill: parent
            active: lay.isVideo && lay.source !== ""
            sourceComponent: Item {
                VideoOutput { id: vo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
                Connections {
                    target: vo.videoSink
                    function onVideoFrameChanged() {
                        if (mp.gotFrame) return;
                        mp.gotFrame = true;
                        if (!mp.want) mp.pause();
                        lay.isReady = true; lay.done(true);
                    }
                }
                MediaPlayer {
                    id: mp
                    source: lay.source
                    loops: MediaPlayer.Infinite
                    videoOutput: vo
                    readonly property bool want: lay.live && !root.covered
                    property bool gotFrame: false
                    onSourceChanged: gotFrame = false
                    onWantChanged: if (gotFrame) { want ? play() : pause(); }
                    onMediaStatusChanged: {
                        if (mediaStatus === MediaPlayer.LoadedMedia && !lay.isReady) {
                            play();                       // erst ein Bild zeichnen lassen, dann ggf. pausieren
                        } else if (mediaStatus === MediaPlayer.InvalidMedia) lay.done(false);
                    }
                }
            }
        }
    }

    Layer {
        id: imgA
        opacity: 1
        z: root.frontLayer === imgA ? 1 : 2       // die hereinkommende Ebene liegt oben
        onDone: ok => root.layerReady(imgA, ok)
    }
    Layer {
        id: imgB
        opacity: 0
        z: root.frontLayer === imgB ? 1 : 2
        onDone: ok => root.layerReady(imgB, ok)
    }

    // ---- Rahmen als Ebene (gleiche Farbe wie die Leiste) ----
    Shape {
        id: frame
        anchors.fill: parent
        z: 5
        visible: root.configuration.FrameBottom > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real fl: root.configuration.FrameLeft
        readonly property real fr: root.configuration.FrameRight
        readonly property real ft: root.configuration.FrameTop
        readonly property real fb: root.configuration.FrameBottom
        readonly property real rr: root.configuration.FrameRadius
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: Qt.hsla(Math.max(0, root.accent.hslHue), 0.25, 0.075, 1)
            strokeColor: "transparent"
            PathSvg {
                readonly property real w: frame.width
                readonly property real h: frame.height
                readonly property real x1: frame.fl
                readonly property real y1: frame.ft
                readonly property real x2: frame.width - frame.fr
                readonly property real y2: frame.height - frame.fb
                readonly property real r: frame.rr
                path: `M0,0 L${w},0 L${w},${h} L0,${h} Z `
                    + `M${x1 + r},${y1} L${x2 - r},${y1} A${r},${r} 0 0 1 ${x2},${y1 + r} `
                    + `L${x2},${y2 - r} A${r},${r} 0 0 1 ${x2 - r},${y2} L${x1 + r},${y2} `
                    + `A${r},${r} 0 0 1 ${x1},${y2 - r} L${x1},${y1 + r} A${r},${r} 0 0 1 ${x1 + r},${y1} Z`
            }
        }
    }

    // ---- Audio ----
    Mpris.Mpris2Model { id: mpris }
    readonly property bool playing: !!mpris.currentPlayer
        && mpris.currentPlayer.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool active: root.configuration.VisualizerEnabled && playing
    property var values: []

    Timer {
        interval: 40
        repeat: true
        running: root.active
        onRunningChanged: if (!running) root.values = []
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
                if (!reply.isError) root.values = Array.from(reply.value);
                reply.destroy();
            });
        }
    }

    // ---- Balken: gespiegelt, tiefe Töne in der Mitte ----
    Item {
        id: bars
        z: 10                          // über beiden Bildebenen der Überblendung
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 44
        anchors.rightMargin: 44
        anchors.bottomMargin: root.configuration.BottomOffset
        height: root.configuration.BarHeight
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        visible: opacity > 0

        readonly property int half: 48
        readonly property int count: half * 2
        readonly property real slot: width / count

        Repeater {
            model: bars.count
            Rectangle {
                // Index links der Mitte spiegeln: Mitte = tiefe Frequenzen
                readonly property int src: index < bars.half ? (bars.half - 1 - index) : (index - bars.half)
                readonly property real v: (root.values && root.values.length > src) ? root.values[src] : 0
                x: index * bars.slot + bars.slot * 0.2
                width: bars.slot * 0.6
                height: 3 + v * bars.height
                anchors.bottom: parent.bottom
                radius: width / 2
                // Akzentfarbe aus dem Hintergrundbild
                color: root.accent
                opacity: 0.45 + 0.45 * v
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
}
