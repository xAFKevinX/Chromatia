# Changelog

## 1.8.0
- **App folders in the bar**, like folders on an Android home screen. Click one and it grows out of the bar like the dashboard notch. It closes by itself 2.5 seconds after the mouse leaves it.
  - Every folder can have its own icon (a controller for games, for example): click the icon in the open folder, or right-click the folder → *Change icon…*.
  - Add apps with the small `+` at the top right (search over all installed apps, Steam games included), or drag apps, folders and files from the launcher, Dolphin or the desktop onto a folder. Folders keep the icon you gave them in Dolphin.
  - Click the folder name to rename it, hover an app for × to remove it, right-click a folder for a new folder or to delete it.
  - Already on Chromatia? The update installs the widget, but doesn't touch your bar: right-click the bar → *Add Widgets…* → **Chromatia Folders**, then put it between two spacers so it gets its own island.
- **Islands can be switched off**: Chromatia Settings → Bar → *Islands* removes the lighter background behind the groups in the bar.
- **Fix**: a Chromatia widget added later only got the wallpaper colors after the next wallpaper change. Now it gets them right away.

## 1.7.2
- **Lock screen with two or more screens**: the password field now always starts on your primary screen and takes the keyboard there, so you can just start typing. Before, it often landed on a side screen (KDE picks the screen under the mouse, which Wayland often doesn't report) and typing did nothing until you clicked. Moving the mouse to another screen still moves the password field there.
- **Fix: the dashboard sometimes didn't close** after you had clicked into the notes once. It now keeps checking while it is open and closes as soon as the mouse is gone.

## 1.7.1
- **Video wallpapers use far less power**, measured on an RTX 5060 Ti: about 18 W less at the wall, now nearly the same as a still image.
  - With an NVIDIA card, Chromatia decodes video wallpapers on the CPU. NVIDIA's driver keeps the whole card at full clocks while its video decoder is in use, which costs ~9 W even for a small 1080p video. A modern CPU decodes that on the side. AMD and Intel keep hardware decoding. Takes effect after the next login.
  - 60 fps videos get a 30 fps copy, made once in the background (a few seconds with ffmpeg).
  - Chromatia Settings → Wallpaper → **Videos only on the main screen**: the other screens show a still frame.
  - Videos pause while the screen is locked.
- **Fix: the visualizer helper used a full CPU core** for a minute after every pause of music or video.

## 1.7.0
- **Lock screen in the Chromatia look**: big clock, your wallpaper with the frame (videos play too, muted, and pause after 3 minutes without input), the accent color and a media island with the wavy progress. Move the mouse or press a key for the unlock card: avatar, round password field and pills for sleep, switch user, restart and shut down. Restart and shut down ask once more ("Shut down?") before they act. Unlocking itself is KDE's own code, unchanged.
- The lock screen follows every wallpaper change automatically.
- **Login screen** (Plasma Login Manager): run `chromatia-login` to give it your current wallpaper, colors and fonts. It asks for your password, `chromatia-login --restore` goes back.
- Already on Chromatia? Run `./install.sh` once and answer **Y** at "Use the Chromatia lock screen?" (you can answer N to everything else), then log out and back in.

## 1.6.1
- **Fix: notifications from Flatpak apps** (e.g. Vesktop/Discord) could leave an empty box at the top right after they disappeared. Their close and action buttons didn't work either.
- Popups now also slide out when the app withdraws its notification, e.g. when you answer a call.

## 1.6.0
- **Quick toggles**: round Wi-Fi and Bluetooth buttons next to the gear at the top of the dashboard. Click to switch on or off; filled in your accent color while on. A button only appears if your computer has the hardware for it.
- New settings page **Dashboard** in Chromatia Settings to hide either button, e.g. on a desktop PC. The tabs move back to the center when the buttons are hidden.
- The update pill no longer covers the Notifications tab.

## 1.5.1
- **Launcher button**: a grid button at the left end of the bar opens the app launcher (the same one as the bottom-left hot corner). New settings page **Bar** in Chromatia Settings to hide it. It is on by default.
- **Wallpaper gallery**: a folder button at the top right opens your wallpaper folder in the file manager.
- "1 wallpaper" instead of "1 wallpapers".

## 1.5.0
- **Squiggly progress bar** (Android style): the media progress is a gently moving wave in your accent color. It flattens when you pause. Click or drag on it to seek.
- **New Dashboard layout**: clock and date sit compactly above the calendar, so the media card gets more room. The cat now lies next to the player controls, and the stats show VRAM too.
- The calendar only shows as many weeks as the month needs.
- **Audio tab**: a "Now playing" bar with cover, title, controls and the wavy progress. The volume sliders are wavy too: flat when muted, moving while sound is playing.
- Chromatia Settings → Audio → **Wavy lines**: switch the waves on or off, separately for media progress and volume sliders. Off gives plain straight bars.

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
