import QtQuick
import QtTest
import "../components/AmberolController.js" as Util

TestCase {
    name: "DeskbandPlayerSelection"
    function player(name, playing, title) { return { desktopEntry: name, dbusName: "org.mpris.MediaPlayer2." + name, isPlaying: playing, trackTitle: title || "", canControl: true, metadata: {} }; }
    function test_amberol_keeps_priority_while_paused() {
        var amberol = player("io.bassi.Amberol", false, "Track");
        var browser = player("browser", true, "Video");
        compare(Util.selectPlayer([browser, amberol], true), amberol);
        verify(Util.hasTrack(amberol));
    }
    function test_empty_amberol_collapses_instead_of_switching() {
        var amberol = player("io.bassi.Amberol", false, "");
        compare(Util.selectPlayer([player("browser", true, "Video"), amberol], true), amberol);
        verify(!Util.hasTrack(amberol));
    }
    function test_fallback_and_absent_players() {
        var paused = player("vlc", false, "Track");
        var playing = player("spotify", true, "Track");
        compare(Util.selectPlayer([paused, playing], true), playing);
        compare(Util.selectPlayer([paused], false), null);
        compare(Util.selectPlayer([], true), null);
    }
    function test_fallback_ties_are_stable() {
        var a = player("a", true, "A"), b = player("b", true, "B");
        compare(Util.selectPlayer([b, a], true), a);
        compare(Util.selectPlayer([a, b], true), a);
    }
    function test_partial_metadata_and_time() {
        var p = player("vlc", false, "");
        p.metadata["xesam:url"] = "file:///track.ogg";
        verify(Util.hasTrack(p));
        compare(Util.formatTime(210), "3:30");
        compare(Util.formatTime(-1), "0:00");
        compare(Util.formatTime(3601), "1:00:01");
    }
    function test_saved_playlist_parses_unicode_paths_and_order() {
        var tracks = Util.parseSavedPlaylist("[playlist]\r\nNumberOfEntries=2\r\nFile0=/music/01 Anunciação.m4a\r\nFile1=/music/02 Céu Azul.mp3\r\n");
        compare(tracks.length, 2);
        compare(tracks[0].number, 1);
        compare(tracks[0].title, "01 Anunciação");
        compare(tracks[1].title, "02 Céu Azul");
    }
    function test_saved_playlist_skips_missing_entries() {
        var tracks = Util.parseSavedPlaylist("NumberOfEntries=3\nFile0=/music/a.ogg\nFile2=/music/c.flac\n");
        compare(tracks.length, 2);
        compare(tracks[1].number, 3);
        compare(Util.parseSavedPlaylist("").length, 0);
    }
}
