/*
    Chromatia unlock card: avatar with accent ring, name, password pill, messages, extra rows.
    The password logic is the one of Plasma's MainBlock.qml (SPDX: 2016 David Edmundson, LGPL-2.0-or-later).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.breeze.components

Item {
    id: block
    required property QtObject pal
    property real s: 1
    property alias passwordInputVisible: pill.visible
    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    property alias showPassword: passwordBox.showPassword
    property var userListModel
    readonly property string userName: userListModel && userListModel.count ? userListModel.get(0).realName : ""
    property string notificationMessage
    default property alias content: extra.data
    readonly property Item card: column             // the clock keeps its distance to this
    signal passwordResult(string password)

    function startLogin() {
        const password = passwordBox.text
        // looks nicer and works around QTBUG-55460 (app closed with a focused TextField)
        unlockButton.forceActiveFocus();
        passwordResult(password);
    }
    function playHighlightAnimation() { bounce.start(); }

    ColumnLayout {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.5 - avatarRing.height / 2)
        width: Math.max(Math.round(380 * block.s), extra.implicitWidth)
        spacing: Math.round(14 * block.s)

        Rectangle {         // avatar with accent ring
            id: avatarRing
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(118 * block.s); implicitHeight: implicitWidth
            radius: width / 2
            color: "transparent"
            border.width: Math.max(2, Math.round(3 * block.s))
            border.color: block.pal.accent
            Kirigami.ShadowedImage {
                id: avatar
                anchors.fill: parent
                anchors.margins: Math.round(8 * block.s)
                radius: width / 2
                color: block.pal.card2
                source: block.userListModel && block.userListModel.count ? block.userListModel.get(0).icon : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                Text {      // initial when there is no picture
                    anchors.centerIn: parent
                    visible: avatar.status !== Image.Ready
                    text: block.userName.charAt(0).toUpperCase()
                    color: block.pal.text
                    font.pixelSize: Math.round(parent.height * 0.45); font.weight: Font.Black
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: block.userName
            color: block.pal.text
            font.pixelSize: Math.round(24 * block.s); font.bold: true
        }

        Rectangle {         // password pill
            id: pill
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.round(380 * block.s)
            Layout.topMargin: Math.round(6 * block.s)
            implicitHeight: Math.round(50 * block.s)
            radius: height / 2
            color: Qt.alpha(block.pal.base, 0.82)
            border.width: Math.max(1, Math.round(2 * block.s))
            border.color: passwordBox.activeFocus ? block.pal.accent : Qt.alpha(block.pal.card2, 0.9)
            Behavior on border.color { ColorAnimation { duration: 160 } }

            Kirigami.Icon {
                id: lockIcon
                anchors.left: parent.left; anchors.leftMargin: Math.round(18 * block.s)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(18 * block.s); height: width
                source: "lock"; isMask: true; color: block.pal.dim
            }
            PlasmaExtras.PasswordField {
                id: passwordBox
                anchors.left: lockIcon.right; anchors.leftMargin: Math.round(6 * block.s)
                anchors.right: unlockButton.left; anchors.rightMargin: Math.round(4 * block.s)
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Math.round(16 * block.s)
                color: block.pal.text
                placeholderTextColor: block.pal.dim
                selectionColor: block.pal.accent
                background: Item {}
                text: PasswordSync.password
                placeholderText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:placeholder in text field", "Password")
                focus: true
                // used to wake out of screensaver mode; no cursor flashing while invisible
                cursorVisible: visible

                onAccepted: {
                    if (block.lockScreenUiVisible) {
                        block.startLogin();
                    }
                }
                Connections {
                    target: root
                    function onClearPassword() {
                        passwordBox.forceActiveFocus()
                        passwordBox.text = "";
                        passwordBox.text = Qt.binding(() => PasswordSync.password);
                    }
                    function onNotificationRepeated() {
                        block.playHighlightAnimation();
                    }
                }
            }
            Binding {
                target: PasswordSync
                property: "password"
                value: passwordBox.text
            }
            Rectangle {
                id: unlockButton
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button accessible only", "Unlock")
                anchors.right: parent.right; anchors.rightMargin: Math.round(6 * block.s)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height - Math.round(12 * block.s); height: width
                radius: width / 2
                color: unlockMouse.containsMouse || activeFocus ? Qt.lighter(block.pal.accent, 1.15) : block.pal.accent
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.5); height: width
                    source: LayoutMirroring.enabled ? "go-previous" : "go-next"
                    isMask: true; color: "white"
                }
                MouseArea {
                    id: unlockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: block.startLogin()
                }
                Keys.onEnterPressed: block.startLogin()
                Keys.onReturnPressed: block.startLogin()
                Keys.onSpacePressed: block.startLogin()
            }
        }

        Text {              // caps lock, "Unlocking failed", PAM messages
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.round(380 * block.s)
            Layout.preferredHeight: Math.round(20 * block.s)
            horizontalAlignment: Text.AlignHCenter
            text: block.notificationMessage
            textFormat: Text.PlainText
            color: block.pal.soft
            font.pixelSize: Math.round(14 * block.s)
            wrapMode: Text.WordWrap
            opacity: text ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        FailableLabel {
            kind: ScreenLocker.Authenticator.Fingerprint
            label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your fingerprint on the reader)")
        }
        FailableLabel {
            kind: ScreenLocker.Authenticator.Smartcard
            label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:usagetip", "(or scan your smartcard)")
        }

        ColumnLayout {
            id: extra
            Layout.fillWidth: true
            spacing: Math.round(12 * block.s)
        }
    }

    RejectPasswordAnimation {
        id: rejectAnimation
        target: pill
    }
    SequentialAnimation {
        id: bounce
        NumberAnimation { target: pill; property: "scale"; to: 1.04; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: pill; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
    }
    function rejectPassword() { rejectAnimation.start(); }

    component FailableLabel : PlasmaComponents3.Label {
        id: _failableLabel
        required property int kind
        required property string label

        visible: authenticator.authenticatorTypes & kind
        text: label
        color: block.pal.dim
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true

        RejectPasswordAnimation {
            id: _rejectAnimation
            target: _failableLabel
            onFinished: _timer.restart()
        }
        Connections {
            target: authenticator
            function onNoninteractiveError(kind, authenticator) {
                if (kind & _failableLabel.kind) {
                    _failableLabel.text = Qt.binding(() => authenticator.errorMessage)
                    _rejectAnimation.start()
                }
            }
        }
        Timer {
            id: _timer
            interval: Kirigami.Units.humanMoment
            onTriggered: _failableLabel.text = Qt.binding(() => _failableLabel.label)
        }
    }
}
