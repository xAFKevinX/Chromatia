#!/usr/bin/env bash
# Chromatia uninstaller – removes everything install.sh added.
# Your panels stay as they are; restore a backup from ~/.local/share/chromatia/backup-* if you like.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"

systemctl --user disable --now chromatia-sync.path >/dev/null 2>&1
rm -f "$HOME/.config/systemd/user/chromatia-sync.service" "$HOME/.config/systemd/user/chromatia-sync.path"
systemctl --user daemon-reload
rm -f "$HOME/.local/bin/chromatia-sync" "$HOME/.local/bin/chromatia-visualizer" \
      "$HOME/.local/share/dbus-1/services/io.github.chromatia.Visualizer.service"
for d in plasmoids/*/; do kpackagetool6 --type Plasma/Applet --remove "$(basename "$d")" >/dev/null 2>&1; done
kpackagetool6 --type Plasma/Wallpaper --remove chromatia.wallpaper >/dev/null 2>&1
kpackagetool6 --type KWin/Script --remove chromatia-edgelink >/dev/null 2>&1
rm -rf "$HOME/.local/share/kwin/scripts/kzones-chromatia"
kwriteconfig6 --file kwinrc --group Plugins --key chromatia-edgelinkEnabled --delete
kwriteconfig6 --file kwinrc --group Plugins --key kzones-chromatiaEnabled --delete
qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
rm -rf "$HOME/.cache/chromatia" "$HOME/.local/state/chromatia"
echo "Chromatia removed. Layout backups are kept in ~/.local/share/chromatia/"
echo "To restore one: stop Plasma (systemctl --user stop plasma-plasmashell), copy the files"
echo "from a backup folder into ~/.config/, then start Plasma again."
