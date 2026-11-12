// Einstellungsseite für „Bild mit Visualizer“ (Rechtsklick Desktop → Hintergrund einrichten).
import QtQuick
import QtCore
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property string cfg_Image
    property int cfg_BarHeight
    property int cfg_BottomOffset
    property bool cfg_VisualizerEnabled

    Image {
        Kirigami.FormData.label: "Image:"
        source: page.cfg_Image
        Layout.preferredWidth: 320
        Layout.preferredHeight: 180
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    QQC2.Button {
        text: "Choose image …"
        icon.name: "document-open"
        onClicked: picker.open()
    }

    QQC2.Label {
        text: "The frame is drawn automatically."
        opacity: 0.7
    }

    QQC2.CheckBox {
        Kirigami.FormData.label: "Visualizer:"
        text: "Show bars above the bottom bar"
        checked: page.cfg_VisualizerEnabled
        onToggled: page.cfg_VisualizerEnabled = checked
    }

    QQC2.SpinBox {
        Kirigami.FormData.label: "Maximum bar height:"
        from: 20; to: 300; stepSize: 10
        value: page.cfg_BarHeight
        onValueModified: page.cfg_BarHeight = value
    }

    FileDialog {
        id: picker
        title: "Choose wallpaper"
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: ["Images and videos (*.png *.jpg *.jpeg *.webp *.avif *.bmp *.mp4 *.webm *.mkv *.mov *.m4v)"]
        onAccepted: page.cfg_Image = selectedFile.toString()
    }
}
