#!/usr/bin/env python3
"""Run under dbus-run-session; test player discovery and disappearance without closing the user's player."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
NAME = "org.mpris.MediaPlayer2.DeskbandFixture"
OBJECT = "/org/mpris/MediaPlayer2"
INTERFACE = "org.mpris.MediaPlayer2.Player"
XML = """<node><interface name="org.mpris.MediaPlayer2">
<property name="Identity" type="s" access="read"/><property name="DesktopEntry" type="s" access="read"/>
<property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
<property name="HasTrackList" type="b" access="read"/><property name="SupportedUriSchemes" type="as" access="read"/>
<property name="SupportedMimeTypes" type="as" access="read"/></interface>
<interface name="org.mpris.MediaPlayer2.Player">
<property name="PlaybackStatus" type="s" access="read"/><property name="Metadata" type="a{sv}" access="read"/>
<property name="CanControl" type="b" access="read"/><property name="CanPlay" type="b" access="read"/>
<property name="CanPause" type="b" access="read"/><property name="CanGoNext" type="b" access="read"/>
<property name="CanGoPrevious" type="b" access="read"/><property name="CanSeek" type="b" access="read"/>
<property name="Position" type="x" access="read"/><property name="Volume" type="d" access="read"/>
<property name="Shuffle" type="b" access="read"/><property name="Rate" type="d" access="read"/>
<property name="MinimumRate" type="d" access="read"/><property name="MaximumRate" type="d" access="read"/>
<property name="LoopStatus" type="s" access="read"/></interface></node>"""


def main():
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    loop = GLib.MainLoop()
    threading.Thread(target=loop.run, daemon=True).start()
    properties = {"Identity": GLib.Variant("s", "Deskband Fixture"), "DesktopEntry": GLib.Variant("s", "deskband-fixture"),
                  "Metadata": GLib.Variant("a{sv}", {}), "PlaybackStatus": GLib.Variant("s", "Stopped"),
                  "Position": GLib.Variant("x", 0), "Volume": GLib.Variant("d", 0.5), "Shuffle": GLib.Variant("b", False),
                  "Rate": GLib.Variant("d", 1.0), "MinimumRate": GLib.Variant("d", 1.0), "MaximumRate": GLib.Variant("d", 1.0),
                  "LoopStatus": GLib.Variant("s", "None"), "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", [])}
    for key in ("CanControl", "CanPlay", "CanPause", "CanGoNext", "CanGoPrevious", "CanSeek"):
        properties[key] = GLib.Variant("b", True)
    for key in ("CanQuit", "CanRaise", "HasTrackList"):
        properties[key] = GLib.Variant("b", False)
    for interface in Gio.DBusNodeInfo.new_for_xml(XML).interfaces:
        connection.register_object(OBJECT, interface, None, lambda c,s,o,i,p: properties[p], None)
    def request(method):
        arguments = GLib.Variant("(su)", (NAME, 0)) if method == "RequestName" else GLib.Variant("(s)", (NAME,))
        connection.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", method, arguments, None, Gio.DBusCallFlags.NONE, -1, None)
    def update(key, value):
        properties[key] = value
        connection.emit_signal(None, OBJECT, "org.freedesktop.DBus.Properties", "PropertiesChanged", GLib.Variant("(sa{sv}as)", (INTERFACE, {key: value}, [])))
    with tempfile.TemporaryDirectory(prefix="deskband-runtime-") as directory:
        folder = Path(directory)
        qml = """import QtQuick
import Quickshell
import Quickshell.Io
import "REPO_URL" as Deskband
ShellRoot {
    Deskband.BarWidget { id: widget; bar: host }
    QtObject { id: host; property bool vertical: false; property int barSize: 24; property string position: "top"; property color foreground: "white"; property string fontFamily: "sans-serif" }
    IpcHandler {
        target: "fixture"
        function status(): string { return JSON.stringify({media:widget.controller.hasMedia,width:widget.implicitWidth,playing:widget.controller.playing,compact:widget.compact,player:widget.controller.player!==null}); }
    }
}
""".replace("REPO_URL", ROOT.as_uri())
        source=folder/"shell.qml"
        source.write_text(qml)
        assert source.read_text()==qml
        with (folder/"run.log").open("w") as log:
            environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_ACCESSIBILITY="0", NO_AT_BRIDGE="1", GIO_USE_VFS="local", QT_NO_XDG_DESKTOP_PORTAL="1")
            process=subprocess.Popen(["quickshell","--path",directory,"--no-color"],stdout=log,stderr=subprocess.STDOUT,env=environment)
            def wait_state(predicate):
                for _ in range(70):
                    result=subprocess.run(["qs","ipc","-p",directory,"call","fixture","status"],capture_output=True,text=True)
                    try: state=json.loads(result.stdout)
                    except ValueError: state={}
                    if predicate(state): return state
                    if process.poll() is not None: raise AssertionError((folder/"run.log").read_text())
                    time.sleep(.06)
                raise AssertionError(state)
            try:
                wait_state(lambda s:s.get("width")==0 and not s.get("player"))
                print("PASS: no player collapses to zero width",flush=True)
                request("RequestName")
                wait_state(lambda s:not s.get("media") and s.get("width")==0)
                print("PASS: empty player stays collapsed",flush=True)
                update("Metadata",GLib.Variant("a{sv}",{"xesam:title":GLib.Variant("s","Fixture track"),"mpris:length":GLib.Variant("x",60000000)}))
                update("PlaybackStatus",GLib.Variant("s","Playing"))
                wait_state(lambda s:s.get("media") and s.get("playing") and s.get("width")==218.4 and s.get("compact"))
                print("PASS: track discovery expands compact top layout",flush=True)
                update("PlaybackStatus",GLib.Variant("s","Paused"))
                wait_state(lambda s:s.get("media") and not s.get("playing") and s.get("width")==218.4)
                print("PASS: paused track stays available",flush=True)
                request("ReleaseName")
                wait_state(lambda s:not s.get("player") and s.get("width")==0)
                print("PASS: player disappearance collapses cleanly",flush=True)
                request("RequestName")
                wait_state(lambda s:s.get("media") and s.get("width")==218.4)
                print("PASS: player reconnection restores capsule",flush=True)
            finally:
                process.terminate()
                process.wait(timeout=5)
        output=(folder/"run.log").read_text()
        assert " ERROR" not in output,output
        loop.quit()
        print("PASS: runtime lifecycle completed without QML errors",flush=True)


if __name__ == "__main__":
    main()
