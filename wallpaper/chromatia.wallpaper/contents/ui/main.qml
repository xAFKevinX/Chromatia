// Chromatia wallpaper – image or video, the frame, and audio bars along the bottom bar.
// The bars live on the wallpaper layer, so they stay below the desktop icons.
// They only appear while something plays. The values come from the helper
// io.github.chromatia.Visualizer (cava), the color is the accent color.

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

    // ---- Switching without visible stutter ----
    // On a switch the old video freezes as a still. The new one loads invisibly and already
    // starts. Only when chromatia-sync has finished recoloring (SwitchGo == Image) and Plasma is
    // calm again does it crossfade. All short hitches fall into a moment without movement.
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
        if (src === shownSource) {                 // back to the current picture: just keep going
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
        if (layer === frontLayer) { shownSource = layer.source; return; }   // first start
        if (!ok) { switching = false; frontLayer.live = true; return; }
        tryGo();
    }
    function tryGo() {
        if (!switching || fade.running || goTimer.running) return;
        const back = backLayer;
        if (back.source !== cfgImage || !back.isReady) return;
        if (cfgGo !== cfgImage && fallbackTimer.running) return;     // chromatia-sync is still recoloring
        fallbackTimer.stop();
        incoming = back;
        incoming.live = true;                      // new video starts invisibly
        goTimer.restart();
    }
    Timer { id: fallbackTimer; interval: 4000; onTriggered: root.tryGo() }   // in case no SwitchGo arrives
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

    // ---- Covered? (windows on this screen) ----
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
    // Chromatia Settings → Wallpaper: pause for a maximized/fullscreen window, and/or when the
    // windows together fill the screen (e.g. two halves). Videos and visualizer bars both stop.
    property bool fullCover: false
    property bool tiledCover: false
    readonly property bool covered: (root.configuration.PauseWhenCovered && fullCover) || (root.configuration.PauseWhenTiled && tiledCover)
                                    || (root.configuration.PauseWhenLocked && locked)
    // screen locked (also after KDE's auto-lock when you're away): nothing of the desktop is visible
    property bool locked: false
    Timer {
        interval: 3000; repeat: true; triggeredOnStart: true
        running: root.configuration.PauseWhenLocked
        onRunningChanged: if (!running) root.locked = false
        onTriggered: {
            const reply = SessionBus.asyncCall({ "service": "org.freedesktop.ScreenSaver", "path": "/ScreenSaver",
                "iface": "org.freedesktop.ScreenSaver", "member": "GetActive", "signature": "()", "arguments": [] });
            reply.finished.connect(() => { if (!reply.isError) root.locked = !!reply.value; reply.destroy(); });
        }
    }
    Timer { id: coverTimer; interval: 250; onTriggered: {
        const rects = [];
        let full = false;
        for (let i = 0; i < coverRep.count; i++) {
            const it = coverRep.itemAt(i);
            if (it && it.shown) { full = full || it.big; rects.push(it.geo); }
        }
        root.fullCover = full;
        root.tiledCover = !full && root.filled(rects);
    } }
    // Is every pixel of the wallpaper inside the frame under a window? Only gaps up to 2 × tol px
    // between windows are ignored. Exact: the window edges cut the area into cells, each cell is checked.
    function filled(rects) {
        const c = root.configuration, s = myScreenRect, tol = 4;
        const L = s.x + c.FrameLeft, T = s.y + c.FrameTop, R = s.x + s.width - c.FrameRight, B = s.y + s.height - c.FrameBottom;
        const rs = rects.map(r => ({ l: r.x - tol, t: r.y - tol, r: r.x + r.width + tol, b: r.y + r.height + tol }));
        const xs = [L, R], ys = [T, B];
        for (const r of rs) { xs.push(r.l, r.r); ys.push(r.t, r.b); }
        const cut = (a, lo, hi) => a.filter(v => v >= lo && v <= hi).sort((p, q) => p - q);
        const cx = cut(xs, L, R), cy = cut(ys, T, B);
        for (let i = 0; i + 1 < cx.length; i++) for (let j = 0; j + 1 < cy.length; j++) {
            if (cx[i + 1] - cx[i] < 0.5 || cy[j + 1] - cy[j] < 0.5) continue;
            const x = (cx[i] + cx[i + 1]) / 2, y = (cy[j] + cy[j + 1]) / 2;
            if (!rs.some(r => x >= r.l && x < r.r && y >= r.t && y < r.b)) return false;
        }
        return true;
    }
    Repeater {
        id: coverRep
        model: onScreen
        delegate: Item {
            readonly property bool shown: model.IsMinimized !== true
            readonly property bool big: shown && (model.IsMaximized === true || model.IsFullScreen === true)
            readonly property rect geo: model.Geometry
            onShownChanged: coverTimer.restart()
            onBigChanged: coverTimer.restart()
            onGeoChanged: coverTimer.restart()
            Component.onCompleted: coverTimer.restart()
            Component.onDestruction: coverTimer.restart()
        }
    }

    // a layer shows either an image or a video (muted, looping)
    component Layer: Item {
        id: lay
        anchors.fill: parent
        property string source: ""
        property bool live: false          // may the video play?
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
                            play();                       // draw one frame first, then pause if needed
                        } else if (mediaStatus === MediaPlayer.InvalidMedia) lay.done(false);
                    }
                }
            }
        }
    }

    Layer {
        id: imgA
        opacity: 1
        z: root.frontLayer === imgA ? 1 : 2       // the incoming layer is on top
        onDone: ok => root.layerReady(imgA, ok)
    }
    Layer {
        id: imgB
        opacity: 0
        z: root.frontLayer === imgB ? 1 : 2
        onDone: ok => root.layerReady(imgB, ok)
    }

    // ---- Frame as a layer (same color as the bar) ----
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
        running: root.active && !root.covered          // hidden behind windows: no need to fetch bars
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

    // ---- Bars: mirrored, low notes in the middle ----
    Item {
        id: bars
        z: 10                          // above both layers of the crossfade
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 44
        anchors.rightMargin: 44
        anchors.bottomMargin: root.configuration.BottomOffset
        height: root.configuration.BarHeight
        opacity: root.active && !root.covered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        visible: opacity > 0

        readonly property int half: 48
        readonly property int count: half * 2
        readonly property real slot: width / count

        Repeater {
            model: bars.count
            Rectangle {
                // mirror the index left of the middle: middle = low frequencies
                readonly property int src: index < bars.half ? (bars.half - 1 - index) : (index - bars.half)
                readonly property real v: (root.values && root.values.length > src) ? root.values[src] : 0
                x: index * bars.slot + bars.slot * 0.2
                width: bars.slot * 0.6
                height: 3 + v * bars.height
                anchors.bottom: parent.bottom
                radius: width / 2
                // accent color from the wallpaper
                color: root.accent
                opacity: 0.45 + 0.45 * v
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
}
