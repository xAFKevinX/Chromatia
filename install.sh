#!/usr/bin/env bash
# Chromatia installer – KDE Plasma 6 (Wayland)
# Usage: ./install.sh            full install (asks before optional steps)
#        ./install.sh --update   update files only, keeps panels and settings
# Installs the widgets, the wallpaper plugin, the helper scripts and services.
# Optional steps (panel layout, KZones tweaks, minimize animation, hot corner) ask before touching anything.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
BIN="$HOME/.local/bin"
DATA="$HOME/.local/share/chromatia"
YES=0; UPDATE=0
for arg in "$@"; do
    case "$arg" in
        --yes) YES=1 ;;
        --update) UPDATE=1; YES=1 ;;   # only refresh files, never touch panels or settings
    esac
done
VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")

say()  { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
ask()  { [[ $YES == 1 ]] && return 0; read -r -p "   $1 [Y/n] " a; [[ -z "$a" || "$a" =~ ^[YyJj] ]]; }

# ---------------------------------------------------------------- dependencies
say "Checking dependencies"
missing=()
for c in qdbus-qt6 kpackagetool6 plasma-apply-colorscheme kscreen-doctor gst-launch-1.0 python3 systemctl; do
    command -v "$c" >/dev/null || missing+=("$c")
done
python3 -c "import PIL" 2>/dev/null        || missing+=("python3 Pillow")
python3 -c "import dbus, gi" 2>/dev/null   || missing+=("python3 dbus + gobject")
if ((${#missing[@]})); then
    warn "Missing: ${missing[*]}"
    echo "   Fedora: sudo dnf install qt6-qttools python3-pillow python3-dbus python3-gobject gstreamer1-plugins-good qt6-qtmultimedia cava"
    echo "   Arch:   sudo pacman -S qt6-tools python-pillow python-dbus python-gobject gst-plugins-good qt6-multimedia qt6-multimedia-ffmpeg cava"
    exit 1
fi
command -v cava >/dev/null || warn "cava not found – the audio visualizer stays hidden until you install it"

# ---------------------------------------------------------------- packages
pkg() {   # type, dir
    local id; id=$(basename "$2")
    if kpackagetool6 --type "$1" --show "$id" >/dev/null 2>&1; then
        kpackagetool6 --type "$1" --upgrade "$2" >/dev/null
    else
        kpackagetool6 --type "$1" --install "$2" >/dev/null
    fi
    echo "   $id"
}
say "Installing widgets"
for d in plasmoids/*/; do pkg Plasma/Applet "${d%/}"; done
say "Installing wallpaper plugin"
pkg Plasma/Wallpaper wallpaper/chromatia.wallpaper
say "Installing the lock screen"
pkg Plasma/Shell lockscreen/chromatia.desktop
say "Installing KWin scripts"
for k in kwin/chromatia-*/; do pkg KWin/Script "${k%/}"; done
[[ $UPDATE == 0 ]] && kwriteconfig6 --file kwinrc --group Plugins --key chromatia-edgelinkEnabled true   # keep the user's choice on updates

# ---------------------------------------------------------------- helpers + services
say "Installing helper scripts and services"
mkdir -p "$BIN" "$DATA" "$HOME/.local/share/dbus-1/services" "$HOME/.config/systemd/user" "$HOME/.config/chromatia"
install -m 755 bin/chromatia-sync bin/chromatia-visualizer bin/chromatia-update bin/chromatia-login "$BIN/"
sed "s|@BINDIR@|$BIN|" dbus/io.github.chromatia.Visualizer.service > "$HOME/.local/share/dbus-1/services/io.github.chromatia.Visualizer.service"
install -m 644 systemd/chromatia-sync.service systemd/chromatia-sync.path "$HOME/.config/systemd/user/"
install -m 644 layout/blank.svg "$DATA/blank.svg"
[[ -f "$HOME/.config/chromatia/chromatia.conf" ]] || printf '[General]\n# false: never change the KDE system accent color\nSystemAccent=true\n' > "$HOME/.config/chromatia/chromatia.conf"
pictures=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
gallery="$pictures/Wallpapers"
mkdir -p "$gallery"
# a first wallpaper so the desktop never starts empty: the first file in the gallery,
# otherwise KDE's default wallpaper (copied into the gallery so it shows up there too)
first=$(find "$gallery" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \) | sort | head -n1)
if [[ -z "$first" ]]; then
    def=$(ls /usr/share/wallpapers/Next/contents/images_dark/*.png /usr/share/wallpapers/Next/contents/images/*.png 2>/dev/null | sort -V | tail -n1)
    if [[ -n "$def" ]]; then cp "$def" "$gallery/plasma-default.png"; first="$gallery/plasma-default.png"; fi
fi
systemctl --user daemon-reload
systemctl --user enable --now chromatia-sync.path >/dev/null 2>&1

if [[ $UPDATE == 0 ]]; then   # optional setup steps – skipped by --update

# ---------------------------------------------------------------- panel layout
plasma() { qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }
echo
say "Panel layout"
echo "   Replaces ALL panels on your primary screen with the Chromatia layout"
echo "   (bottom island bar, thin frame panels with dashboard and wallpaper gallery)."
echo "   Needs \"Panel Colorizer\" (Get New Widgets → search \"Panel Colorizer\")."
if ask "Apply the Chromatia panel layout?"; then
    if ! plasma 'print(knownWidgetTypes.indexOf("luisbocanegra.panel.colorizer") >= 0)' | grep -q true; then
        warn "Panel Colorizer is not installed – skipping the layout. Install it and run ./install.sh again."
    else
        backup="$DATA/backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup"
        cp "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/plasmashellrc" "$backup/" 2>/dev/null || true
        echo "   backup of your current layout: $backup"
        plasma "$(sed -e "s|@HOME@|$HOME|g" -e "s|@WALL@|${first:-}|g" layout/layout.js)"
    fi
fi

# ---------------------------------------------------------------- KZones
echo
say "Window snapping (KZones)"
KZ="$HOME/.local/share/kwin/scripts/kzones"
if [[ -d "$KZ" ]]; then
    echo "   Creates a tweaked copy \"KZones (Chromatia)\": zones stay inside the frame, the layout"
    echo "   selector appears as soon as you grab a window, smaller selector, no gaps."
    if ask "Set up KZones the Chromatia way?"; then
        KC="$HOME/.local/share/kwin/scripts/kzones-chromatia"
        rm -rf "$KC"; cp -r "$KZ" "$KC"
        if (cd "$KC" && patch -p1 -s < "$OLDPWD/kwin/kzones/chromatia-kzones.patch"); then
            python3 - "$KC/metadata.json" <<'EOF'
import json, sys
p = sys.argv[1]; m = json.load(open(p))
m["KPlugin"]["Id"] = "kzones-chromatia"; m["KPlugin"]["Name"] = "KZones (Chromatia)"
m["X-KDE-PluginKeyword"] = "kzones-chromatia"
json.dump(m, open(p, "w"), indent=4)
EOF
            G=(--file kwinrc --group Script-kzones-chromatia)
            kwriteconfig6 "${G[@]}" --key layoutsJson "$(cat kwin/kzones/layouts.json)"
            kwriteconfig6 "${G[@]}" --key enableZoneSelector true
            kwriteconfig6 "${G[@]}" --key enableZoneOverlay false
            kwriteconfig6 "${G[@]}" --key enableEdgeSnapping false
            kwriteconfig6 "${G[@]}" --key showOsdMessages false
            kwriteconfig6 --file kwinrc --group Plugins --key kzonesEnabled false
            kwriteconfig6 --file kwinrc --group Plugins --key kzones-chromatiaEnabled true
        else
            warn "The patch does not fit your KZones version – skipped (tested with KZones 0.9.2)."
            rm -rf "$KC"
        fi
    fi
else
    echo "   KZones is not installed. Optional: System Settings → Window Management →"
    echo "   KWin Scripts → Get New → \"KZones\", then run ./install.sh again."
fi

# ---------------------------------------------------------------- minimize animation
echo
if ask "Windows minimize into the dock with the Magic Lamp animation?"; then
    kwriteconfig6 --file kwinrc --group Plugins --key magiclampEnabled true
    kwriteconfig6 --file kwinrc --group Plugins --key squashEnabled false
fi

# ---------------------------------------------------------------- lock screen
echo
say "Lock screen"
echo "   Chromatia look for the lock screen: big clock, your wallpaper (videos too) and the"
echo "   accent color. Only the lock screen changes, unlocking works exactly like in KDE."
echo "   Takes effect after your next login."
LOCK_DROPIN="$HOME/.config/systemd/user/plasma-kwin_wayland.service.d/chromatia-lockscreen.conf"
if ask "Use the Chromatia lock screen?"; then
    mkdir -p "$(dirname "$LOCK_DROPIN")"
    install -m 644 systemd/chromatia-lockscreen.conf "$LOCK_DROPIN"
    systemctl --user daemon-reload
    "$BIN/chromatia-sync" --lockscreen >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------- hot corner
echo
if ask "Bottom-left hot corner opens the application launcher?"; then
    kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomLeft ApplicationLauncher
fi

fi

# ---------------------------------------------------------------- remember where we live
CONF="$HOME/.config/chromatia/chromatia.conf"
kwriteconfig6 --file "$CONF" --group General --key RepoPath "$(pwd)"
kwriteconfig6 --file "$CONF" --group General --key InstalledVersion "$VERSION"

# ---------------------------------------------------------------- reload
say "Reloading KWin and Plasma"
qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
systemctl --user restart plasma-plasmashell.service
sleep 6
"$BIN/chromatia-sync" >/dev/null 2>&1 || true
echo
if [[ $UPDATE == 1 ]]; then say "Chromatia updated to $VERSION."; exit 0; fi
say "Done! Put images or videos into $pictures/Wallpapers and move the mouse to the"
echo "   middle of the left screen edge to pick one. Everything recolors itself."
