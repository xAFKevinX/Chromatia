// Round Chromatia button: icon and optional text, accent color when checked
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

AbstractButton {
    id: pill
    required property QtObject pal
    property real s: 1
    property string label
    property string iconSource
    // confirm: the first click arms the button (shows "label?"), a second click within 4 s fires confirmed()
    property bool confirm: false
    property string confirmLabel
    property bool armed: false
    signal confirmed()
    readonly property string shown: armed ? confirmLabel + "?" : label
    readonly property bool lit: checked || armed
    text: confirm ? confirmLabel : label
    hoverEnabled: true
    implicitHeight: Math.round(38 * s)
    implicitWidth: shown ? row.implicitWidth + Math.round(32 * s) : implicitHeight
    Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    onClicked: {
        if (!confirm) return;
        if (armed) { armed = false; confirmed(); }
        else { armed = true; disarm.restart(); }
    }
    ToolTip.visible: confirm && hovered && !armed
    ToolTip.text: confirmLabel
    ToolTip.delay: 600
    Timer { id: disarm; interval: 4000; onTriggered: pill.armed = false }
    opacity: enabled ? 1 : 0.5
    background: Rectangle {
        radius: height / 2
        color: pill.lit ? pill.pal.accent
             : (pill.hovered || pill.visualFocus) ? Qt.alpha(pill.pal.card2, 0.95) : Qt.alpha(pill.pal.card, 0.85)
        border.width: pill.lit ? 0 : 1
        border.color: Qt.alpha(pill.pal.card2, 0.9)
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(8 * pill.s)
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(18 * pill.s); height: width
                source: pill.iconSource
                isMask: true
                color: pill.lit ? "white" : pill.pal.text
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.shown !== ""
                text: pill.shown
                color: pill.lit ? "white" : pill.pal.text
                font.pixelSize: Math.round(14 * pill.s)
                font.bold: pill.lit
            }
        }
    }
}
