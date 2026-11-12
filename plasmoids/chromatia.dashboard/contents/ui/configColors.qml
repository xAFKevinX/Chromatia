// Chromatia Settings – Colors: where the accent color comes from
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property int cfg_accentMode
    property string cfg_fixedAccent
    property bool cfg_systemAccent
    property bool cfg_appColors

    Kirigami.FormLayout {
        QQC2.RadioButton {
            Kirigami.FormData.label: "Accent color:"
            text: "From the wallpaper"
            checked: page.cfg_accentMode === 0
            onToggled: if (checked) page.cfg_accentMode = 0
        }
        RowLayout {
            QQC2.RadioButton {
                text: "Fixed color"
                checked: page.cfg_accentMode === 1
                onToggled: if (checked) page.cfg_accentMode = 1
            }
            QQC2.Button {
                enabled: page.cfg_accentMode === 1
                implicitWidth: Kirigami.Units.gridUnit * 4
                onClicked: colorDialog.open()
                contentItem: Rectangle {
                    radius: 4
                    color: page.cfg_fixedAccent
                    border.width: 1
                    border.color: Kirigami.Theme.textColor
                    opacity: parent.enabled ? 1 : 0.4
                }
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: "System:"
            text: "Also use it as the KDE accent color"
            checked: page.cfg_systemAccent
            onToggled: page.cfg_systemAccent = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Tints folder icons, highlights and other apps. Turn it off if an Electron app crashes when the color changes."
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Apps:"
            text: "Terminal (Konsole) uses the colors too"
            checked: page.cfg_appColors
            onToggled: page.cfg_appColors = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Adds the color scheme and profile \"Chromatia\" to Konsole and makes it the default (only if you have no default profile yet). New Konsole windows pick up the colors."
        }
    }

    ColorDialog {
        id: colorDialog
        selectedColor: page.cfg_fixedAccent
        onAccepted: page.cfg_fixedAccent = selectedColor.toString()
    }
}
