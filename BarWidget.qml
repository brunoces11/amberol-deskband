import QtQuick
import "components"

Item {
    id: root
    property QtObject bar: null
    property string moduleName: "amberol-deskband"
    property var settings: ({})
    readonly property bool deskbandInline: true
    readonly property bool vertical: bar ? bar.vertical : false
    readonly property bool compact: bar ? bar.barSize < 36 : false
    readonly property color foreground: bar ? bar.foreground : "#eeeeee"
    readonly property color accent: bar && bar.accent !== undefined ? bar.accent : "#e5b567"
    readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : "sans-serif"
    readonly property var controller: media
    property alias panel: popup
    property bool opened: false
    readonly property real expandedWidth: Math.max(compact ? 200 : 240, Math.min(374.4, Number(settings.width) || (compact ? 218.4 : 265.2)))
    property real displayedPosition: media.player ? media.player.position : 0
    property string seekTrack: ""
    implicitWidth: media.hasMedia && !vertical ? expandedWidth : 0
    implicitHeight: compact ? Math.max(20, bar ? bar.barSize : 24) : 42
    visible: implicitWidth > 0
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    onVerticalChanged: close()
    function close() { opened = false; }
    function togglePanel() { if (media.hasMedia) opened = !opened; }
    onOpenedChanged: {
        if (!bar) return;
        if (opened && typeof bar.requestPopout === "function") bar.requestPopout(root);
        else if (!opened && typeof bar.releasePopout === "function") bar.releasePopout(root);
    }
    Connections {
        target: media
        function onHasMediaChanged() { if (!media.hasMedia) root.close(); }
        function onPlayerChanged() { root.close(); }
        function onTrackKeyChanged() { root.displayedPosition = media.player ? media.player.position : 0; }
    }
    Connections {
        target: media.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.displayedPosition = media.player ? media.player.position : 0; }
        function onIsPlayingChanged() { root.displayedPosition = media.player ? media.player.position : 0; }
    }
    Timer {
        interval: 500
        repeat: true
        running: root.visible && media.playing && !capsule.seeking
        onTriggered: root.displayedPosition = media.player ? media.player.position : 0
    }
    Connections {
        target: root.bar
        ignoreUnknownSignals: true
        function onActivePopoutChanged() { if (root.opened && root.bar.activePopout !== root) root.close(); }
    }
    Component.onDestruction: {
        if (bar && typeof bar.releasePopout === "function") bar.releasePopout(root);
    }
    AmberolController { id: media; fallbackEnabled: root.settings.fallback !== false; amberolShuffleEnabled: root.settings.amberolMprisShuffle === true }
    DeskbandCapsule {
        id: capsule
        width: root.expandedWidth
        height: parent.height
        controller: media
        hostBar: root.bar
        compact: root.compact
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        popupOpen: root.opened
        displayedPosition: root.displayedPosition
        onExpandRequested: root.togglePanel()
        onSeekStarted: root.seekTrack = media.trackKey
        onSeekCommitted: function(value) { media.seekTo(value, root.seekTrack || media.trackKey); root.seekTrack = ""; root.displayedPosition = media.player ? media.player.position : 0; }
    }
    DeskbandPopup {
        id: popup
        anchorItem: root
        controller: media
        hostBar: root.bar
        open: root.opened
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        background: root.bar && root.bar.popupBackground !== undefined ? root.bar.popupBackground : "#202126"
        displayedPosition: root.displayedPosition
        onCloseRequested: root.close()
    }
}
