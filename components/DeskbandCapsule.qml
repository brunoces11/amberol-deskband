import QtQuick
import Quickshell
import "AmberolController.js" as Colors

Item {
    id: root
    required property var controller
    property var hostBar: null
    property bool compact: false
    property bool isExpanded: false
    property color foreground: "#eeeeee"
    property color accent: "#e5b567"
    property string fontFamily: "sans-serif"
    property bool popupOpen: false
    property real displayedPosition: 0
    readonly property real itemSpacing: 1.547
    readonly property color backdrop: hostBar && hostBar.background !== undefined ? hostBar.background : "#1b1d2a"
    readonly property int buttonSize: compact ? 22 : 24
    readonly property real controlPaddingFactor: 0.78
    readonly property real controlIconSize: 16 * 0.85
    readonly property real controlButtonHorizontalPadding: compact
        ? ((22 - root.controlIconSize) / 2) * root.controlPaddingFactor
        : ((24 - root.controlIconSize) / 2) * root.controlPaddingFactor
    readonly property real controlButtonVerticalPadding: compact
        ? ((20 - root.controlIconSize) / 2) * root.controlPaddingFactor
        : ((22 - root.controlIconSize) / 2) * root.controlPaddingFactor
    readonly property real controlButtonWidth: root.controlIconSize + root.controlButtonHorizontalPadding * 2
    readonly property real controlButtonHeight: root.controlIconSize + root.controlButtonVerticalPadding * 2

    signal iconClicked()
    signal iconRightClicked()
    signal iconMiddleClicked()
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

    // Sessão 1: Ícone do Amberol + Linha divisória fina
    Item {
        id: iconSection
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.isExpanded ? (root.compact ? 28 : 36) : (parent.width - 4)

        Rectangle {
            id: iconHover
            anchors.centerIn: parent
            width: root.compact ? 22 : 28
            height: root.compact ? 22 : 28
            radius: 6
            color: iconMouse.containsMouse ? Colors.alpha(root.foreground, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Image {
            id: amberolIcon
            anchors.centerIn: parent
            width: root.compact ? 18 : 22
            height: root.compact ? 18 : 22
            source: Quickshell.iconPath("io.bassi.Amberol", true) || "file:///usr/share/icons/hicolor/scalable/apps/io.bassi.Amberol.svg"
            sourceSize: Qt.size(24, 24)
            smooth: true
            mipmap: true
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.iconClicked()
                } else if (mouse.button === Qt.RightButton) {
                    root.iconRightClicked()
                } else if (mouse.button === Qt.MiddleButton) {
                    root.iconMiddleClicked()
                }
            }
            onEntered: {
                if (root.hostBar && typeof root.hostBar.showTooltip === "function") {
                    var tip = root.isExpanded
                        ? (root.controller.title ? (root.controller.title + " (Clique: Pausar e Recolher)") : "Amberol (Pausar e Recolher)")
                        : "Amberol (Tocar e Expandir)"
                    root.hostBar.showTooltip(iconMouse, tip)
                }
            }
            onExited: {
                if (root.hostBar && typeof root.hostBar.hideTooltip === "function") {
                    root.hostBar.hideTooltip(iconMouse)
                }
            }
        }

        Rectangle {
            id: verticalDivider
            visible: root.isExpanded && !root.compact
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 20
            radius: 0.5
            color: Colors.alpha(root.foreground, 0.18)
        }
    }

    // Sessão 3: Bloco de Transporte (Botões na linha de cima e Seek na linha de baixo)
    Item {
        id: transportSection
        visible: root.isExpanded
        opacity: root.isExpanded ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: controlsRow.width

        Row {
            id: controlsRow
            anchors.top: parent.top
            anchors.topMargin: root.compact ? Math.round((parent.height - root.controlButtonHeight) / 2) : 3
            spacing: root.itemSpacing

            DeskbandButton {
                width: root.controlButtonWidth
                height: root.controlButtonHeight
                horizontalPadding: root.controlButtonHorizontalPadding
                verticalPadding: root.controlButtonVerticalPadding
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰒮"
                label: "Faixa anterior"
                enabled: !!(root.controller.player && root.controller.player.canGoPrevious)
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                glyphScale: 0.85
                hostBar: root.hostBar
                onClicked: root.controller.previous()
            }
            DeskbandButton {
                width: root.controlButtonWidth
                height: root.controlButtonHeight
                horizontalPadding: root.controlButtonHorizontalPadding
                verticalPadding: root.controlButtonVerticalPadding
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.controller.playing ? "󰏤" : "󰐊"
                label: root.controller.playing ? "Pausar" : "Reproduzir"
                enabled: root.controller.canToggle
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                glyphScale: 0.85
                hostBar: root.hostBar
                onClicked: root.controller.togglePlaying()
            }
            DeskbandButton {
                width: root.controlButtonWidth
                height: root.controlButtonHeight
                horizontalPadding: root.controlButtonHorizontalPadding
                verticalPadding: root.controlButtonVerticalPadding
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰒭"
                label: "Próxima faixa"
                enabled: !!(root.controller.player && root.controller.player.canGoNext)
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                glyphScale: 0.85
                hostBar: root.hostBar
                onClicked: root.controller.next()
            }
            DeskbandButton {
                width: root.buttonSize
                height: root.compact ? 20 : 22
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰒟"
                label: root.controller.canShuffle ? "Alternar aleatório" : "Aleatório indisponível neste player"
                enabled: root.controller.canShuffle
                selected: !!(root.controller.player && root.controller.player.shuffle)
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                glyphScale: 0.85
                hostBar: root.hostBar
                onClicked: root.controller.toggleShuffle()
            }
            DeskbandButton {
                width: root.buttonSize
                height: root.compact ? 20 : 22
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.popupOpen ? "⌄" : "⌃"
                label: "Expandir player"
                selected: root.popupOpen
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                glyphScale: 0.85
                hostBar: root.hostBar
                onClicked: root.expandRequested()
            }
        }

        DeskbandSlider {
            id: progress
            visible: !root.compact && root.isExpanded
            anchors.top: controlsRow.bottom
            anchors.topMargin: 1
            anchors.left: controlsRow.left
            anchors.right: controlsRow.right
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

    // Sessão 2: Metadados da Faixa (Título em cima, Artista embaixo em 2 linhas)
    Item {
        id: metadataSection
        visible: root.isExpanded
        opacity: root.isExpanded ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        anchors.left: iconSection.right
        anchors.leftMargin: 8
        anchors.right: transportSection.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: textCol.height

        Column {
            id: textCol
            width: parent.width
            anchors.centerIn: parent
            spacing: 1

            Text {
                width: parent.width
                text: root.controller.title || "Amberol"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: root.compact ? 9 : 11
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                visible: !root.compact
                text: root.controller.artist || ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Colors.alpha(root.foreground, 0.64)
                font.family: root.fontFamily
                font.pixelSize: 9
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: if (root.hostBar && typeof root.hostBar.showTooltip === "function") root.hostBar.showTooltip(metadataSection, root.controller.title + " — " + root.controller.artist)
            onExited: if (root.hostBar && typeof root.hostBar.hideTooltip === "function") root.hostBar.hideTooltip(metadataSection)
        }
    }
}
