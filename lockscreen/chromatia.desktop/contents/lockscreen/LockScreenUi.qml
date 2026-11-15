/*
    Chromatia lock screen. The unlock logic (authenticator, PAM timeouts, fade timers, keys)
    is Plasma's LockScreenUi.qml, only the look is Chromatia.
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 Kristen McWilliam <kristen@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.accessibility
import org.kde.plasma.workspace.components as PW
import org.kde.plasma.workspace.keyboardlayout as Keyboards
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.ki18n

import org.kde.plasma.private.sessions
import org.kde.breeze.components

Item {
    id: lockScreenUi

    // Whether we expect a given authenticator to prompt for a credential at all.
    property bool expectingPrompt: false // this is set for real when an authenticator is selected
    // Whether we are expected to visualize the prompt message for the authenticator
    property bool showPrompt: false // this is set for real when an authenticator is selected

    // size factor: designed for 1080p, follows the screen
    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))

    // Chromatia colors, all from the accent color (like the widgets)
    QtObject {
        id: colors
        readonly property color accent: (config.accentColor && config.accentColor !== "") ? config.accentColor : Kirigami.Theme.highlightColor
        readonly property real hue: Math.max(0, accent.hslHue)
        readonly property color base: Qt.hsla(hue, 0.25, 0.075, 1)
        readonly property color card: Qt.hsla(hue, 0.20, 0.14, 1)
        readonly property color card2: Qt.hsla(hue, 0.22, 0.22, 1)
        readonly property color text: Qt.hsla(hue, 0.55, 0.90, 1)
        readonly property color time: Qt.hsla(hue, 0.55, 0.92, 1)
        readonly property color soft: Qt.hsla(hue, 0.55, 0.78, 1)
        readonly property color dim: Qt.hsla(hue, 0.25, 0.68, 1)
        readonly property color glow: Qt.hsla(hue, 0.60, 0.66, 1)     // accent that stays visible on dark wallpapers
    }

    function handleMessage(msg) {
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg
        }
        lockScreenRoot.uiVisible = true
    }

    property string pendingPassword

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) { // if this is coming from the noninteractive authenticators
                return;
            }
            const msg = i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed");
            lockScreenUi.handleMessage(msg);
            root.clearPassword();
            authenticator.startAuthenticating();
            notificationRemoveTimer.restart();
            mainBlock.rejectPassword();
        }

        function onSucceeded() {
            // This is important. It stops the all pending authentication processes, preventing timeouts etc.
            authenticator.stopAuthenticating()

            if (!lockScreenUi.expectingPrompt) {
                Qt.quit()
            }
            if (authenticator.hadPrompt) {
                Qt.quit();
            } else {
                mainStack.replace(null, Qt.resolvedUrl("NoPasswordUnlock.qml"),
                    {
                        userListModel: users
                    },
                    StackView.Immediate,
                );
                mainStack.forceActiveFocus();
            }
        }

        function onInfoMessageChanged() {
            lockScreenUi.handleMessage(authenticator.infoMessage);
        }

        function onErrorMessageChanged() {
            lockScreenUi.handleMessage(authenticator.errorMessage);
        }

        function onPromptChanged() {
            lockScreenUi.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged() {
            mainBlock.showPassword = false;
            mainBlock.mainPasswordBox.forceActiveFocus();
            if (lockScreenUi.showPrompt) {
                lockScreenUi.handleMessage(authenticator.promptForSecret);
            }
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    AccessibilityStatus {
        id: accessibilityStatus
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        property bool blockUI: containsMouse && (mainStack.depth > 1 || mainBlock.mainPasswordBox.text.length > 0 || Keyboards.KWinVirtualKeyboard.visible)

        x: parent.x
        y: parent.y
        width: parent.width
        height: parent.height
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true
        onPressed: uiVisible = true;
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
            }

            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            authenticator.startAuthenticating();
        }

        Timer { // heart beat keeping the backend active for as long as we are in visible state
            interval: 1000
            running: !authenticator.unlocked && parent.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }

        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        ScreenLocker.ActiveScreenMonitor {
            id: activeScreenMonitor
            lockscreenState: ScreenLocker.LockscreenState
            window: lockScreenRoot.Window.window
            onActiveChanged: {
                if(!active) {
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Keys.onEscapePressed: {
            // If the escape key is pressed, kscreenlocker will turn off the screen.
            // We do not want to show the password prompt in this case.
            if (uiVisible) {
                uiVisible = false;
                if (Keyboards.KWinVirtualKeyboard.visible) {
                    Keyboards.KWinVirtualKeyboard.active = false;
                }
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }
        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    mainBlock.mainPasswordBox.showPassword = false;
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }

        PropertyAnimation {
            id: launchAnimation
            target: lockScreenRoot
            property: "opacity"
            from: 0
            to: 1
            duration: Kirigami.Units.veryLongDuration * 2
        }

        Component.onCompleted: {
            launchAnimation.start();
            // KDE activates the screen under the mouse cursor. Wayland often doesn't report the cursor
            // before it moves, then the first screen in the list got the keyboard, often a side screen.
            // Start on the primary screen instead (Qt lists it first); moving the mouse still switches.
            const screens = Qt.application.screens;
            if (screens.length > 1 && lockScreenRoot.Screen.name === screens[0].name) primaryActivate.start();
        }
        Timer {     // after kscreenlocker's own activation of "the screen under the cursor"
            id: primaryActivate
            interval: 300
            onTriggered: { lockScreenRoot.Window.window.requestActivate(); lockScreenRoot.uiVisible = true; }
        }

        // video wallpaper (same as on the desktop), muted; the still image stays underneath
        // until the first frame. Pauses after three minutes without input to save power.
        Item {
            id: backdrop
            anchors.fill: parent
            readonly property bool hasVideo: !!config.video && config.video !== ""
            Video {
                id: video
                anchors.fill: parent
                source: backdrop.hasVideo ? config.video : ""
                muted: true
                loops: MediaPlayer.Infinite
                fillMode: VideoOutput.PreserveAspectCrop
                opacity: position > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.veryLongDuration } }
                readonly property bool wanted: backdrop.hasVideo && root.viewVisible && !idlePause.paused
                onWantedChanged: wanted ? play() : pause()
                Component.onCompleted: if (wanted) play()
            }
            Timer {
                id: idlePause
                property bool paused: false
                interval: 180000
                running: !lockScreenRoot.uiVisible
                onTriggered: paused = true
                onRunningChanged: if (running === false) paused = false
            }
        }

        // wallpaper: blurred and dimmed while the unlock card is shown
        WallpaperFader {
            anchors.fill: parent
            state: lockScreenRoot.uiVisible ? "on" : "off"
            mainStack: mainStack
            footer: footer
            clock: clock
            alwaysShowClock: config.alwaysShowClock && !config.hideClockWhenIdle

            // the video once it shows its first frame, the still image before that
            Component.onCompleted: source = Qt.binding(() => video.opacity > 0.5 ? backdrop : wallpaper)
        }
        Rectangle {         // a little extra tint in the accent hue while unlocking
            anchors.fill: parent
            color: colors.base
            opacity: lockScreenRoot.uiVisible ? 0.35 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad } }
        }

        // the Chromatia frame: a thin border with rounded inner corners, like on the desktop
        Rectangle {
            readonly property int frame: Math.round(10 * lockScreenUi.s)
            readonly property int extra: 60
            anchors.fill: parent
            anchors.margins: -extra
            color: "transparent"
            border.width: frame + extra
            border.color: colors.base
            radius: Math.round(25 * lockScreenUi.s) + border.width
        }

        // big clock: centered while idle, moves up and gets smaller for the unlock card
        ChromaClock {
            id: clock
            pal: colors
            visible: config.alwaysShowClock
            anchors.horizontalCenter: parent.horizontalCenter
            transformOrigin: Item.Top
            readonly property real idleY: Math.round(parent.height * 0.5 - height / 2)
            readonly property real cardY: Math.max(Math.round(40 * lockScreenUi.s),
                                                   Math.round(mainStack.y + mainBlock.card.y - height * 0.62 - 50 * lockScreenUi.s))
            s: lockScreenUi.s
            y: lockScreenRoot.uiVisible ? cardY : idleY
            scale: lockScreenRoot.uiVisible ? 0.62 : 1
            Behavior on y { NumberAnimation { duration: Kirigami.Units.veryLongDuration * 1.5; easing.type: Easing.InOutCubic } }
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.veryLongDuration * 1.5; easing.type: Easing.InOutCubic } }
        }

        ListModel {
            id: users

            Component.onCompleted: {
                users.append({
                    name: kscreenlocker_userName,
                    realName: kscreenlocker_userName,
                    icon: kscreenlocker_userImage !== ""
                          ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                          : "",
                })
            }
        }

        Connections {
            target: authenticator
            function onPamTimeoutChanged(): void {
                if (!authenticator.pamTimeout && lockScreenUi.pendingPassword.length > 0) {
                    authenticator.respond(lockScreenUi.pendingPassword);
                    lockScreenUi.pendingPassword = "";
                    mainBlock.enabled = true;
                }
            }
        }

        StackView {
            id: mainStack
            anchors {
                left: parent.left
                right: parent.right
            }
            height: lockScreenRoot.height
            focus: true //StackView is an implicit focus scope, so we need to give this focus so the item inside will have it

            // this isn't implicit, otherwise items still get processed for the scenegraph
            visible: opacity > 0

            initialItem: MainBlock {
                id: mainBlock
                pal: colors
                s: lockScreenUi.s
                lockScreenUiVisible: lockScreenRoot.uiVisible

                StackView.onStatusChanged: {
                    // prepare for presenting again to the user
                    if (StackView.status === StackView.Activating) {
                        mainPasswordBox.clear();
                        mainPasswordBox.focus = true;
                        root.notification = "";
                    }
                }
                userListModel: users

                notificationMessage: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Caps Lock is on"));
                    }
                    if (accessibilityStatus.slowKeysEnabled) {
                        parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Slow Keys are enabled"));
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    return parts.join(" • ");
                }

                onPasswordResult: password => {
                    if (authenticator.pamTimeout) {
                        lockScreenUi.pendingPassword = password
                        mainBlock.enabled = false
                    } else {
                        authenticator.respond(password)
                    }
                }

                // authentication methods (password, fingerprint, …) when there is more than one
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: authenticationTypeRepeater.count > 1
                    spacing: Math.round(8 * lockScreenUi.s)

                    Repeater {
                        id: authenticationTypeRepeater
                        model: ScreenLocker.AuthenticatorModel

                        delegate: Pill {
                            pal: colors; s: lockScreenUi.s
                            id: authPill
                            required property int type
                            required property string iconName
                            required property bool passwordField
                            required property bool expectingPrompt
                            required property string tooltip
                            required property bool showPrompt
                            required property bool functional

                            onFunctionalChanged: {
                                if (functional) {
                                    return
                                }
                                root.notification = ""
                                mainBlock.passwordInputVisible = false
                                lockScreenUi.handleMessage(KI18n.i18ndc(
                                    "plasma_shell_org.kde.plasma.desktop",
                                    "@info:status",
                                    "This authentication method is not functioning correctly. Please try another method, and check your system configuration."))
                            }

                            // Be careful if you remove this to ensure defunct handling is present in all scenarios (e.g. onClicked)
                            enabled: functional
                            iconSource: iconName
                            label: ""
                            checked: authenticator.authenticator === type
                            onClicked: {
                                authenticator.authenticator = type
                                root.notification = ""
                                mainBlock.passwordInputVisible = passwordField
                                lockScreenUi.expectingPrompt = expectingPrompt
                                lockScreenUi.showPrompt = showPrompt
                            }

                            PlasmaComponents3.ToolTip.text: tooltip
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered

                            Component.onCompleted: {
                                if (checked) {
                                    clicked()
                                }
                            }
                        }
                    }
                }

                // sleep, hibernate, switch user, restart, shut down
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Math.round(4 * lockScreenUi.s)
                    spacing: Math.round(8 * lockScreenUi.s)
                    Pill {
                        pal: colors; s: lockScreenUi.s
                        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Slee&p").replace("&", "")
                        iconSource: "system-suspend"
                        onClicked: sessionManagement.suspend()
                        visible: sessionManagement.canSuspend
                    }
                    Pill {
                        pal: colors; s: lockScreenUi.s
                        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "&Hibernate").replace("&", "")
                        iconSource: "system-suspend-hibernate"
                        onClicked: sessionManagement.hibernate()
                        visible: sessionManagement.canHibernate
                    }
                    Pill {
                        pal: colors; s: lockScreenUi.s
                        label: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Switch &User").replace("&", "")
                        iconSource: "system-switch-user"
                        onClicked: sessionManagement.switchUser()
                        visible: sessionManagement.canSwitchUser
                    }
                    Pill {
                        pal: colors; s: lockScreenUi.s
                        confirm: true
                        confirmLabel: i18nd("plasma_applet_org.kde.plasma.lock_logout", "Restart")
                        iconSource: "system-reboot"
                        // no dialog: it would open behind the lock screen
                        onConfirmed: sessionManagement.requestReboot(SessionManagement.ConfirmationMode.Skip)
                        visible: sessionManagement.canReboot
                    }
                    Pill {
                        pal: colors; s: lockScreenUi.s
                        confirm: true
                        confirmLabel: i18nd("plasma_applet_org.kde.plasma.lock_logout", "Shut down")
                        iconSource: "system-shutdown"
                        onConfirmed: sessionManagement.requestShutdown(SessionManagement.ConfirmationMode.Skip)
                        visible: sessionManagement.canShutdown
                    }
                }
            }
        }

        // media island at the bottom, visible while locked and while unlocking
        Loader {
            id: media
            z: 1
            active: config.showMediaControls
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(34 * lockScreenUi.s)
            sourceComponent: MediaControls {
                pal: colors
                s: lockScreenUi.s
                wave: config.waveMedia !== false
                active: root.viewVisible
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
            }
        }

        // keyboard buttons left, battery right (only shown while unlocking)
        RowLayout {
            id: footer
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Math.round(34 * lockScreenUi.s)
            }
            spacing: Math.round(8 * lockScreenUi.s)

            Pill {
                pal: colors; s: lockScreenUi.s
                id: virtualKeyboardButton
                focusPolicy: Qt.TabFocus
                label: ""
                Accessible.name: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to show/hide virtual keyboard", "Virtual Keyboard")
                iconSource: Keyboards.KWinVirtualKeyboard.visible ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                checked: Keyboards.KWinVirtualKeyboard.visible
                onClicked: {
                    if (Keyboards.KWinVirtualKeyboard.visible) {
                        Keyboards.KWinVirtualKeyboard.active = false;
                    } else {
                        // Otherwise the password field loses focus and on-screen keyboard
                        // keystrokes get eaten
                        mainBlock.mainPasswordBox.forceActiveFocus();
                        Keyboards.KWinVirtualKeyboard.forceActivate();
                    }
                }
            }

            Pill {
                pal: colors; s: lockScreenUi.s
                id: keyboardButton
                focusPolicy: Qt.TabFocus
                Accessible.description: i18ndc("plasma_shell_org.kde.plasma.desktop", "Button to change keyboard layout", "Switch layout")
                iconSource: "input-keyboard"

                PW.KeyboardLayoutSwitcher {
                    id: keyboardLayoutSwitcher

                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                }

                label: keyboardLayoutSwitcher.layoutNames.longName
                onClicked: keyboardLayoutSwitcher.keyboardLayout.switchToNextLayout()

                visible: keyboardLayoutSwitcher.hasMultipleKeyboardLayouts
            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                visible: battery.visible
                implicitWidth: battery.implicitWidth + Math.round(28 * lockScreenUi.s)
                implicitHeight: Math.round(38 * lockScreenUi.s)
                radius: height / 2
                color: Qt.alpha(colors.base, 0.85)
                Battery { id: battery; anchors.centerIn: parent }
            }
        }
    }
}
