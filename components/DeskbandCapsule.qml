import QtQuick
import QtQuick.Shapes
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
    signal iconAltClicked()
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

        Item {
            id: dynamicIconContainer
            anchors.centerIn: parent
            width: root.compact ? 20 : 24
            height: root.compact ? 20 : 24

            // Estado Stand-by / Pause: Círculo branco vazado com 29% de opacidade + Seta de Play
            Item {
                id: pauseVisual
                anchors.fill: parent
                opacity: root.controller.playing ? 0.0 : 1.0
                scale: root.controller.playing ? 0.72 : 1.0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: root.compact ? 2 : 2.5
                    border.color: Qt.rgba(1, 1, 1, 0.29)
                }

                Shape {
                    id: playArrow
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.compact ? 1 : 1.2
                    width: root.compact ? 7 : 8.5
                    height: root.compact ? 8 : 10
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(1, 1, 1, 0.88)
                        startX: 0
                        startY: 0
                        PathLine { x: playArrow.width; y: playArrow.height / 2 }
                        PathLine { x: 0; y: playArrow.height }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }

            // Estado Play / Tocando: Mini Equalizer com 3 barrinhas animadas e degradê deslizante
            Item {
                id: playVisual
                anchors.fill: parent
                opacity: root.controller.playing ? 1.0 : 0.0
                scale: root.controller.playing ? 1.0 : 0.72
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                property real shimmerPhase: 0.0
                NumberAnimation on shimmerPhase {
                    from: 0.0
                    to: 1.0
                    duration: 2200
                    loops: Animation.Infinite
                    running: root.controller.playing
                }

                function barColor(index) {
                    var wave = 0.5 + 0.5 * Math.sin(playVisual.shimmerPhase * 6.28318 - index * 1.15)
                    return Qt.tint(root.accent, Qt.rgba(1, 1, 1, wave * 0.35))
                }

                Row {
                    anchors.centerIn: parent
                    spacing: root.compact ? 1.5 : 2
                    height: root.compact ? 12 : 14

                    // Barra 1
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: root.compact ? 2 : 2.5
                        radius: width / 2
                        color: playVisual.barColor(0)
                        height: root.compact ? 4 : 5
                        SequentialAnimation on height {
                            running: root.controller.playing
                            loops: Animation.Infinite
                            NumberAnimation { to: root.compact ? 11 : 13; duration: 380; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 4 : 5; duration: 320; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 8 : 10; duration: 280; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 3 : 4; duration: 360; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Barra 2 (Central)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: root.compact ? 2 : 2.5
                        radius: width / 2
                        color: playVisual.barColor(1)
                        height: root.compact ? 6 : 8
                        SequentialAnimation on height {
                            running: root.controller.playing
                            loops: Animation.Infinite
                            NumberAnimation { to: root.compact ? 5 : 6; duration: 290; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 12 : 14; duration: 420; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 6 : 8; duration: 310; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 11 : 13; duration: 340; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Barra 3
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: root.compact ? 2 : 2.5
                        radius: width / 2
                        color: playVisual.barColor(2)
                        height: root.compact ? 3 : 4
                        SequentialAnimation on height {
                            running: root.controller.playing
                            loops: Animation.Infinite
                            NumberAnimation { to: root.compact ? 10 : 11; duration: 350; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 3 : 3; duration: 400; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 10 : 12; duration: 300; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: root.compact ? 5 : 6; duration: 370; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property bool altPressedAtDown: false

            onPressed: function(mouse) {
                altPressedAtDown = (mouse.modifiers & (Qt.AltModifier | Qt.MetaModifier | Qt.GroupSwitchModifier)) !== 0
            }

            onCanceled: {
                altPressedAtDown = false
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    var hasAlt = altPressedAtDown || ((mouse.modifiers & (Qt.AltModifier | Qt.MetaModifier | Qt.GroupSwitchModifier)) !== 0)
                    altPressedAtDown = false
                    if (hasAlt) {
                        root.iconAltClicked()
                    } else {
                        root.iconClicked()
                    }
                } else if (mouse.button === Qt.RightButton) {
                    root.iconRightClicked()
                } else if (mouse.button === Qt.MiddleButton) {
                    root.iconMiddleClicked()
                }
            }
            onEntered: {
                if (root.hostBar && typeof root.hostBar.showTooltip === "function") {
                    var titleInfo = root.controller.title ? (root.controller.title + "\n") : ""
                    var tip = titleInfo + "Clique: " + (root.isExpanded ? "Recolher (Ultra Compacto)" : "Expandir (Compacto)") +
                        " • Alt+Clique: " + (root.controller.playing ? "Pausar" : "Tocar")
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
                label: root.popupOpen ? "Ocultar Menu" : "Exibir Menu"
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
