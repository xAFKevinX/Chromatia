#!/bin/bash
# Chromatia: isolated, headless Plasma test session (own HOME, own D-Bus, virtual KWin).
#   testsession.sh setup   fresh test home with Chromatia from ~/Chromatia + layout
#   testsession.sh start   start the session (prints nothing; dbus address in $T/../dbus)
#   testsession.sh env     print exports for using the session from a shell
#   testsession.sh stop    kill everything that belongs to the test home
# Own XDG_RUNTIME_DIR ($B/run): portals started inside the test bus (xdg-document-portal)
# must never touch /run/user/<uid>/doc, or Flatpaks of the real session stop working.
REAL=$(getent passwd "$(id -u)" | cut -d: -f6)   # real home, even when called from inside the test env
B=${CHROMATIA_TEST:-$REAL/.cache/chromatia-test}; T=$B/home; R=$REAL/Chromatia
envs() { echo "export HOME=$T XDG_CONFIG_HOME=$T/.config XDG_DATA_HOME=$T/.local/share XDG_CACHE_HOME=$T/.cache XDG_STATE_HOME=$T/.local/state XDG_RUNTIME_DIR=$B/run"; }
case "$1" in
setup)
    rm -rf "$T"; mkdir -p $T/.config $T/.local/share/plasma/plasmoids $T/.local/bin $T/.local/share/chromatia $T/.cache "$T/Pictures/Wallpapers"
    cp -r $REAL/.local/share/plasma/plasmoids/luisbocanegra.panel.colorizer $T/.local/share/plasma/plasmoids/
    ls $REAL/Bilder/Hintergründe/*.jpg 2>/dev/null | head -2 | xargs -I{} cp {} "$T/Pictures/Wallpapers/"
    printf 'PICTURES_DIR="$HOME/Pictures"\n' > $T/.config/user-dirs.dirs
    ( eval "$(envs)"; cd $R
      for d in plasmoids/*/; do kpackagetool6 --type Plasma/Applet --install "${d%/}" >/dev/null; done
      kpackagetool6 --type Plasma/Wallpaper --install wallpaper/chromatia.wallpaper >/dev/null
      for k in kwin/chromatia-*/; do kpackagetool6 --type KWin/Script --install "${k%/}" >/dev/null; kwriteconfig6 --file kwinrc --group Plugins --key "$(basename $k)Enabled" true; done
      install -m755 bin/* $T/.local/bin/; cp layout/blank.svg $T/.local/share/chromatia/ ) ;;
start)
    "$0" stop
    rm -f $B/dbus; mkdir -p $B/run; chmod 700 $B/run
    cat > $B/inner.sh <<IN
#!/bin/bash
echo \$WAYLAND_DISPLAY > $B/wl
/usr/libexec/kactivitymanagerd >/dev/null 2>&1 &
sleep 1
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=wayland exec plasmashell --no-respawn > $B/plasmashell.log 2>&1
IN
    chmod +x $B/inner.sh
    # envs BEFORE dbus-run-session: D-Bus-activated services inherit the daemon's environment
    ( eval "$(envs)"; env -u ELECTRON_RUN_AS_NODE -u WAYLAND_DISPLAY -u DISPLAY setsid dbus-run-session -- bash -c "echo \$DBUS_SESSION_BUS_ADDRESS > $B/dbus; exec kwin_wayland --virtual --width 1920 --height 1080 --no-lockscreen --no-global-shortcuts --exit-with-session $B/inner.sh" >/dev/null 2>&1 < /dev/null & )
    for i in $(seq 1 30); do [ -s $B/dbus ] && DBUS_SESSION_BUS_ADDRESS=$(cat $B/dbus) qdbus-qt6 org.kde.plasmashell /PlasmaShell 2>/dev/null | grep -q evaluateScript && break; sleep 1; done ;;
env)
    envs; echo "export DBUS_SESSION_BUS_ADDRESS=$(cat $B/dbus) WAYLAND_DISPLAY=$(cat $B/wl)"; echo "unset ELECTRON_RUN_AS_NODE" ;;
stop)
    # SAFETY: only ever kill processes that provably run with the test HOME. Never parents,
    # never anything else – a stray kill of "systemd --user" ends the whole desktop session.
    [ "$HOME" = "$T" ] && exec env HOME="$REAL" "$0" stop       # our own helpers must not match
    keep=" "; q=$$; while [ "${q:-0}" -gt 1 ]; do keep="$keep$q "; q=$(ps -o ppid= -p "$q" | tr -d ' '); done   # nor our callers
    mine() { for p in $(pgrep -u "$(id -u)"); do
        case "$keep" in *" $p "*) continue ;; esac
        { tr '\0' '\n' < /proc/$p/environ; } 2>/dev/null | grep -qx "HOME=$T" || continue
        case "$(cat /proc/$p/comm 2>/dev/null)" in systemd|systemd-*) continue ;; esac
        echo "$p $(cat /proc/$p/comm 2>/dev/null)"
    done; }
    # apps first, while KWin and the bus still run: if Wayland vanishes under them, portals and
    # kdeconnectd abort, get re-activated, abort again – a flood of crash reports in the real session
    for r in 1 2 3; do mine | while read -r p c; do case "$c" in kwin_wayland*|dbus-daemon|dbus-run-sessio) ;; *) kill "$p" 2>/dev/null ;; esac; done; sleep 0.7; done
    mine | while read -r p c; do kill "$p" 2>/dev/null; done
    sleep 1; for m in $(findmnt -rn -o TARGET | grep "^$B/run/"); do fusermount3 -uz "$m"; done
    rm -f $B/dbus $B/wl $B/*.pid ;;
esac
