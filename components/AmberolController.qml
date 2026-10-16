import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "AmberolController.js" as Util

Item {
    id: root
    visible: false
    property bool fallbackEnabled: true
    property bool amberolShuffleEnabled: false
    readonly property var players: Mpris.players.values
    readonly property var player: Util.selectPlayer(players, fallbackEnabled)
    readonly property bool hasMedia: Util.hasTrack(player)
    readonly property string title: player ? (player.trackTitle || "Faixa sem título") : ""
    readonly property string artist: player ? (player.trackArtist || player.identity || "") : ""
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property string trackKey: player ? player.dbusName + ":" + String(player.metadata["mpris:trackid"] || player.uniqueId) : ""
    readonly property bool playing: player ? player.isPlaying : false
    readonly property bool canSeek: !!(player && player.canSeek && player.positionSupported && player.lengthSupported && player.length > 0 && (!amberolSelected || amberolStreams.length > 0))
    readonly property bool amberolSelected: !!(player && (player.desktopEntry === "io.bassi.Amberol" || player.dbusName.indexOf("org.mpris.MediaPlayer2.io.bassi.Amberol") === 0))
    readonly property var audioStreams: {
        var nodes = Pipewire.nodes.values;
        var result = [];
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i];
            if (node && node.isStream && node.isSink && node.audio) result.push(node);
        }
        return result;
    }
    readonly property var amberolStreams: {
        var result = [];
        for (var i = 0; i < audioStreams.length; i++) {
            var node = audioStreams[i];
            var props = node.ready ? node.properties : {};
            if (props["application.icon-name"] === "io.bassi.Amberol" || props["application.id"] === "io.bassi.Amberol" || props["application.process.binary"] === "amberol" || node.name === "Amberol") result.push(node);
        }
        return result;
    }
    readonly property bool canVolume: !!(player && player.canControl && (amberolSelected ? amberolStreams.length > 0 : player.volumeSupported))
    readonly property real volume: amberolSelected ? (amberolStreams.length ? amberolStreams[0].audio.volume : 0) : (player ? player.volume : 0)
    readonly property string volumeBackend: amberolSelected ? "PipeWire" : "MPRIS"
    PwObjectTracker { objects: root.audioStreams }
    readonly property bool canShuffle: !!(player && player.canControl && player.shuffleSupported && (!amberolSelected || amberolShuffleEnabled))
    readonly property bool canToggle: !!(player && (player.canTogglePlaying || (playing ? player.canPause : player.canPlay)))

    function togglePlaying() {
        var p = player;
        if (!p) return false;
        if (p.canTogglePlaying) p.togglePlaying();
        else if (p.isPlaying && p.canPause) p.pause();
        else if (!p.isPlaying && p.canPlay) p.play();
        else return false;
        return true;
    }
    function previous() { if (!player || !player.canGoPrevious) return false; player.previous(); return true; }
    function next() { if (!player || !player.canGoNext) return false; player.next(); return true; }
    function toggleShuffle() { if (!canShuffle) return false; player.shuffle = !player.shuffle; return true; }
    function setVolume(value, expectedPlayer) {
        if (!isFinite(Number(value)) || !canVolume || (expectedPlayer && expectedPlayer !== player)) return false;
        var clamped = Math.max(0, Math.min(1, value));
        // Amberol 2026.1 advertises writable MPRIS Volume but ignores setters.
        // Only its playback streams are changed; never the default device.
        if (amberolSelected) {
            for (var i = 0; i < amberolStreams.length; i++) amberolStreams[i].audio.volume = clamped;
        } else player.volume = clamped;
        return true;
    }
    function seekTo(value, expectedTrack) {
        if (!isFinite(Number(value)) || !canSeek || (expectedTrack && expectedTrack !== trackKey)) return false;
        var position = Math.max(0, Math.min(player.length, value));
        // Amberol 2026.1 implements relative Seek, but not SetPosition.
        if (amberolSelected) player.seek(position - player.position);
        else player.position = position;
        return true;
    }
}
