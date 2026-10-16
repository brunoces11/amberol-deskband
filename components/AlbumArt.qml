import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string source: ""
    property color foreground: "#eeeeee"
    property color background: "#333333"
    property real radius: 5
    Rectangle { anchors.fill: parent; radius: root.radius; color: root.background }
    Image {
        id: art
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.ceil(root.width * 2)
        sourceSize.height: Math.ceil(root.height * 2)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        color: "white"
        layer.enabled: true
        visible: false
    }
    MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: mask; visible: art.status === Image.Ready }
    Text {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: "♪"
        font.pixelSize: Math.max(14, root.width * 0.35)
        color: root.foreground
    }
}
