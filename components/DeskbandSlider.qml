import QtQuick
import "AmberolController.js" as Colors

Item {
    id: root
    property real value: 0
    property real maximum: 1
    property real liveValue: value
    property color foreground: "#eeeeee"
    property color accent: "#e5b567"
    property string label: ""
    readonly property bool dragging: mouse.pressed
    readonly property real fraction: Math.max(0, Math.min(1, liveValue / Math.max(0.001, maximum)))
    signal started()
    signal committed(real value)
    implicitHeight: 28
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: label
    onValueChanged: if (!dragging) liveValue = value
    onMaximumChanged: if (!dragging) liveValue = value
    function at(x) { return Math.max(0, Math.min(1, x / Math.max(1, width))) * maximum; }
    Keys.onLeftPressed: committed(Math.max(0, value - maximum / 100))
    Keys.onRightPressed: committed(Math.min(maximum, value + maximum / 100))
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Colors.alpha(root.foreground, 0.18) }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * root.fraction; height: 4; radius: 2; color: root.accent }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(root.width - width, root.width * root.fraction - width / 2))
        width: 12; height: 12; radius: 6
        color: root.foreground
        border.width: root.activeFocus ? 2 : 0
        border.color: root.accent
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(event) { root.started(); root.liveValue = root.at(event.x); }
        onPositionChanged: function(event) { if (pressed) root.liveValue = root.at(event.x); }
        onReleased: function(event) { root.committed(root.at(event.x)); root.liveValue = Qt.binding(function() { return root.value; }); }
        onCanceled: root.liveValue = Qt.binding(function() { return root.value; })
    }
    opacity: enabled ? 1 : 0.35
}
