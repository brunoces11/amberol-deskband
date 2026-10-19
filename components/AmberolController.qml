import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "AmberolController.js" as Util

Item {
    id: root
    visible: false
    property bool fallbackEnabled: true
    property string defaultFolder: ""
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/amberol-deskband/config.json"

    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                var d = JSON.parse(text());
                if (d && d.default_folder) root.defaultFolder = d.default_folder;
                else root.defaultFolder = "";
            } catch (e) {
                root.defaultFolder = "";
            }
        }
        onFileChanged: reload()
    }

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
    readonly property bool canShuffle: !!(player && player.canControl && player.shuffleSupported && (!amberolSelected || player.identity === "Amberol Deskband"))
    readonly property bool canRepeat: !!(player && player.canControl && player.loopSupported)
    readonly property int loopState: player && player.loopSupported ? player.loopState : MprisLoopState.None
    readonly property string repeatLabel: loopState === MprisLoopState.Track
        ? "Repetir esta faixa"
        : (loopState === MprisLoopState.Playlist ? "Repetir playlist" : "Repetição desativada")
    readonly property string repeatGlyph: loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
    readonly property bool canToggle: !!(hasMedia || (player && (player.canControl || player.canTogglePlaying || player.canPlay || player.canPause)) || (defaultFolder && defaultFolder.length > 0))

    function togglePlaying() {
        var p = player;
        if (!p || !hasMedia) {
            if (defaultFolder && defaultFolder.length > 0) {
                var script = Qt.resolvedUrl("../scripts/select_folder.py").toString().replace(/^file:\/\//, "");
                Quickshell.execDetached(["python3", script, "--play-default"]);
                return true;
            }
            if (!p) return false;
        }
        if (p.isPlaying) {
            if (p.canPause) {
                p.pause();
                return true;
            }
            if (p.canTogglePlaying) {
                p.togglePlaying();
                return true;
            }
            if (p.dbusName && p.dbusName.length > 0) {
                Quickshell.execDetached(["busctl", "--user", "call", p.dbusName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Pause"]);
                return true;
            }
            return false;
        } else {
            // Amberol when Stopped advertises canPlay=false in MPRIS, which causes
            // Quickshell's C++ MprisPlayer to reject pl.play() and pl.togglePlaying().
            // For Amberol, or whenever canPlay/canTogglePlaying are false,
            // calling Play directly via D-Bus starts playback reliably.
            if (amberolSelected && p.dbusName && p.dbusName.length > 0) {
                Quickshell.execDetached(["busctl", "--user", "call", p.dbusName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Play"]);
                return true;
            }
            if (p.canPlay) {
                p.play();
                return true;
            }
            if (p.canTogglePlaying) {
                p.togglePlaying();
                return true;
            }
            if (p.dbusName && p.dbusName.length > 0) {
                Quickshell.execDetached(["busctl", "--user", "call", p.dbusName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Play"]);
                return true;
            }
            return false;
        }
    }
    function previous() { if (!player || !player.canGoPrevious) return false; player.previous(); return true; }
    function next() { if (!player || !player.canGoNext) return false; player.next(); return true; }
    function toggleShuffle() { if (!canShuffle) return false; player.shuffle = !player.shuffle; return true; }
    function toggleRepeat() {
        if (!canRepeat) return false;
        var nextState = MprisLoopState.None;
        if (player.loopState === MprisLoopState.None) nextState = MprisLoopState.Playlist;
        else if (player.loopState === MprisLoopState.Playlist) nextState = MprisLoopState.Track;
        player.loopState = nextState;
        return true;
    }
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
