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
}
