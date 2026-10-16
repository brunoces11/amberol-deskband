import QtQuick
import "AmberolController.js" as Colors
import Quickshell
import Quickshell.Hyprland
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
    property string seekTrack: ""
    property var volumePlayer: null
    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property string position: hostBar && hostBar.position ? hostBar.position : "top"
    signal closeRequested()
    function refreshPosition() { displayedPosition = controller.player ? controller.player.position : 0; }
    function close() { closeRequested(); }
    visible: open && anchorWindow !== null
    color: "transparent"
    implicitWidth: 320
    implicitHeight: 390
    onOpenChanged: if (open) refreshPosition()
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
    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.controller.playing && !seek.dragging
        onTriggered: root.refreshPosition()
    }
    Connections {
        target: root.controller.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.refreshPosition(); }
        function onIsPlayingChanged() { root.refreshPosition(); }
    }
    Connections { target: root.controller; function onTrackKeyChanged() { root.refreshPosition(); } }
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.background
        border.width: 1
        border.color: Colors.alpha(root.foreground, 0.28)
        focus: root.open
        Keys.onEscapePressed: root.closeRequested()
        Column {
            x: 16; y: 14; width: parent.width - 32; spacing: 7
            Item {
                width: parent.width; height: 156
                AlbumArt { anchors.horizontalCenter: parent.horizontalCenter; width: 156; height: 156; radius: 8; source: root.controller.artUrl; foreground: root.foreground }
                DeskbandButton { anchors.right: parent.right; glyph: "×"; label: "Fechar"; foreground: root.foreground; onClicked: root.closeRequested() }
            }
            Text { width: parent.width; height: 18; text: root.controller.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
            Text { width: parent.width; height: 15; text: root.controller.artist; textFormat: Text.PlainText; elide: Text.ElideRight; color: Colors.alpha(root.foreground, 0.66); font.family: root.fontFamily; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
            DeskbandSlider {
                id: seek
                width: parent.width
                label: "Posição da faixa"
                maximum: root.controller.player && root.controller.player.length > 0 ? root.controller.player.length : 1
                value: root.displayedPosition
                enabled: root.controller.canSeek
                foreground: root.foreground; accent: root.accent
                onStarted: root.seekTrack = root.controller.trackKey
                onCommitted: function(value) { root.controller.seekTo(value, root.seekTrack || root.controller.trackKey); root.seekTrack = ""; root.refreshPosition(); }
            }
            Row {
                width: parent.width
                Text { width: parent.width / 2; text: Util.formatTime(seek.dragging ? seek.liveValue : root.displayedPosition); color: Colors.alpha(root.foreground, 0.7); font.family: root.fontFamily; font.pixelSize: 10 }
                Text { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: root.controller.player && root.controller.player.lengthSupported ? Util.formatTime(root.controller.player.length) : "—"; color: Colors.alpha(root.foreground, 0.7); font.family: root.fontFamily; font.pixelSize: 10 }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12; height: 32
                DeskbandButton { glyph: "󰒮"; label: "Faixa anterior"; enabled: !!(root.controller.player && root.controller.player.canGoPrevious); foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.controller.previous() }
                DeskbandButton { glyph: root.controller.playing ? "󰏤" : "󰐊"; label: "Reproduzir / pausar"; selected: true; enabled: root.controller.canToggle; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; onClicked: root.controller.togglePlaying() }
                DeskbandButton { glyph: "󰒭"; label: "Próxima faixa"; enabled: !!(root.controller.player && root.controller.player.canGoNext); foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.controller.next() }
                DeskbandButton { glyph: "󰒟"; label: "Aleatório"; selected: !!(root.controller.player && root.controller.player.shuffle); enabled: root.controller.canShuffle; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; onClicked: root.controller.toggleShuffle() }
            }
            Row {
                width: parent.width; spacing: 10
                Text { width: 18; anchors.verticalCenter: parent.verticalCenter; text: "󰕾"; font.family: root.fontFamily; color: root.foreground; font.pixelSize: 16 }
                DeskbandSlider {
                    width: parent.width - 70
                    label: "Volume do player"
                    value: root.controller.volume
                    enabled: root.controller.canVolume
                    foreground: root.foreground; accent: root.accent
                    onStarted: root.volumePlayer = root.controller.player
                    onCommitted: function(value) { root.controller.setVolume(value, root.volumePlayer); root.volumePlayer = null; }
                }
                Text { width: 32; anchors.verticalCenter: parent.verticalCenter; text: root.controller.canVolume ? Math.round(root.controller.volume * 100) + "%" : "—"; color: Colors.alpha(root.foreground, 0.7); font.family: root.fontFamily; font.pixelSize: 10 }
            }
        }
    }
}
