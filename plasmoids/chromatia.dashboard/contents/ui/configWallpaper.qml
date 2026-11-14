// Chromatia Settings – Wallpaper: when video wallpapers and the visualizer pause
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigPage {
    id: page

    Kirigami.FormLayout {
        QQC2.CheckBox {
            Kirigami.FormData.label: "Pause:"
            text: "When a window is maximized or fullscreen"
            checked: page.cfg_pauseWhenCovered
            onToggled: page.cfg_pauseWhenCovered = checked
        }
        QQC2.CheckBox {
            text: "When windows together fill the screen (e.g. two side by side)"
            checked: page.cfg_pauseWhenTiled
            onToggled: page.cfg_pauseWhenTiled = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Video wallpapers and the visualizer bars stop while they are hidden behind windows, which saves power. Turn this off if you use transparent windows and want to keep seeing them move."
        }
    }
}
