# Chromatia

**A KDE Plasma 6 desktop that takes its colors from your wallpaper — images *and* videos.**

Pick a wallpaper and everything follows: the frame around the screen, the island bar, the dock,
the dashboard, the desktop clock, folder icons and the system accent color. Built from plain
Plasma parts (widgets, a wallpaper plugin, KWin scripts) — no extra shell, nothing replaces Plasma.

> 📹 Preview: *add your screenshot or video here* (e.g. `docs/preview.mp4`)

---

## Features

- **Wallpaper-driven colors** – a strong accent color is picked from every wallpaper (for videos from a still frame) and applied everywhere, including the KDE system accent.
- **Frame around the desktop** – rounded inner corners, colored like the bar, drawn over images and videos.
- **Video wallpapers** – muted, looping, paused automatically while a window is maximized or fullscreen on that screen. Switching wallpapers freezes the old video, recolors everything, then crossfades — no visible stutter.
- **Audio visualizer** – bars along the bottom of the wallpaper while music plays (needs `cava`).
- **Island bar** – workspaces | dock | tray, clock and a kawaii *show desktop* dog.
- **Dock** – apps grouped, live window previews (also for minimized windows), magic-lamp minimize target, pin/unpin, middle-click for a new window.
- **Workspace pills** – numbered pills with a live preview of each desktop, `+` to add, right-click to remove, scroll to switch.
- **Dashboard** – slides down from the top edge: clock with a playing cat, calendar, media player with a round visualizer, sleep inhibitor, CPU/GPU/RAM, an audio mixer (devices and per-app volume), system rings and notes.
- **Wallpaper gallery** – slides out of the left screen edge; click a picture or video to set it on all screens.
- **Big desktop clock** in the accent color.
- **Window snapping (optional, KZones)** – grab a window and a small layout picker slides in at the top (halves, big-left, quarters, thirds).
- **Edge link** – windows that sit edge to edge resize together.

## Requirements

- KDE Plasma 6 on Wayland (made on Plasma 6.8 / Fedora 44)
- Qt 6 Multimedia with the FFmpeg backend (video wallpapers)
- GStreamer with the good plugins (still frames of videos)
- Python 3 with Pillow, dbus-python and PyGObject
- [`cava`](https://github.com/karlstav/cava) – optional, for the visualizers
- **[Panel Colorizer](https://github.com/luisbocanegra/plasma-panel-colorizer)** – for the island bar and frame panels (*Add Widgets → Get New Widgets → "Panel Colorizer"*)
- Optional: **KZones** (*System Settings → Window Management → KWin Scripts → Get New*), **Network Speed** widget (`org.kde.netspeedWidget`), **Mission Center** (opens from the dashboard)

Fedora:
```bash
sudo dnf install qt6-qttools qt6-qtmultimedia python3-pillow python3-dbus python3-gobject gstreamer1-plugins-good cava
```
Arch:
```bash
sudo pacman -S qt6-tools qt6-multimedia qt6-multimedia-ffmpeg python-pillow python-dbus python-gobject gst-plugins-good cava
```

## Installation

```bash
git clone https://github.com/xAFKevinX/Chromatia.git
cd Chromatia
./install.sh
```

The installer adds the widgets, the wallpaper plugin, the KWin script, two small helper scripts
(`~/.local/bin/chromatia-sync`, `chromatia-visualizer`) and a systemd user unit. Then it **asks** before:

1. **replacing the panels on your primary screen** with the Chromatia layout (a backup of your current layout is saved to `~/.local/share/chromatia/backup-*`),
2. **setting up KZones** (only if installed),
3. **enabling the bottom-left hot corner** for the application launcher.

Afterwards put images or videos into `~/Pictures/Wallpapers`, move the mouse to the **middle of the left screen edge** and pick one.

> Tip: virtual desktops per screen (*System Settings → Virtual Desktops*) work nicely with the workspace pills.

## Usage

| Where | What |
|---|---|
| Left edge, middle | wallpaper gallery |
| Top edge, middle | dashboard (tabs: Dashboard · Audio · System · Notes) |
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

## Troubleshooting

- **Colors don't change** – check the service: `systemctl --user status chromatia-sync.path`, run `chromatia-sync` once by hand and look at its output.
- **An Electron app crashes when the accent changes** – that comes from KDE's GTK settings sync (kded module *gtkconfig*). Disable it or set `SystemAccent=false`.
- **Video wallpaper stays black** – make sure the Qt Multimedia FFmpeg backend is installed.
- **Changed QML doesn't show up** – restart Plasma: `systemctl --user restart plasma-plasmashell`.

## Uninstall

```bash
./uninstall.sh
```

## Credits

- Inspired by [Caelestia](https://github.com/caelestia-dots/shell) – Chromatia rebuilds a similar look with stock Plasma parts.
- Panel styling with [Panel Colorizer](https://github.com/luisbocanegra/plasma-panel-colorizer) by luisbocanegra.
- Window snapping with [KZones](https://github.com/gerritdevriese/kzones) by gerritdevriese (GPL-3.0). `kwin/kzones/chromatia-kzones.patch` is a small modification of it and is licensed under GPL-3.0 as well.
- Playing cat animation: ["Cat playing animation" by Abdul Latif on LottieFiles](https://lottiefiles.com/free-animation/cat-playing-animation-1cwXJbHzz7), [Lottie Simple License](https://help.lottiefiles.com/animation-licensing-basics-).

## License

MIT – see [LICENSE](LICENSE). Exceptions: the KZones patch (GPL-3.0) and the cat animation (Lottie Simple License), see Credits.
