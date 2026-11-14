# Changelog

## 1.4.2
- **Video wallpapers also pause when windows together fill the screen**, e.g. two side by side. New settings page **Wallpaper** (Chromatia Settings) to switch this and the pause for maximized windows on or off, for example if you use transparent windows.
- The visualizer bars on the wallpaper pause too while they are hidden behind windows.
- Saves power: the dashboard's clock and system sensors only update while the dashboard is open.
- All code comments are in English now.

## 1.4.1
- Fixed: the uninstaller left the notification script behind (KDE's popups stayed hidden afterwards) and kept chromatia-update.
- Opening Chromatia Settings no longer fills the Plasma log with warnings.
- Code cleanup: less duplicated code, unused parts removed. Nothing changes in how it looks or works.

## 1.4.0
- **Notifications**: new notifications slide out of the frame at the top right and slide back in after a few seconds (hover to keep them). Buttons and clicks work as usual.
- A glowing pill in the notch tells you when something is unread, in a signal color that matches your accent without being the same. All notifications are collected in the dashboard's new **Notifications** tab, with do-not-disturb.
- Settings → Notifications: Chromatia or KDE popups, how long they stay, no popups while a fullscreen app (game, video) is focused, open the Notifications tab first.
- Updating from an older version keeps KDE's bell in the tray; hide it in the tray settings if you like (Chromatia uses it in the background).

## 1.3.0
- **VS Code follows the wallpaper**: Chromatia sets workbench.colorCustomizations in your VS Code settings (only that key is touched, comments stay, a backup is kept as settings.json.chromatia-backup). Switch it off in Settings → Colors → Apps.

## 1.2.0
- **Terminal colors**: Konsole gets a "Chromatia" color scheme and profile that follow the wallpaper too (Settings → Colors → Apps). New Konsole windows use the current colors.

## 1.1.0
- **Chromatia Settings**: the gear in the dashboard opens Colors (accent from the wallpaper or a fixed color, KDE accent on/off) and Audio (choose which outputs and microphones the dashboard shows, give them your own names).
- **Updates**: the dashboard tells you when a new version is out and installs it with one click. Settings → About & Updates shows the version and the changes.
- `./install.sh --update` updates Chromatia without touching your panels or settings.

## 1.0.1
- Fixed: black screen with only the clock on fresh accounts (Plasma waited for a wallpaper that was never set).
- The installer sets a first wallpaper and can enable the Magic Lamp minimize animation.
- Dates and weekday names are English everywhere.

## 1.0.0
- First release.
