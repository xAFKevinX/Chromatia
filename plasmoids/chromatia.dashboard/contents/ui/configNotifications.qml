// Chromatia Settings – Notifications
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    id: page
    readonly property var mutedList: { try { return JSON.parse(cfg_muted || "[]"); } catch (e) { return []; } }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: "Popups:"
            text: "Chromatia style, sliding in at the top right"
            checked: page.cfg_chromatiaPopups
            onToggled: page.cfg_chromatiaPopups = checked
        }
        RowLayout {
            Kirigami.FormData.label: "Show for:"
            enabled: page.cfg_chromatiaPopups
            QQC2.SpinBox {
                from: 3; to: 30
                value: page.cfg_popupSeconds
                onValueModified: page.cfg_popupSeconds = value
            }
            QQC2.Label { text: "seconds (longer if an app asks for it)" }
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Fullscreen:"
            enabled: page.cfg_chromatiaPopups
            text: "No popups while a fullscreen app (game, video) is focused"
            checked: page.cfg_hideInFullscreen
            onToggled: page.cfg_hideInFullscreen = checked
        }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Dashboard:"
            text: "Open the Notifications tab first when something is unread"
            checked: page.cfg_openNotificationsFirst
            onToggled: page.cfg_openNotificationsFirst = checked
        }
        ColumnLayout {
            Kirigami.FormData.label: "Muted:"
            QQC2.Label { visible: page.mutedList.length === 0; text: "Nothing. Use the bell on a notification in the dashboard."; opacity: 0.7 }
            Repeater {
                model: page.mutedList
                RowLayout {
                    required property var modelData
                    required property int index
                    QQC2.Label { text: modelData.app + (modelData.summary ? " – “" + modelData.summary + "”" : " (all)") }
                    QQC2.Button {
                        text: "Unmute"
                        icon.name: "notifications-symbolic"
                        onClicked: { const l = page.mutedList.slice(); l.splice(index, 1); page.cfg_muted = JSON.stringify(l); }
                    }
                }
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Off: KDE's normal notification popups come back. Either way, all notifications are collected in the dashboard's Notifications tab, and a glowing pill in the notch tells you when something is unread. Per-app rules and sounds stay in System Settings → Notifications."
        }
    }
}
