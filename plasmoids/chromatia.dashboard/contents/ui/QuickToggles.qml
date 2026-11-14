// Wi-Fi and Bluetooth pills next to the gear. Loaded through a Loader, so a system
// without plasma-nm or bluez-qt only loses the pills, not the dashboard.
// A pill only shows when it's enabled in the settings and the hardware exists.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.bluezqt as BluezQt
import org.kde.plasma.networkmanagement as PlasmaNM

Row {
    id: qt
    spacing: 8
    required property var dash    // main.qml root, for the colors

    PlasmaNM.AvailableDevices { id: devices }
    PlasmaNM.EnabledConnections { id: enabled }
    PlasmaNM.Handler { id: nm }

    Repeater {
        model: [
            { show: Plasmoid.configuration.wifiToggle && devices.wirelessDeviceAvailable,
              on: enabled.wirelessEnabled, icon: "network-wireless", off: "network-wireless-disconnected",
              toggle: () => nm.enableWireless(!enabled.wirelessEnabled) },
            { show: Plasmoid.configuration.bluetoothToggle && BluezQt.Manager.adapters.length > 0,
              on: BluezQt.Manager.bluetoothOperational, icon: "network-bluetooth", off: "network-bluetooth-inactive",
              toggle: () => {      // same as KDE's Bluetooth applet: unblock, then power every adapter
                  const on = !BluezQt.Manager.bluetoothOperational;
                  BluezQt.Manager.bluetoothBlocked = !on;
                  for (const a of BluezQt.Manager.adapters) a.powered = on;
              } }
        ]
        Rectangle {
            visible: modelData.show
            width: 34; height: 34; radius: 17
            color: modelData.on ? qt.dash.accent : (mouse.containsMouse ? qt.dash.cCard2 : qt.dash.cCard)
            Behavior on color { ColorAnimation { duration: 160 } }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: (modelData.on ? modelData.icon : modelData.off) + "-symbolic"
                isMask: true
                color: modelData.on ? "white" : qt.dash.cDim
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.toggle()
            }
        }
    }
}
