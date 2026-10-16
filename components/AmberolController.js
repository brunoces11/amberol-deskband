.pragma library

function formatTime(seconds) {
    var n = Math.max(0, Math.floor(Number(seconds) || 0));
    var s = String(n % 60).padStart(2, "0");
    var m = Math.floor(n / 60);
    return m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") + ":" + s : m + ":" + s;
}

function hasTrack(player) {
    if (!player) return false;
    var metadata = player.metadata || {};
    var track = String(metadata["mpris:trackid"] || "");
    return !!(player.trackTitle || metadata["xesam:url"] || (track && !track.endsWith("/NoTrack")));
}

function selectPlayer(players, fallback) {
    var amberol = [], others = [];
    for (var i = 0; i < players.length; i++) {
        var p = players[i];
        if (!p) continue;
        if (p.desktopEntry === "io.bassi.Amberol" || p.dbusName.indexOf("org.mpris.MediaPlayer2.io.bassi.Amberol") === 0)
            amberol.push(p);
        else if (p.canControl && hasTrack(p) && p.dbusName.indexOf("playerctld") === -1) others.push(p);
    }
    function compare(a, b) {
        if (a.isPlaying !== b.isPlaying) return a.isPlaying ? -1 : 1;
        return a.dbusName.localeCompare(b.dbusName);
    }
    amberol.sort(compare);
    others.sort(compare);
    return amberol.length ? amberol[0] : (fallback && others.length ? others[0] : null);
}

function alpha(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity); }

// Preserve the old surface's relative brightness, then neutralize its tint.
function lighterGraySurface(background, foreground, opacity, factor) {
    var r = background.r * (1 - opacity) + foreground.r * opacity;
    var g = background.g * (1 - opacity) + foreground.g * opacity;
    var b = background.b * (1 - opacity) + foreground.b * opacity;
    var gray = Math.min(1, (0.2126 * r + 0.7152 * g + 0.0722 * b) * factor);
    return Qt.rgba(gray, gray, gray, 1);
}
