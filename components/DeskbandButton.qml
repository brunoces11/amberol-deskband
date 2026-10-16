import QtQuick
import "AmberolController.js" as Colors

Item {
    id: root
    property string glyph: ""
    property string label: ""
    property color foreground: "#eeeeee"
    property color accent: "#e5b567"
    property string fontFamily: "sans-serif"
    property real glyphScale: 1
    property bool selected: false
    property var hostBar: null
    property var registeredHost: null
    signal clicked()
    implicitWidth: 26
    implicitHeight: 28
    opacity: enabled ? 1 : 0.32
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: triggerPress(Qt.LeftButton)
    function triggerPress(button) { if (enabled && button === Qt.LeftButton) clicked(); }
    function registerHost() {
        if (registeredHost && typeof registeredHost.unregisterClickTarget === "function") registeredHost.unregisterClickTarget(root);
        registeredHost = hostBar;
        if (registeredHost && typeof registeredHost.registerClickTarget === "function") registeredHost.registerClickTarget(root);
    }
    onHostBarChanged: registerHost()
    Component.onDestruction: {
        if (registeredHost && typeof registeredHost.unregisterClickTarget === "function") registeredHost.unregisterClickTarget(root);
    }
    Keys.onSpacePressed: triggerPress(Qt.LeftButton)
    Keys.onReturnPressed: triggerPress(Qt.LeftButton)
    Rectangle {
        anchors.fill: parent
        radius: 5
        color: root.selected ? Colors.alpha(root.accent, 0.22) : Colors.alpha(root.foreground, mouse.containsMouse || root.activeFocus ? 0.12 : 0)
        border.width: root.activeFocus ? 1 : 0
        border.color: root.accent
    }
    Text {
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.glyph
        textFormat: Text.PlainText
        font.family: root.fontFamily
        font.pixelSize: Math.min(16 * root.glyphScale, root.height - 4)
        color: root.selected ? root.accent : root.foreground
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.triggerPress(Qt.LeftButton)
        onEntered: if (root.hostBar && typeof root.hostBar.showTooltip === "function") root.hostBar.showTooltip(root, root.label)
        onExited: if (root.hostBar && typeof root.hostBar.hideTooltip === "function") root.hostBar.hideTooltip(root)
    }
}
