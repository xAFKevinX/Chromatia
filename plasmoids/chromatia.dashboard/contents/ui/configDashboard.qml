// Chromatia Settings – Dashboard
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    id: page

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: "Quick toggles:"
            text: "Wi-Fi"
            checked: page.cfg_wifiToggle
            onToggled: page.cfg_wifiToggle = checked
        }
        QQC2.CheckBox {
            text: "Bluetooth"
            checked: page.cfg_bluetoothToggle
            onToggled: page.cfg_bluetoothToggle = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Round buttons next to the gear at the top of the dashboard. A button only appears if this computer has the hardware for it."
        }
    }
}
