import QtQuick
import "AmberolController.js" as Colors

Item {
    id: root
    required property var controller
    property var hostBar: null
    property bool compact: false
    property color foreground: "#eeeeee"
    property color accent: "#e5b567"
    property string fontFamily: "sans-serif"
    property bool popupOpen: false
    property real displayedPosition: 0
    readonly property real itemSpacing: 3.4
    readonly property color backdrop: hostBar && hostBar.background !== undefined ? hostBar.background : "#1b1d2a"
    readonly property int buttonSize: compact ? 22 : 26
    signal expandRequested()
    signal seekStarted()
    signal seekCommitted(real value)
    readonly property bool seeking: progress.dragging
    clip: true
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.min(12, height / 2)
        color: Colors.lighterGraySurface(root.backdrop, root.foreground, 0.055, 1.265)
        border.width: 1
        border.color: Colors.alpha(root.foreground, 0.12)
    }
    Row {
        y: root.compact ? 0 : 2
        x: 8
        height: root.compact ? parent.height : 26
        spacing: root.itemSpacing
        Item {
            width: Math.max(24, root.width - 16 - root.buttonSize * 5 - root.itemSpacing * 6)
            height: root.compact ? 18 : 30
            anchors.verticalCenter: parent.verticalCenter
            Column {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text { width: parent.width; text: root.controller.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: root.compact ? 10 : 11; font.weight: Font.Medium }
                Text { width: parent.width; visible: !root.compact; text: root.controller.artist; textFormat: Text.PlainText; elide: Text.ElideRight; color: Colors.alpha(root.foreground, 0.64); font.family: root.fontFamily; font.pixelSize: 8 }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                onEntered: if (root.hostBar && typeof root.hostBar.showTooltip === "function") root.hostBar.showTooltip(root, root.controller.title + " — " + root.controller.artist)
                onExited: if (root.hostBar && typeof root.hostBar.hideTooltip === "function") root.hostBar.hideTooltip(root)
            }
        }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 24; anchors.verticalCenter: parent.verticalCenter; glyph: "󰒮"; label: "Faixa anterior"; enabled: !!(root.controller.player && root.controller.player.canGoPrevious); foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.previous() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 24; anchors.verticalCenter: parent.verticalCenter; glyph: root.controller.playing ? "󰏤" : "󰐊"; label: root.controller.playing ? "Pausar" : "Reproduzir"; enabled: root.controller.canToggle; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.togglePlaying() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 24; anchors.verticalCenter: parent.verticalCenter; glyph: "󰒭"; label: "Próxima faixa"; enabled: !!(root.controller.player && root.controller.player.canGoNext); foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.next() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 24; anchors.verticalCenter: parent.verticalCenter; glyph: "󰒟"; label: root.controller.canShuffle ? "Alternar aleatório" : "Aleatório indisponível neste player"; enabled: root.controller.canShuffle; selected: !!(root.controller.player && root.controller.player.shuffle); foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.toggleShuffle() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 24; anchors.verticalCenter: parent.verticalCenter; glyph: root.popupOpen ? "⌄" : "⌃"; label: "Expandir player"; selected: root.popupOpen; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.expandRequested() }
    }
    DeskbandSlider {
        id: progress
        visible: !root.compact
        x: 14
        y: parent.height - 12
        width: parent.width - 28
        height: 10
        compact: true
        label: "Posição da faixa"
        maximum: root.controller.player && root.controller.player.length > 0 ? root.controller.player.length : 1
        value: root.displayedPosition
        enabled: root.controller.canSeek
        foreground: root.foreground
        accent: root.accent
        onStarted: root.seekStarted()
        onCommitted: function(value) { root.seekCommitted(value); }
    }
}
