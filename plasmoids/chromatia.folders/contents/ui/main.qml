// Chromatia folders – app folders in the bar, like folders on an Android home screen.
//
// Click a folder: it grows out of the bar like the dashboard notch, click an app to start it.
// It closes by itself 2.5 s after the mouse left it. Fill it with the + at the top right (search over
// all apps) or drag apps from the launcher or Dolphin onto it. In the open folder: click the icon to
// change it, the name to rename it. Right click a folder: icon, new folder, delete. Hover an app: × removes it.

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

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

    // ---- Sizes ----
    readonly property int tile: Math.max(20, Math.round(root.height * 0.9))   // folder in the bar
    readonly property int cellW: 92
    readonly property int cellH: 96
    readonly property int pad: 14
    readonly property int headH: 46
    readonly property int inv: 24      // inward curved corner at the bar, like the notch
    readonly property int rad: 28

    // ---- Data: [{name, icon, apps: [{file, name, icon}]}] as JSON in the config (no icon: mini app icons) ----
    readonly property var folders: parse(Plasmoid.configuration.folders)
    function parse(s) { try { const f = JSON.parse(s); return Array.isArray(f) ? f : []; } catch (e) { return []; } }
    function edit(fn) { const f = JSON.parse(JSON.stringify(folders)); fn(f); Plasmoid.configuration.folders = JSON.stringify(f); }
    function has(fi, file) { return !!folders[fi] && folders[fi].apps.some(a => a.file === file); }
    function setIcon(fi, icon) { edit(f => f[fi].icon = icon); }
    function isSymbolic(icon) { return String(icon).endsWith("-symbolic"); }
    function toggleApp(fi, a) {
        edit(f => { const i = f[fi].apps.findIndex(x => x.file === a.file); i < 0 ? f[fi].apps.push(a) : f[fi].apps.splice(i, 1); });
    }

    property int current: -1
    readonly property var apps: folders[current] ? folders[current].apps : []
    property bool searching: false
    property string query: ""
    property var allApps: []
    readonly property var results: allApps.filter(a => a.name.toLowerCase().includes(query.toLowerCase()))

    // ---- Shell helpers: app list (chromatia-apps) and launching (kioclient, KDE's own app launcher) ----
    readonly property string tool: "\"$HOME/.local/bin/chromatia-apps\""
    property var pending: ({})
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function run(cmd, cb) { pending[cmd] = cb; sh.connectSource(cmd); }
    P5Support.DataSource {
        id: sh
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            const cb = root.pending[source];
            delete root.pending[source];
            if (cb) cb(data.stdout);
        }
    }
    function json(s) { try { return JSON.parse(s); } catch (e) { return []; } }
    function loadApps() { run(tool, out => allApps = json(out)); }
    function launch(a) { run("kioclient exec " + q(a.file) + " #" + Date.now(), null); close(); }   // unique: the same app twice in a row

    // dropped from the launcher (applications: URLs), Dolphin or the desktop: apps, folders, files
    function addUrls(fi, urls) {
        const files = [];
        for (let u of urls) {
            u = String(u);
            if (u.startsWith("applications:")) {
                const a = allApps.find(x => x.file.endsWith("/" + u.slice(13)));
                if (a) files.push(a.file);
            } else if (u.startsWith("file://") || u.startsWith("desktop:/")) files.push(u);   // chromatia-apps resolves them
        }
        if (files.length) run(tool + " " + files.map(q).join(" "), out => json(out).forEach(a => { if (!has(fi, a.file)) toggleApp(fi, a); }));
    }

    // ---- Open / close ----
    property real reveal: 0
    property bool shown: false
    property Item anchorItem: null
    property double closedAt: 0
    property bool popupHovered: false
    property bool tileHovered: false

    // closes by itself once the mouse has been away from the folder and its tile for a moment
    Timer {
        interval: 2500
        running: root.shown && !root.popupHovered && !root.tileHovered && !iconDialog.visible
        onTriggered: root.close()
    }

    function toggle(i, item) {
        if (shown && current === i) return close();
        if (current === i && Date.now() - closedAt < 300) return;   // this click just closed it by taking the focus
        current = i; anchorItem = item; searching = false; query = ""; popupHovered = false;
        shown = true;
        drawer.visible = true;
        drawer.requestActivate();
        anim.stop(); anim.to = 1; anim.duration = 340; anim.easing.type = Easing.OutQuint; anim.start();
    }
    function close() {
        if (!shown) return;
        shown = false; closedAt = Date.now();
        anim.stop(); anim.to = 0; anim.duration = 220; anim.easing.type = Easing.InCubic; anim.start();
    }
    function startSearch() { query = ""; searching = true; loadApps(); search.forceActiveFocus(); }
    function endSearch() { searching = false; body.forceActiveFocus(); }

    NumberAnimation {
        id: anim; target: root; property: "reveal"
        onFinished: if (root.reveal <= 0.001) { drawer.visible = false; root.searching = false; }
    }

    Component.onCompleted: loadApps()

    KIconThemes.IconDialog {
        id: iconDialog
        property int folder: -1
        onAccepted: Qt.callLater(() => { if (iconName) root.setIcon(folder, iconName); })   // after iconName is updated
        onVisibleChanged: if (!visible && root.shown) drawer.requestActivate()   // keep closing on outside clicks
    }
    function pickIcon(fi) { iconDialog.folder = fi; iconDialog.open(); }   // iconName is read-only, no preselection

    PlasmaExtras.Menu {
        id: menu
        property int folder: -1
        PlasmaExtras.MenuItem { text: "Change icon…"; icon: "preferences-desktop-icons"; onClicked: root.pickIcon(menu.folder) }
        PlasmaExtras.MenuItem {
            text: "Show app icons instead"; icon: "view-grid-symbolic"
            visible: !!root.folders[menu.folder] && !!root.folders[menu.folder].icon
            onClicked: root.setIcon(menu.folder, "")
        }
        PlasmaExtras.MenuItem { text: "New folder"; icon: "folder-new"; onClicked: root.edit(f => f.push({ name: "Folder " + (f.length + 1), apps: [] })) }
        PlasmaExtras.MenuItem {
            text: "Delete folder"; icon: "edit-delete"
            onClicked: { if (root.current === menu.folder) root.close(); root.current = -1; root.edit(f => f.splice(menu.folder, 1)); }
        }
    }

    // ---- The bar: one tile per folder, its own icon or up to four mini app icons ----
    fullRepresentation: Item {
        Layout.preferredWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(root.tile * 0.25)

            Repeater {
                model: root.folders

                Rectangle {
                    id: tile
                    readonly property var folder: modelData
                    readonly property bool open: root.shown && root.current === index
                    width: root.tile; height: root.tile
                    radius: Math.round(width * 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                    color: open ? Qt.alpha(root.accent, 0.42)
                                : Qt.alpha(Kirigami.Theme.textColor, (mouse.containsMouse || drop.containsDrag) ? 0.22 : 0.10)
                    border.width: drop.containsDrag ? 2 : 0
                    border.color: root.accent
                    scale: drop.containsDrag ? 1.12 : 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

                    Kirigami.Icon {
                        visible: !!tile.folder.icon
                        anchors.centerIn: parent
                        width: Math.round(tile.width * 0.72); height: width
                        source: tile.folder.icon || ""
                        isMask: root.isSymbolic(source)
                        color: root.cText
                    }
                    Grid {
                        visible: !tile.folder.icon
                        anchors.centerIn: parent
                        columns: 2
                        spacing: Math.round(tile.width * 0.07)
                        Repeater {
                            model: tile.folder.apps.slice(0, 4)
                            Kirigami.Icon { width: Math.round(tile.width * 0.33); height: width; source: modelData.icon }
                        }
                    }
                    Kirigami.Icon {
                        visible: !tile.folder.icon && tile.folder.apps.length === 0
                        anchors.centerIn: parent
                        width: Math.round(tile.width * 0.55); height: width
                        source: "folder-symbolic"
                        isMask: true
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.85)
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onContainsMouseChanged: root.tileHovered = containsMouse
                        onClicked: m => {
                            if (m.button === Qt.LeftButton) return root.toggle(index, tile);
                            menu.folder = index; menu.visualParent = tile; menu.openRelative();
                        }
                    }
                    DropArea {
                        id: drop
                        anchors.fill: parent
                        onDropped: d => { if (d.hasUrls) root.addUrls(index, d.urls); }
                    }
                }
            }
            // no folders left: a plus to start again
            Rectangle {
                visible: root.folders.length === 0
                width: root.tile; height: root.tile; radius: Math.round(width * 0.3)
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Kirigami.Theme.textColor, plusMouse.containsMouse ? 0.22 : 0.06)
                Kirigami.Icon { anchors.centerIn: parent; width: Math.round(parent.width * 0.5); height: width; source: "list-add-symbolic"; isMask: true; color: root.cText }
                MouseArea { id: plusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.edit(f => f.push({ name: "Apps", apps: [] })) }
            }
        }
    }

    // ---- The open folder: grows out of the bar ----
    PlasmaCore.Dialog {
        id: drawer
        visualParent: root.anchorItem
        location: PlasmaCore.Types.BottomEdge
        type: PlasmaCore.Dialog.Normal
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: false
        onActiveChanged: if (!active && !iconDialog.visible) root.close()

        mainItem: Item {
            id: body
            readonly property int cols: root.searching ? 5 : Math.min(5, Math.max(3, root.apps.length))
            readonly property int rows: root.searching ? 3 : Math.max(1, Math.ceil(root.apps.length / cols))
            readonly property int innerW: cols * root.cellW + 2 * root.pad
            readonly property int innerH: root.headH + rows * root.cellH + 2 * root.pad
            readonly property real bh: Math.max(root.inv + root.rad + 2, height * root.reveal)
            width: innerW + 2 * root.inv
            height: innerH
            focus: true
            Keys.onEscapePressed: root.searching ? root.endSearch() : root.close()
            HoverHandler { onHoveredChanged: root.popupHovered = hovered }

            // shape with rounded top corners and inward curves where it meets the bar
            Shape {
                anchors.bottom: parent.bottom
                width: parent.width; height: body.bh
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.cBase
                    strokeColor: "transparent"
                    PathSvg {
                        readonly property real w: body.width
                        readonly property real h: body.bh
                        readonly property real ri: root.inv
                        readonly property real ro: root.rad
                        path: `M0,${h} A${ri},${ri} 0 0 0 ${ri},${h - ri} L${ri},${ro} A${ro},${ro} 0 0 1 ${ri + ro},0 `
                            + `L${w - ri - ro},0 A${ro},${ro} 0 0 1 ${w - ri},${ro} L${w - ri},${h - ri} A${ri},${ri} 0 0 0 ${w},${h} Z`
                    }
                }
            }

            // content that slides up with the shape
            Item {
                x: root.inv
                anchors.bottom: parent.bottom
                width: body.innerW
                height: body.bh
                clip: true

                Item {
                    id: content
                    width: body.innerW
                    height: body.innerH
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -(1 - root.reveal) * 40
                    opacity: Math.min(1, root.reveal * 1.8)

                    // header: folder icon (click: change) and name, or the search field
                    Rectangle {
                        id: iconBtn
                        visible: !root.searching
                        x: root.pad; y: root.pad
                        width: root.headH - 8; height: width; radius: width / 2
                        color: iconMouse.containsMouse ? root.cCard2 : root.cCard
                        readonly property string icon: root.folders[root.current] && root.folders[root.current].icon || "folder-symbolic"
                        Kirigami.Icon { anchors.centerIn: parent; width: 22; height: 22; source: iconBtn.icon; isMask: root.isSymbolic(iconBtn.icon); color: root.cText }
                        MouseArea { id: iconMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pickIcon(root.current) }
                    }
                    TextInput {
                        id: title
                        visible: !root.searching
                        x: iconBtn.x + iconBtn.width + 10; y: root.pad
                        width: parent.width - x - root.headH - root.pad; height: root.headH - 8
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.folders[root.current] ? root.folders[root.current].name : ""
                        color: root.cText
                        selectionColor: root.accent
                        font.pixelSize: 20; font.bold: true
                        maximumLength: 30
                        onEditingFinished: if (text.trim() !== "" && root.folders[root.current] && text !== root.folders[root.current].name) { const t = text.trim(); root.edit(f => f[root.current].name = t); }
                        Keys.onEscapePressed: { text = root.folders[root.current].name; body.forceActiveFocus(); }
                        HoverHandler { cursorShape: Qt.IBeamCursor }
                    }
                    Rectangle {
                        visible: root.searching
                        x: root.pad; y: root.pad
                        width: parent.width - 2 * root.pad - root.headH; height: root.headH - 8
                        radius: height / 2
                        color: root.cCard
                        border.width: 1; border.color: Qt.alpha(root.accent, search.activeFocus ? 0.6 : 0.2)
                        Kirigami.Icon { id: lens; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; source: "search-symbolic"; isMask: true; color: root.cDim }
                        TextInput {
                            id: search
                            anchors { left: lens.right; leftMargin: 8; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            color: root.cText
                            selectionColor: root.accent
                            font.pixelSize: 14
                            text: root.query
                            onTextChanged: root.query = text
                            Keys.onReturnPressed: if (root.results.length) root.toggleApp(root.current, root.results[0])
                            Keys.onEscapePressed: root.endSearch()
                            Text { visible: !search.text; text: "Search apps…"; color: root.cDim; font: search.font }
                        }
                    }
                    // top right corner: + opens the search, ✓ ends it
                    Rectangle {
                        x: parent.width - root.pad - width; y: root.pad + (root.headH - 8 - height) / 2
                        width: root.searching ? root.headH - 8 : 28; height: width; radius: width / 2
                        color: cornerMouse.containsMouse ? root.accent : root.cCard2
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: root.searching ? 18 : 14; height: width
                            source: root.searching ? "dialog-ok-apply-symbolic" : "list-add-symbolic"
                            isMask: true; color: root.cText
                        }
                        MouseArea { id: cornerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.searching ? root.endSearch() : root.startSearch() }
                    }

                    // the apps of the folder
                    Text {
                        visible: !root.searching && root.apps.length === 0
                        x: root.pad; y: root.pad + root.headH
                        width: body.cols * root.cellW; height: root.cellH
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        text: "Empty. Add apps with + or drop them onto the folder."
                        color: root.cDim; font.pixelSize: 13
                    }
                    Grid {
                        visible: !root.searching
                        x: root.pad; y: root.pad + root.headH
                        columns: body.cols
                        Repeater {
                            model: root.apps
                            AppCell {
                                app: modelData
                                removable: true
                                onClicked: root.launch(modelData)
                                onRemoveClicked: root.toggleApp(root.current, modelData)
                            }
                        }
                    }

                    // search results: click adds or removes, a check marks what is already in the folder
                    GridView {
                        visible: root.searching
                        x: root.pad; y: root.pad + root.headH
                        width: body.cols * root.cellW; height: body.rows * root.cellH
                        cellWidth: root.cellW; cellHeight: root.cellH
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.searching ? root.results : []
                        delegate: AppCell {
                            app: modelData
                            checked: root.has(root.current, modelData.file)
                            onClicked: root.toggleApp(root.current, modelData)
                        }
                    }
                }
            }
        }
    }

    component AppCell: Item {
        id: cell
        property var app
        property bool checked: false
        property bool removable: false
        signal clicked()
        signal removeClicked()
        width: root.cellW; height: root.cellH

        Rectangle {
            anchors.fill: parent; anchors.margins: 3
            radius: 16
            color: cell.checked ? Qt.alpha(root.accent, 0.30) : (cellMouse.containsMouse ? root.cCard2 : "transparent")
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Kirigami.Icon {
            id: ic
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            width: 46; height: width
            source: cell.app ? cell.app.icon : ""
            scale: cellMouse.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
        }
        Text {
            anchors { top: parent.top; topMargin: 64; left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
            text: cell.app ? cell.app.name : ""
            color: root.cText
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Kirigami.Icon {
            visible: cell.checked
            anchors { top: parent.top; right: parent.right; margins: 8 }
            width: 16; height: 16
            source: "checkmark-symbolic"; isMask: true; color: root.accent
        }
        MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cell.clicked()
        }
        // remove: a small × in the corner while hovering (above the click area)
        Rectangle {
            visible: cell.removable
            opacity: cellMouse.containsMouse || xMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            anchors { top: parent.top; right: parent.right; margins: 6 }
            width: 20; height: 20; radius: 10
            color: xMouse.containsMouse ? "#e5484d" : root.cCard
            Kirigami.Icon { anchors.centerIn: parent; width: 12; height: 12; source: "window-close-symbolic"; isMask: true; color: root.cText }
            MouseArea { id: xMouse; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cell.removeClicked() }
        }
    }
}
