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
    property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/amberol-deskband/config.json"
    property string currentFolder: ""
    property string currentFolderName: ""
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
    function updateConfigData(content) {
        try {
            var data = JSON.parse(content);
            if (data && data.default_folder) {
                root.currentFolder = data.default_folder;
                var parts = data.default_folder.split("/").filter(function(p) { return p.length > 0; });
                root.currentFolderName = parts.length > 0 ? parts[parts.length - 1] : data.default_folder;
            } else {
                root.currentFolder = "";
                root.currentFolderName = "";
            }
        } catch (e) {
            root.currentFolder = "";
            root.currentFolderName = "";
        }
    }
    function launchSelectFolder() {
        var script = Qt.resolvedUrl("../scripts/select_folder.py").toString().replace(/^file:\/\//, "");
        Quickshell.execDetached(["python3", script, "--play"]);
        root.closeRequested();
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
    onOpenChanged: {
        if (open) {
            refreshPlaylist();
            configFile.reload();
        }
    }
    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.updateConfigData(text())
        onFileChanged: if (root.open) reload()
    }
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
                width: parent.width
                height: 32
                Column {
                    id: headerColumn
                    width: parent.width - 34
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { width: parent.width; text: "Músicas carregadas"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { width: parent.width; text: root.playlistStatus; color: Colors.alpha(root.foreground, 0.66); font.family: root.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                }
                DeskbandButton {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "×"
                    label: "Fechar"
                    foreground: root.foreground
                    onClicked: root.closeRequested()
                }
            }
            ListView {
                width: parent.width; height: 275; clip: true; model: playlistModel; spacing: 1
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
            Rectangle {
                id: loadFolderBtn
                width: parent.width
                height: 36
                radius: 7
                color: loadFolderArea.pressed ? Colors.alpha(root.accent, 0.25) :
                       loadFolderArea.containsMouse ? Colors.alpha(root.accent, 0.15) :
                       Colors.alpha(root.foreground, 0.08)
                border.width: 1
                border.color: loadFolderArea.containsMouse ? Colors.alpha(root.accent, 0.8) : Colors.alpha(root.foreground, 0.18)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: loadFolderArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchSelectFolder()
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰉋"
                        font.family: root.fontFamily
                        font.pixelSize: 17
                        color: root.accent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 56
                        spacing: 1

                        Text {
                            text: "Load Folder"
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.foreground
                        }

                        Text {
                            width: parent.width
                            text: root.currentFolderName.length > 0 ? ("Pasta: " + root.currentFolderName) : "Selecionar pasta local de músicas"
                            font.family: root.fontFamily
                            font.pixelSize: 9
                            color: Colors.alpha(root.foreground, 0.65)
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        color: Colors.alpha(root.foreground, 0.5)
                    }
                }
            }
        }
    }
}
