// Chromatia notifications – hides KDE's own notification popups while Chromatia shows its own
// (Settings → Notifications). Windows titled "chromatia-notifications" are Chromatia's and stay.
const OWN = "chromatia-notifications";

function isKdePopup(w) {
    return !!w && (w.notification || w.criticalNotification)
        && String(w.resourceClass).indexOf("plasmashell") >= 0 && w.caption !== OWN;
}

function hide(w) {
    if (!isKdePopup(w)) return;
    w.opacity = 0;
    const away = () => {
        if (!isKdePopup(w)) { w.opacity = 1; return; }
        const g = w.frameGeometry;
        if (g.x > -5000) w.frameGeometry = { x: -10000, y: g.y, width: g.width, height: g.height };
    };
    away();
    w.frameGeometryChanged.connect(away);
    w.captionChanged.connect(away);
}

workspace.windowList().forEach(hide);
workspace.windowAdded.connect(hide);
