import QtQuick
import QtTest
import "../components"

TestCase {
    name: "DeskbandSlider"
    width: 240
    height: 60

    DeskbandSlider {
        id: slider
        x: 10
        y: 10
        width: 200
        maximum: 100
        value: 20
        compact: true
    }

    function test_compact_progress_is_small_and_maps_position() {
        compare(slider.implicitHeight, 10);
        verify(Math.abs(slider.at(150) - 75) < 1);
    }
}
