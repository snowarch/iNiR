import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property var keyData
    property string key: keyData.label
    property string type: keyData.keytype
    property var keycode: keyData.keycode
    property string shape: keyData.shape
    property bool isShift: Ydotool.shiftKeys.includes(keycode)
    property bool isCaps: type === "caps"
    property bool isBackspace: (key.toLowerCase() == "backspace")
    property bool isEnter: (key.toLowerCase() == "enter" || key.toLowerCase() == "return")
    property real baseWidth: 45
    property real baseHeight: 45
    // What a family may restyle; the defaults are Material's and Waffle's keycap.
    property color colKeyText: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1
    property color colKeyTextToggled: Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimary
    property string keyFontFamily: Appearance.font.family.main
    property string glyphFontFamily: Appearance.font.family.iconMaterial
    property real keyFontSize: Appearance.font.pixelSize.large
    property real fnFontSize: Appearance.font.pixelSize.small
    property real glyphFontSize: Appearance.font.pixelSize.huge
    property var widthMultiplier: ({
        "normal": 1,
        "fn": 1,
        "tab": 1.6,
        "caps": 1.9,
        "shift": 2.5,
        "control": 1.3
    })
    property var heightMultiplier: ({
        "normal": 1,
        "fn": 0.7,
        "tab": 1,
        "caps": 1,
        "shift": 1,
        "control": 1
    })
    toggled: isShift ? Ydotool.shiftMode : isCaps ? Ydotool.shiftMode == 2 : false

    enabled: shape != "empty"
    // ZZZ: raised carbon keycaps (bg2) over the bg0 backplate, with the active
    // mod key reading as a signal sticker. Other styles keep the flat layer1.
    colBackground: shape == "empty"
        ? ColorUtils.transparentize(Appearance.colors.colLayer1)
        : (Appearance.zzzEverywhere ? Appearance.zzz.bg2 : Appearance.colors.colLayer1)
    colBackgroundToggled: Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimary
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
    implicitWidth: baseWidth * widthMultiplier[shape] || baseWidth
    implicitHeight: baseHeight * heightMultiplier[shape] || baseHeight
    Layout.fillWidth: shape == "space" || shape == "expand"

    Connections {
        target: Ydotool
        enabled: isShift
        function onShiftModeChanged() {
            if (Ydotool.shiftMode == 0) {
                capsLockTimer.hasStarted = false;
            }
        }
    }

    Timer {
        id: capsLockTimer
        property bool hasStarted: false
        property bool canCaps: false
        interval: 300
        function startWaiting() {
            hasStarted = true;
            canCaps = true;
            start();
        }
        onTriggered: {
            canCaps = false;
        }
    }

    downAction: () => {
        if (root.isCaps)
            return;
        Ydotool.press(root.keycode);
        if (isShift && Ydotool.shiftMode == 0) Ydotool.shiftMode = 1;
    }
    releaseAction: () => {
        if (root.isCaps) {
            if (Ydotool.shiftMode == 2) {
                Ydotool.releaseShiftKeys();
            } else {
                Ydotool.press(Ydotool.shiftKeys[0]);
                Ydotool.shiftMode = 2; // Caps lock mode
            }
        } else if (root.type == "normal") {
            Ydotool.release(root.keycode);
            if (Ydotool.shiftMode == 1) {
                Ydotool.releaseShiftKeys()
            }
        } else if (isShift) {
            if (Ydotool.shiftMode == 1) {
                if (!capsLockTimer.hasStarted) {
                    capsLockTimer.startWaiting();
                } else {
                    if (capsLockTimer.canCaps) {
                        Ydotool.shiftMode = 2; // Caps lock mode
                    } else {
                        Ydotool.releaseShiftKeys()
                    }
                }
            } else if (Ydotool.shiftMode == 2) {
                Ydotool.releaseShiftKeys();
            }
        } else if (root.type == "modkey") {
            root.toggled = !root.toggled;
            if (!root.toggled) {
                if (isShift) {
                    Ydotool.releaseShiftKeys();
                } else { 
                    Ydotool.release(root.keycode);
                }
            }
        }

    }

    contentItem: StyledText {
        id: keyText
        anchors.fill: parent
        font.family: (isBackspace || isEnter) ? root.glyphFontFamily : root.keyFontFamily
        font.pixelSize: root.shape == "fn" ? root.fnFontSize :
            (isBackspace || isEnter) ? root.glyphFontSize :
            root.keyFontSize
        horizontalAlignment: Text.AlignHCenter
        color: root.toggled ? root.colKeyTextToggled : root.colKeyText
        text: root.isBackspace ? "backspace" : root.isEnter ? "subdirectory_arrow_left" :
            (root.toggled && root.keyData.labelToggled) ? root.keyData.labelToggled :
            Ydotool.shiftMode == 2 ? (root.keyData.labelCaps || root.keyData.labelShift || root.keyData.label) :
            Ydotool.shiftMode == 1 ? (root.keyData.labelShift || root.keyData.label) : 
            root.keyData.label
    }
}
