import org.kde.plasma.configuration

// Chromatia Settings – opened from the gear in the dashboard (or right-click → Configure)
ConfigModel {
    ConfigCategory {
        name: "Colors"
        icon: "color-management"
        source: "configColors.qml"
    }
    ConfigCategory {
        name: "Wallpaper"
        icon: "preferences-desktop-wallpaper"
        source: "configWallpaper.qml"
    }
    ConfigCategory {
        name: "Bar"
        icon: "view-app-grid-symbolic"
        source: "configBar.qml"
    }
    ConfigCategory {
        name: "Dashboard"
        icon: "view-grid-symbolic"
        source: "configDashboard.qml"
    }
    ConfigCategory {
        name: "Audio"
        icon: "audio-volume-high"
        source: "configAudio.qml"
    }
    ConfigCategory {
        name: "Notifications"
        icon: "preferences-desktop-notification-bell"
        source: "configNotifications.qml"
    }
    ConfigCategory {
        name: "About & Updates"
        icon: "help-about"
        source: "configAbout.qml"
    }
}
