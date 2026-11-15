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
        QQC2.CheckBox {
            text: "While the screen is locked"
            checked: page.cfg_pauseWhenLocked
            onToggled: page.cfg_pauseWhenLocked = checked
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Save power:"
            text: "Play videos at 30 fps"
            checked: page.cfg_videoLite
            onToggled: page.cfg_videoLite = checked
        }
        QQC2.CheckBox {
            text: "Videos only on the main screen (still image on the others)"
            checked: page.cfg_videoMainOnly
            onToggled: page.cfg_videoMainOnly = checked
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Smoother videos (60 fps) get a 30 fps copy in the background, made once per video (needs ffmpeg). Every screen with a video decodes it on its own, so a still image on the side screens saves even more. A video wallpaper costs about as much power as playing a video."
        }
    }
}
