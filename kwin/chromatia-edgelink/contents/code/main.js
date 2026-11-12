// Chromatia edge link – windows that sit edge to edge resize together.
//
// Drag the edge of a window that another window touches directly (e.g. two windows
// snapped 50/50 with KZones) and the neighbour follows when you release the mouse.
// Only on resize, never on move. Windows with a gap between them are left alone.

const TOL = 3;            // how close edges must be to count as touching (px)
const MIN = 220;          // smallest width/height a neighbour may shrink to
const LIVE = false;       // true: follow live while dragging (choppy with Electron apps), false: on release
const STEP_MS = 33;       // live mode: at most ~30 updates per second

function geo(g) { return { x: g.x, y: g.y, width: g.width, height: g.height }; }
function near(a, b) { return Math.abs(a - b) <= TOL; }
function overlap(a1, a2, b1, b2) { return Math.min(a2, b2) - Math.max(a1, b1) > 40; }

function usable(w) {
    return !!w && !w.deleted && w.normalWindow && !w.minimized && !w.fullScreen
        && w.resizeable && !w.specialWindow;
}
function sameDesk(a, b) {
    if (a.onAllDesktops || b.onAllDesktops) return true;
    return a.desktops.some(d => b.desktops.some(e => e.id === d.id));
}

// find neighbours touching an edge of s
function linksFor(w, s) {
    const out = [];
    for (const n of workspace.windowList()) {
        if (n === w || !usable(n) || n.output !== w.output || !sameDesk(w, n)) continue;
        if (w.tile && n.tile) continue;               // KWin's own tiles are handled by KWin
        const g = geo(n.frameGeometry);
        const vOver = overlap(s.y, s.y + s.height, g.y, g.y + g.height);
        const hOver = overlap(s.x, s.x + s.width, g.x, g.x + g.width);
        if (vOver && near(s.x + s.width, g.x)) out.push({ n, g, side: "R" });
        if (vOver && near(s.x, g.x + g.width)) out.push({ n, g, side: "L" });
        if (hOver && near(s.y + s.height, g.y)) out.push({ n, g, side: "B" });
        if (hOver && near(s.y, g.y + g.height)) out.push({ n, g, side: "T" });
    }
    return out;
}

function follow(start, now) {
    for (const l of start.links) {
        const g = l.g;
        let r = null;
        if (l.side === "R" && !near(now.x + now.width, start.geo.x + start.geo.width)) {
            const e = now.x + now.width, right = g.x + g.width;
            if (right - e >= MIN) r = { x: e, y: g.y, width: right - e, height: g.height };
        } else if (l.side === "L" && !near(now.x, start.geo.x)) {
            const e = now.x;
            if (e - g.x >= MIN) r = { x: g.x, y: g.y, width: e - g.x, height: g.height };
        } else if (l.side === "B" && !near(now.y + now.height, start.geo.y + start.geo.height)) {
            const e = now.y + now.height, bottom = g.y + g.height;
            if (bottom - e >= MIN) r = { x: g.x, y: e, width: g.width, height: bottom - e };
        } else if (l.side === "T" && !near(now.y, start.geo.y)) {
            const e = now.y;
            if (e - g.y >= MIN) r = { x: g.x, y: g.y, width: g.width, height: e - g.y };
        }
        if (r && !l.n.deleted) l.n.frameGeometry = r;
    }
}

function track(w) {
    if (!w || !w.normalWindow) return;
    let start = null, last = 0;
    w.interactiveMoveResizeStarted.connect(() => {
        start = usable(w) ? { geo: geo(w.frameGeometry), links: null } : null;
    });
    w.interactiveMoveResizeStepped.connect(g => {
        if (!start || !w.resize) return;
        if (start.links === null) start.links = linksFor(w, start.geo);
        if (!LIVE || start.links.length === 0) return;
        const t = Date.now();
        if (t - last < STEP_MS) return;
        last = t;
        follow(start, geo(g));
    });
    w.interactiveMoveResizeFinished.connect(() => {
        if (start && start.links && start.links.length) follow(start, geo(w.frameGeometry));
        start = null;
    });
}

workspace.windowList().forEach(track);
workspace.windowAdded.connect(track);
