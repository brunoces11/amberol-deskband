import QtQuick
import QtQuick.Controls
import "AmberolController.js" as Colors
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "AmberolController.js" as Util

PopupWindow {
    id: root
    required property Item anchorItem
    required property var controller
    property var hostBar: null
    property bool open: false
    property color foreground: "#eeeeee"
    property color accent: "#e5b567"
    property color background: "#202126"
    property string fontFamily: "sans-serif"
    property real displayedPosition: 0
    property string playlistStatus: "Carregando playlist do Amberol…"
    property string playlistPath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/amberol/playlists/current.pls"
    property bool triedFlatpakCache: false
    ListModel { id: playlistModel }
    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property string position: hostBar && hostBar.position ? hostBar.position : "top"
    signal closeRequested()
    function refreshPlaylist() {
        if (!controller.amberolSelected) {
            playlistModel.clear();
            playlistStatus = "A lista local está disponível apenas para o Amberol";
            return;
        }
        playlistFile.reload();
    }
    function loadPlaylist(contents) {
        playlistModel.clear();
        var entries = Util.parseSavedPlaylist(contents);
        for (var i = 0; i < entries.length; i++) playlistModel.append(entries[i]);
        playlistStatus = entries.length ? "Playlist salva pelo Amberol · " + entries.length + " músicas" : "Nenhuma música carregada encontrada";
    }
    function refreshPosition() { displayedPosition = controller.player ? controller.player.position : 0; }
    function close() { closeRequested(); }
    visible: open && anchorWindow !== null
    color: "transparent"
    implicitWidth: 340
    implicitHeight: 390
    onOpenChanged: if (open) refreshPlaylist()
    FileView {
        id: playlistFile
        path: root.playlistPath
        watchChanges: true
        printErrors: false
        onLoaded: root.loadPlaylist(text())
        onFileChanged: if (root.open) reload()
        onLoadFailed: {
            if (!root.triedFlatpakCache) {
                root.triedFlatpakCache = true;
                root.playlistPath = Quickshell.env("HOME") + "/.var/app/io.bassi.Amberol/cache/amberol/playlists/current.pls";
                reload();
            } else {
                playlistModel.clear();
                root.playlistStatus = "O Amberol ainda não salvou uma playlist";
            }
        }
    }
    anchor {
        window: root.anchorWindow
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
        rect.width: 1
        rect.height: 1
        onAnchoring: {
            if (!root.anchorWindow || !root.anchorItem) return;
            var x = root.anchorItem.width / 2 - root.implicitWidth / 2;
            var y = root.position === "bottom" ? -root.implicitHeight - 6 : root.anchorItem.height + 6;
            var point = root.anchorWindow.contentItem.mapFromItem(root.anchorItem, x, y);
            root.anchor.rect.x = Math.round(Math.max(6, Math.min(point.x, root.anchorWindow.width - root.implicitWidth - 6)));
            root.anchor.rect.y = Math.round(point.y);
        }
    }
    HyprlandFocusGrab {
        active: root.open
        windows: root.anchorWindow ? [root, root.anchorWindow] : [root]
        onCleared: root.closeRequested()
    }
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.background
        border.width: 1
        border.color: Colors.alpha(root.foreground, 0.28)
        focus: root.open
        Keys.onEscapePressed: root.closeRequested()
        Column {
            x: 14; y: 12; width: parent.width - 28; spacing: 6
            Row {
                width: parent.width; height: 26
                Column {
                    width: parent.width - 36; spacing: 2
                    Text { width: parent.width; text: "Músicas carregadas"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { width: parent.width; text: root.playlistStatus; color: Colors.alpha(root.foreground, 0.66); font.family: root.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                }
                DeskbandButton { width: 30; height: 26; glyph: "×"; label: "Fechar"; foreground: root.foreground; onClicked: root.closeRequested() }
            }
            ListView {
                width: parent.width; height: 294; clip: true; model: playlistModel; spacing: 1
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    required property int index
                    required property int number
                    required property string title
                    width: ListView.view.width; height: 27; radius: 6
                    readonly property bool isCurrentTrack: Util.sameTrackTitle(title, root.controller.title)
                    color: isCurrentTrack ? Colors.alpha("#3988ff", 0.24) : "transparent"
                    border.width: isCurrentTrack ? 1 : 0
                    border.color: Colors.alpha("#3988ff", 0.78)
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
                        Text { width: 24; height: parent.height; verticalAlignment: Text.AlignVCenter; text: String(number).padStart(2, "0"); color: parent.parent.isCurrentTrack ? "#8bbcff" : Colors.alpha(root.foreground, 0.5); font.family: root.fontFamily; font.pixelSize: 10 }
                        Text { width: parent.width - 42; height: parent.height; verticalAlignment: Text.AlignVCenter; text: title; textFormat: Text.PlainText; elide: Text.ElideRight; color: parent.parent.isCurrentTrack ? "#a9ceff" : root.foreground; font.family: root.fontFamily; font.pixelSize: 11; font.weight: parent.parent.isCurrentTrack ? Font.DemiBold : Font.Normal }
                    }
                }
            }
            Text { width: parent.width; text: "Exibe a playlist salva pelo Amberol; a ordem aleatória do player não é publicada."; wrapMode: Text.WordWrap; color: Colors.alpha(root.foreground, 0.58); font.family: root.fontFamily; font.pixelSize: 9 }
        }
    }
}
