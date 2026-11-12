import org.kde.plasma.configuration

// Chromatia Settings – opened from the gear in the dashboard (or right-click → Configure)
ConfigModel {
    ConfigCategory {
        name: "Colors"
        icon: "color-management"
        source: "configColors.qml"
    }
    ConfigCategory {
        name: "Audio"
        icon: "audio-volume-high"
        source: "configAudio.qml"
    }
    ConfigCategory {
        name: "About & Updates"
        icon: "help-about"
        source: "configAbout.qml"
    }
}
