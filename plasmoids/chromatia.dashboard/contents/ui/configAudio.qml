// Chromatia Settings – Audio: which devices the dashboard shows, and their names
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.private.volume

KCM.SimpleKCM {
    id: page

    property string cfg_hiddenOutputs
    property string cfg_hiddenInputs
    property string cfg_deviceNames

    function arr(t) { try { return JSON.parse(t || "[]"); } catch (e) { return []; } }
    function obj(t) { try { return JSON.parse(t || "{}"); } catch (e) { return {}; } }

    function setShown(mic, name, shown) {
        const a = arr(mic ? cfg_hiddenInputs : cfg_hiddenOutputs).filter(n => n !== name);
        if (!shown) a.push(name);
        if (mic) cfg_hiddenInputs = JSON.stringify(a); else cfg_hiddenOutputs = JSON.stringify(a);
    }
    function setLabel(name, text) {
        const o = obj(cfg_deviceNames);
        if (text.trim() === "") delete o[name]; else o[name] = text.trim();
        cfg_deviceNames = JSON.stringify(o);
    }

    component Device: RowLayout {
        id: row
        property bool mic: false
        property string devName
        property string devDesc
        readonly property bool shown: page.arr(mic ? page.cfg_hiddenInputs : page.cfg_hiddenOutputs).indexOf(devName) < 0
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        QQC2.CheckBox {
            checked: row.shown
            onToggled: page.setShown(row.mic, row.devName, checked)
            QQC2.ToolTip.text: "Show in the dashboard"
            QQC2.ToolTip.visible: hovered
        }
        QQC2.Label {
            text: row.devDesc
            elide: Text.ElideRight
            Layout.fillWidth: true
            opacity: row.shown ? 1 : 0.5
        }
        QQC2.TextField {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
            placeholderText: "Own name (optional)"
            text: page.obj(page.cfg_deviceNames)[row.devName] || ""
            enabled: row.shown
            onEditingFinished: page.setLabel(row.devName, text)
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Choose which devices appear in the dashboard's Audio tab. Unticked devices stay hidden. Give them short names if the system names are too long."
        }

        Kirigami.Heading { text: "Output"; level: 3 }
        Repeater {
            model: SinkModel {}
            delegate: Device {
                required property var model
                devName: String(model.Name || "")
                devDesc: String(model.Description || model.Name || "")
            }
        }

        Kirigami.Heading { text: "Microphone"; level: 3; Layout.topMargin: Kirigami.Units.largeSpacing }
        Repeater {
            model: SourceModel {}
            delegate: Device {
                required property var model
                mic: true
                visible: devName.indexOf(".monitor") < 0
                devName: String(model.Name || "")
                devDesc: String(model.Description || model.Name || "")
            }
        }
    }
}
