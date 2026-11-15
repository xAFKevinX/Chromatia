#!/usr/bin/env bash
# Chromatia uninstaller – removes everything install.sh added.
# Your panels stay as they are; restore a backup from ~/.local/share/chromatia/backup-* if you like.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"

systemctl --user disable --now chromatia-sync.path >/dev/null 2>&1
rm -f "$HOME/.config/systemd/user/chromatia-sync.service" "$HOME/.config/systemd/user/chromatia-sync.path"
systemctl --user daemon-reload
for f in bin/*; do rm -f "$HOME/.local/bin/$(basename "$f")"; done
rm -f "$HOME/.local/share/dbus-1/services/io.github.chromatia.Visualizer.service"
for d in plasmoids/*/; do kpackagetool6 --type Plasma/Applet --remove "$(basename "$d")" >/dev/null 2>&1; done
kpackagetool6 --type Plasma/Wallpaper --remove chromatia.wallpaper >/dev/null 2>&1
# lock screen: KWin goes back to KDE's lock screen at the next login (until then KDE's
# lock screen is used as well, because the package is gone)
rm -f "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d/chromatia-lockscreen.conf"
rmdir "$HOME/.config/systemd/user/plasma-kwin_wayland.service.d" 2>/dev/null
kpackagetool6 --type Plasma/Shell --remove chromatia.desktop >/dev/null 2>&1
for k in accentColor video; do kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key $k --delete; done
if grep -q "/.cache/chromatia/" "$HOME/.config/kscreenlockerrc" 2>/dev/null; then   # the still frame is deleted below
    for k in Image PreviewImage; do kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key $k --delete; done
fi
for k in kwin/chromatia-*/; do   # edge link, notifications (else KDE's popups would stay hidden)
    kpackagetool6 --type KWin/Script --remove "$(basename "$k")" >/dev/null 2>&1
    kwriteconfig6 --file kwinrc --group Plugins --key "$(basename "$k")Enabled" --delete
done
rm -rf "$HOME/.local/share/kwin/scripts/kzones-chromatia"
kwriteconfig6 --file kwinrc --group Plugins --key kzones-chromatiaEnabled --delete
qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
rm -rf "$HOME/.cache/chromatia" "$HOME/.local/state/chromatia"
if systemctl is-enabled plasmalogin.service >/dev/null 2>&1; then
    echo "Login screen: if you ran chromatia-login, run \"./bin/chromatia-login --restore\" (asks for your password)."
fi
echo "Chromatia removed. Layout backups are kept in ~/.local/share/chromatia/"
echo "To restore one: stop Plasma (systemctl --user stop plasma-plasmashell), copy the files"
echo "from a backup folder into ~/.config/, then start Plasma again."
