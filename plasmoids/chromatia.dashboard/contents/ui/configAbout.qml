// Chromatia Settings – About & Updates
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

ConfigPage {
    id: page

    property var info: ({})
    property string phase: "checking"      // checking, done, running, error
    readonly property string updater: "\"$HOME/.local/bin/chromatia-update\""

    P5Support.DataSource {
        id: run
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            let r = null;
            try { r = JSON.parse(data.stdout); } catch (e) { page.phase = "error"; return; }
            if (source.indexOf("--check") >= 0) { page.info = r; page.phase = "done"; }
            else { page.phase = r.ok ? "running" : "error"; if (!r.ok) page.info = Object.assign({}, page.info, { error: r.error }); }
        }
    }
    function check() { phase = "checking"; run.connectSource(updater + " --check"); }
    Component.onCompleted: check()

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { text: "Chromatia " + (page.info.installed || ""); level: 2 }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "A KDE Plasma desktop that takes its colors from your wallpaper.\nhttps://github.com/xAFKevinX/Chromatia"
        }

        Kirigami.Separator { Layout.fillWidth: true }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.bold: true
            text: page.phase === "checking" ? "Checking for updates…"
                : page.phase === "running" ? "Updating… Plasma restarts in a moment."
                : page.info.error ? page.info.error
                : page.info.available ? ("Version " + page.info.latest + " is available.")
                : "Chromatia is up to date."
        }

        Repeater {
            model: page.info.available ? (page.info.changes || []) : []
            ColumnLayout {
                Layout.fillWidth: true
                QQC2.Label { text: modelData.version; font.bold: true; color: Kirigami.Theme.highlightColor }
                Repeater {
                    model: modelData.items
                    QQC2.Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "•  " + modelData }
                }
            }
        }

        RowLayout {
            QQC2.Button {
                text: "Check now"
                icon.name: "view-refresh"
                enabled: page.phase !== "checking" && page.phase !== "running"
                onClicked: page.check()
            }
            QQC2.Button {
                visible: page.info.available === true
                text: "Update now"
                icon.name: "update-none"
                highlighted: true
                enabled: page.phase === "done"
                onClicked: { page.phase = "running"; run.connectSource(page.updater + " --apply"); }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Updates only install when you click \"Update now\". Your panels and settings stay as they are."
        }
    }
}
