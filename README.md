# Chromatia

**A KDE Plasma 6 desktop that takes its colors from your wallpaper — images *and* videos.**

Pick a wallpaper and everything follows: the frame around the screen, the island bar, the dock,
the dashboard, the desktop clock, folder icons and the system accent color. Built from plain
Plasma parts (widgets, a wallpaper plugin, KWin scripts) — no extra shell, nothing replaces Plasma.

https://github.com/user-attachments/assets/17dc0145-0b8f-4d3d-8fab-c6801b7a00a2

> 🤖 **Disclaimer:** Chromatia was made with the help of [Claude](https://claude.ai), an AI assistant by Anthropic.
> I came up with the look, decided what goes in and tested everything on my own desktop –
> a large part of the code was written by Claude. Just so nobody feels fooled. 🙂

---

## Features

- **Wallpaper-driven colors** – a strong accent color is picked from every wallpaper (for videos from a still frame) and applied everywhere, including the KDE system accent, the Konsole terminal and VS Code.
- **Frame around the desktop** – rounded inner corners, colored like the bar, drawn over images and videos.
- **Video wallpapers** – muted, looping, paused automatically while a window is maximized or fullscreen on that screen, while windows side by side fill it, or while the screen is locked (all can be switched off). Power-friendly: 60 fps videos play as a 30 fps copy, side screens can show a still frame, and on NVIDIA the CPU decodes them (the card stays in its power-saving state). Switching wallpapers freezes the old video, recolors everything, then crossfades — no visible stutter.
- **Audio visualizer** – bars along the bottom of the wallpaper while music plays (needs `cava`).
- **Island bar** – workspaces | dock | tray, clock and a kawaii *show desktop* dog.
- **Dock** – apps grouped, live window previews (also for minimized windows), magic-lamp minimize target, pin/unpin, middle-click for a new window.
- **Workspace pills** – numbered pills with a live preview of each desktop, `+` to add, right-click to remove, scroll to switch.
- **Dashboard** – slides down from the top edge: clock, calendar, media player with a round visualizer, squiggly progress bar and a playing cat, sleep inhibitor, CPU/GPU/RAM/VRAM, an audio mixer (now playing, devices and per-app volume, with wavy sliders), system rings, notes and all your notifications.
- **Notifications** – slide out of the frame at the top right; a glowing pill in the notch shows what you haven't read yet.
- **Wallpaper gallery** – slides out of the left screen edge; click a picture or video to set it on all screens.
- **Big desktop clock** in the accent color.
- **Lock screen** – big clock on your wallpaper (videos too), round password field, media island, and sleep/restart/shut down pills. Unlocking is KDE's own code.
- **Login screen** – `chromatia-login` gives Plasma's login screen your wallpaper and colors.
- **Window snapping (optional, KZones)** – grab a window and a small layout picker slides in at the top (halves, big-left, quarters, thirds).
- **Edge link** – windows that sit edge to edge resize together.

## Requirements

- KDE Plasma 6 on Wayland – **tested only on Fedora 44 with Plasma 6.8**. Other distributions may work, see [Issues & requests](#issues--requests)
- A few packages (installed in step 1 below)
- **[Panel Colorizer](https://github.com/luisbocanegra/plasma-panel-colorizer)** for the island bar and the frame panels (step 2)
- Optional: **KZones** for window snapping, the **Network Speed** widget, **Mission Center** (opens from the dashboard)

## Installation – step by step

> ⚠️ **Use at your own risk.** Chromatia changes your Plasma panels, wallpaper and some KWin settings.
> It works on my machine and was tested on a fresh account, but every setup is different.
> I take no responsibility for anything that breaks – the software is provided "as is", without any
> warranty (see [LICENSE](LICENSE)). The installer backs up your panel layout first; still, it's a good
> idea to try it on a test user account before using it on your main one.

### 1. Install the packages Chromatia needs

This does **not** install Chromatia yet – it installs the programs Chromatia uses
(video playback, the audio visualizer `cava`, Python libraries). Open a terminal (Konsole) and run:

**Fedora**
```bash
sudo dnf install qt6-qttools qt6-qtmultimedia python3-pillow python3-dbus python3-gobject gstreamer1-plugins-good cava
```

**Arch / EndeavourOS / CachyOS**
```bash
sudo pacman -S qt6-tools qt6-multimedia qt6-multimedia-ffmpeg python-pillow python-dbus python-gobject gst-plugins-good cava
```

Other distributions: install the same things under your distro's package names. The installer
tells you if something is still missing.

### 2. Install Panel Colorizer (and optionally KZones)

These come from the KDE store, not from the terminal:

- **Panel Colorizer** (required for the bar): right-click the desktop → *Enter Edit Mode* → *Add Widgets…* → *Get New Widgets…* → *Download New Plasma Widgets* → search **Panel Colorizer** → *Install*.
- **KZones** (optional, window snapping): *System Settings* → *Window Management* → *KWin Scripts* → *Get New…* → search **KZones** → *Install*.

### 3. Download Chromatia

This only downloads the files into a folder called `Chromatia` – nothing is installed yet:
```bash
git clone https://github.com/xAFKevinX/Chromatia.git
```
(No `git`? `sudo dnf install git` or `sudo pacman -S git` – or click *Code → Download ZIP* on this page and unpack it.)

### 4. Run the installer

This is the step that actually installs Chromatia:
```bash
cd Chromatia
./install.sh
```

It installs the widgets, the wallpaper plugin, the window script, two small helper programs
(`~/.local/bin/chromatia-sync`, `chromatia-visualizer`) and a background service. Then it **asks** before:

1. **replacing the panels on your primary screen** with the Chromatia layout – answer **Y** for the full look (a backup of your current panels is saved to `~/.local/share/chromatia/backup-*`),
2. **setting up KZones** (only asked if KZones is installed),
3. **enabling the Magic Lamp animation** – windows minimize into their dock icon,
4. **using the Chromatia lock screen** – active after your next login,
5. **enabling the bottom-left hot corner** for the application launcher.

Plasma restarts once at the end – your screen flickers briefly, that's normal.

### 5. Add wallpapers

Put images or videos (`.jpg`, `.png`, `.webp`, `.mp4`, `.webm`, …) into **`~/Pictures/Wallpapers`**,
move the mouse to the **middle of the left screen edge** and click one. The whole desktop recolors itself.

> Tip: virtual desktops per screen (*System Settings → Virtual Desktops*) work nicely with the workspace pills.

### Updating later

```bash
cd Chromatia
git pull
./install.sh
```

## Usage

| Where | What |
|---|---|
| Left edge, middle | wallpaper gallery |
| Top edge, middle | dashboard (tabs: Dashboard · Audio · System · Notes · Notifications) |
| Wi-Fi / Bluetooth buttons (dashboard, top right) | switch on or off (hide them in Chromatia Settings → Dashboard) |
| Grid button (bar, far left) | application launcher (hide it in Chromatia Settings → Bar) |
| Bottom left pills | click: switch · `+`: new desktop · right-click: remove · scroll: switch · hover: preview |
| Dock | click: activate / minimize / cycle windows · middle-click: new window · right-click: pin, close |
| Dog button | minimize all windows · click again: bring exactly those back |
| Drag a window | layout picker at the top (with KZones) |
| Bottom-left corner | application launcher (hot corner) |

### Settings

`~/.config/chromatia/chromatia.conf`
```ini
[General]
# false: Chromatia never changes the KDE system accent color
SystemAccent=true
```

The wallpaper folder can be changed in the settings of the wallpaper gallery widget.

### Lock screen & login screen

- **Lock screen** (Meta+L, after sleep): switched on by the installer. It only changes how the lock screen
  looks: KWin starts the lock screen with Chromatia's `chromatia.desktop` package
  (`~/.config/systemd/user/plasma-kwin_wayland.service.d/chromatia-lockscreen.conf`), your desktop is not touched.
  Wallpaper and accent color follow the desktop automatically. To switch it off, delete that file and log in again.
- **Login screen** (Plasma Login Manager, Plasma 6.6+): its layout is built into KDE and can't be themed, but
  `chromatia-login` gives it your current wallpaper (a still frame for videos), colors, fonts and screen setup.
  It needs your password, so it doesn't run by itself: run it again after changing the wallpaper if you like.
  `chromatia-login --restore` brings back the state from before. SDDM is not supported.

## Troubleshooting

- **Black screen with only the clock after installing** (versions before November 12, 2026, on accounts without a wallpaper set): your panels are fine, Plasma was waiting for the wallpaper. Press **Ctrl+Alt+T** to open a terminal and run
  ```bash
  cd ~/Chromatia && git pull && ./install.sh
  ```
  If no terminal opens: press **Ctrl+Alt+F3**, log in, run
  ```bash
  cd ~/Chromatia && git pull && kpackagetool6 --type Plasma/Wallpaper --upgrade wallpaper/chromatia.wallpaper && systemctl --user restart plasma-plasmashell
  ```
  then go back to your desktop with **Ctrl+Alt+F2** (or F1). Sorry about that!
- **Colors don't change** – check the service: `systemctl --user status chromatia-sync.path`, run `chromatia-sync` once by hand and look at its output.
- **An Electron app crashes when the accent changes** – that comes from KDE's GTK settings sync (kded module *gtkconfig*). Disable it or set `SystemAccent=false`.
- **Video wallpaper stays black** – make sure the Qt Multimedia FFmpeg backend is installed.
- **Still KDE's lock screen** – the Chromatia lock screen starts with your next login. Log out and back in once.
- **Stuck on the lock screen** (should not happen; if the Chromatia lock screen fails to load, KDE's built-in one takes over): press **Ctrl+Alt+F3**, log in and run `loginctl unlock-session`, then **Ctrl+Alt+F2** (or F1) to go back.
- **Changed QML doesn't show up** – restart Plasma: `systemctl --user restart plasma-plasmashell`.

## Issues & requests

Chromatia is a personal project that I share as it is. I test it only on my own setup: **Fedora 44, KDE Plasma 6.8, Wayland**. Other distributions and Plasma versions may work, but I don't test them and can't promise support.

Bug reports and ideas are welcome as [GitHub issues](https://github.com/xAFKevinX/Chromatia/issues). Please include:
- your distribution and Plasma version (`plasmashell --version`)
- what went wrong, and what `chromatia-sync` prints when you run it by hand
- the Plasma log if a widget misbehaves: `journalctl --user -u plasma-plasmashell -b`

I look at them when I find the time, but I can't promise to fix or build everything. Pull requests are welcome.

## Uninstall

```bash
./uninstall.sh
```

## Credits

- Inspired by [Caelestia](https://github.com/caelestia-dots/shell) – Chromatia rebuilds a similar look with stock Plasma parts.
- Panel styling with [Panel Colorizer](https://github.com/luisbocanegra/plasma-panel-colorizer) by luisbocanegra.
- Window snapping with [KZones](https://github.com/gerritdevriese/kzones) by gerritdevriese (GPL-3.0). `kwin/kzones/chromatia-kzones.patch` is a small modification of it and is licensed under GPL-3.0 as well.
- Lock screen: the unlock logic in `lockscreen/` comes from [KDE Plasma](https://invent.kde.org/plasma/plasma-desktop) (GPL-2.0-or-later), so that folder is licensed under GPL-2.0-or-later as well.
- Playing cat animation: ["Cat playing animation" by Abdul Latif on LottieFiles](https://lottiefiles.com/free-animation/cat-playing-animation-1cwXJbHzz7), [Lottie Simple License](https://help.lottiefiles.com/animation-licensing-basics-).

## License

MIT – see [LICENSE](LICENSE). Exceptions: the KZones patch (GPL-3.0), the lock screen in `lockscreen/` (GPL-2.0-or-later) and the cat animation (Lottie Simple License), see Credits.
