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
    readonly property real itemSpacing: 3.4
    readonly property color backdrop: hostBar && hostBar.background !== undefined ? hostBar.background : "#1b1d2a"
    readonly property int artSize: compact ? 18 : 28
    readonly property int buttonSize: compact ? 22 : 26
    signal expandRequested()
    clip: true
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.min(12, height / 2)
        color: Colors.lighterGraySurface(root.backdrop, root.foreground, 0.055, 1.10)
        border.width: 1
        border.color: Colors.alpha(root.foreground, 0.12)
    }
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        spacing: root.itemSpacing
        AlbumArt { width: root.artSize; height: width; anchors.verticalCenter: parent.verticalCenter; source: root.controller.artUrl; foreground: root.foreground }
        Item {
            width: Math.max(24, root.width - 16 - root.artSize - root.buttonSize * 5 - root.itemSpacing * 6)
            height: root.compact ? 18 : 30
            anchors.verticalCenter: parent.verticalCenter
            Column {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text { width: parent.width; text: root.controller.title; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: root.compact ? 10 : 11; font.weight: Font.Medium }
                Text { width: parent.width; visible: !root.compact; text: root.controller.artist; textFormat: Text.PlainText; elide: Text.ElideRight; color: Colors.alpha(root.foreground, 0.64); font.family: root.fontFamily; font.pixelSize: 10 }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                onEntered: if (root.hostBar && typeof root.hostBar.showTooltip === "function") root.hostBar.showTooltip(root, root.controller.title + " — " + root.controller.artist)
                onExited: if (root.hostBar && typeof root.hostBar.hideTooltip === "function") root.hostBar.hideTooltip(root)
            }
        }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 28; anchors.verticalCenter: parent.verticalCenter; glyph: "󰒮"; label: "Faixa anterior"; enabled: !!(root.controller.player && root.controller.player.canGoPrevious); foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.previous() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 28; anchors.verticalCenter: parent.verticalCenter; glyph: root.controller.playing ? "󰏤" : "󰐊"; label: root.controller.playing ? "Pausar" : "Reproduzir"; enabled: root.controller.canToggle; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.togglePlaying() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 28; anchors.verticalCenter: parent.verticalCenter; glyph: "󰒭"; label: "Próxima faixa"; enabled: !!(root.controller.player && root.controller.player.canGoNext); foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.next() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 28; anchors.verticalCenter: parent.verticalCenter; glyph: "󰒟"; label: root.controller.canShuffle ? "Alternar aleatório" : "Aleatório indisponível neste player"; enabled: root.controller.canShuffle; selected: !!(root.controller.player && root.controller.player.shuffle); foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.controller.toggleShuffle() }
        DeskbandButton { width: root.buttonSize; height: root.compact ? 20 : 28; anchors.verticalCenter: parent.verticalCenter; glyph: root.popupOpen ? "⌄" : "⌃"; label: "Expandir player"; selected: root.popupOpen; foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily; hostBar: root.hostBar; onClicked: root.expandRequested() }
    }
}
