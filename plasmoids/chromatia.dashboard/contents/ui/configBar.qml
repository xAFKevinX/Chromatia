// Chromatia Settings – Bar
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    id: page

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: "Islands:"
            text: "Lighter background behind the groups in the bar"
            checked: page.cfg_islands
            onToggled: page.cfg_islands = checked
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Launcher button:"
            text: "Show a button for the app launcher at the left end of the bar"
            checked: page.cfg_launcherButton
            onToggled: page.cfg_launcherButton = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "The launcher also opens with the Meta key, and with the bottom-left hot corner if you enabled it during installation (System Settings → Screen Edges)."
        }
    }
}
