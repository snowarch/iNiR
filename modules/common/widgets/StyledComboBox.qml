import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

ComboBox {
    id: root

    // Settings search integration (optional)
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1
    property string settingsSearchLabel: ""
    property string settingsSearchDescription: ""
    property list<string> settingsSearchKeywords: []

    property real baseHeight: Appearance.regaliaEverywhere ? Appearance.regalia.controlHeight : 38
    property real radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small

    hoverEnabled: true
    opacity: root.enabled ? 1 : 0.4

    readonly property color _bgColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2
    readonly property color _bgHoverColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateHover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer2Hover
    readonly property color _bgActiveColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active
    readonly property color _textColor: Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer2
    readonly property color _subtextColor: Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color _borderColor: Appearance.angelEverywhere ? Appearance.angel.colBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : "transparent"
    readonly property real _borderWidth: (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : 0
    readonly property color _popupColor: Appearance.regaliaEverywhere ? Appearance.regalia.bg2
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.colors.colLayer3Base
    readonly property color _popupBorderColor: Appearance.regaliaEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border
    // Dropdown row hover/selected — matched to _popupColor's own layer (Layer3, or
    // inir's Layer2). The angel/aurora "glass card" tokens used here previously were
    // tuned for card surfaces, not this opaque popup, and read as barely-there.
    readonly property color _popupHoverColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.colors.colLayer3Hover
    readonly property color _selectedColor: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
        : Appearance.colors.colPrimaryContainer

    background: Rectangle {
        implicitHeight: root.baseHeight
        radius: root.radius
        color: Appearance.regaliaEverywhere ? "transparent"
            : root.down ? root._bgActiveColor
            : root.hovered ? root._bgHoverColor
            : root._bgColor
        border.width: root._borderWidth
        border.color: root.activeFocus
            ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : Appearance.inirEverywhere ? Appearance.inir.colBorderFocus
                : root._borderColor)
            : root._borderColor

        RegaliaControlFace {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: root._bgColor
            radius: root.radius
            hovered: root.hovered
            pressed: root.down
            focused: root.activeFocus
        }

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    }

    contentItem: RowLayout {
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : 12
            text: root.displayText
            color: root._textColor
            font.pixelSize: Appearance.font.pixelSize.small
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        MaterialSymbol {
            Layout.rightMargin: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : 8
            text: "expand_more"
            iconSize: Appearance.font.pixelSize.normal
            color: root._subtextColor
            rotation: root.popup.visible ? 180 : 0
            Behavior on rotation {
                enabled: Appearance.animationsEnabled
                RotationAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    direction: RotationAnimation.Shortest
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    // Base ComboBox ships its own arrow indicator alongside this custom contentItem —
    // left unset, the two stack and eat into the text's width (root cause of dropdown
    // labels looking truncated/shoved right). Custom "expand_more" above is the only one.
    indicator: Item {}

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 300)
        padding: 4

        // Shared contextual reveal: grow + fade from the field instead of a hard
        // appear. Driven by the global popupReveal profile, so zzz gets its
        // grow-from-origin punch (closedScale 0.90) for free. Durations run
        // through calcEffectiveDuration → instant when animations are disabled.
        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: Appearance.motion.popupReveal.enableFade ? 0 : 1; to: 1
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.motion.popupReveal.enterBezierCurve
            }
            NumberAnimation {
                property: "scale"
                from: Appearance.motion.popupReveal.enableScale ? Appearance.motion.popupReveal.closedScale : 1; to: 1
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.motion.popupReveal.enterBezierCurve
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1; to: Appearance.motion.popupReveal.enableFade ? 0 : 1
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
            NumberAnimation {
                property: "scale"
                from: 1; to: Appearance.motion.popupReveal.enableScale ? Appearance.motion.popupReveal.closedScale : 1
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
        }

        background: Rectangle {
            id: popupBg
            radius: root.radius
            color: Appearance.regaliaEverywhere ? "transparent" : root._popupColor
            border.width: Appearance.regaliaEverywhere ? 0 : 1
            border.color: root._popupBorderColor

            RegaliaPlate {
                anchors.fill: parent
                visible: Appearance.regaliaEverywhere
                fillColor: root._popupColor
                radius: popupBg.radius
                elevated: true
            }

            Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        }

        contentItem: ListView {
            id: popupList
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: popupList.contentHeight > 290 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }
    }

    delegate: ItemDelegate {
        id: delegateItem
        required property int index
        required property var modelData

        width: root.width - (Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 8)
        height: Appearance.regaliaEverywhere ? Appearance.regalia.controlHeight : 36
        highlighted: root.highlightedIndex === index
        hoverEnabled: true

        background: Rectangle {
            radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
                : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                : Appearance.rounding.unsharpenmore
            color: Appearance.regaliaEverywhere ? "transparent"
                : delegateItem.index === root.currentIndex ? root._selectedColor
                : delegateItem.hovered ? root._popupHoverColor
                : "transparent"

            RegaliaControlFace {
                anchors.fill: parent
                visible: Appearance.regaliaEverywhere
                fillColor: delegateItem.index === root.currentIndex
                    ? root._selectedColor : Appearance.regalia.controlPlate
                radius: parent.radius
                hovered: delegateItem.hovered
                selected: delegateItem.index === root.currentIndex
            }

            Behavior on color {
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        // Text starts at the same 12px the closed field uses (contentItem above) so the
        // dropdown lines up with the trigger instead of drifting right. The selected-row
        // fill (_selectedColor) already marks selection, so the checkmark is a trailing
        // accent, not a reserved left gutter every row used to pay for.
        contentItem: RowLayout {
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : 12
                text: {
                    if (typeof delegateItem.modelData === "object" && delegateItem.modelData !== null) {
                        return delegateItem.modelData[root.textRole] ?? delegateItem.modelData.toString()
                    }
                    return delegateItem.modelData?.toString() ?? ""
                }
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.regaliaEverywhere && delegateItem.index === root.currentIndex
                    ? Appearance.regalia.primaryPlateInk : root._textColor
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            MaterialSymbol {
                Layout.rightMargin: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : 8
                text: "check"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.regaliaEverywhere && delegateItem.index === root.currentIndex
                    ? Appearance.regalia.primaryPlateInk : root._textColor
                visible: delegateItem.index === root.currentIndex
            }
        }
    }

    function _findSettingsContext() {
        var page = null;
        var sectionTitle = "";
        var groupTitle = "";
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
            }
            if (p.hasOwnProperty("title")) {
                if (!sectionTitle && p.hasOwnProperty("icon")) {
                    sectionTitle = p.title;
                } else if (!groupTitle && !p.hasOwnProperty("icon")) {
                    groupTitle = p.title;
                }
            }
            p = p.parent;
        }
        return { page: page, sectionTitle: sectionTitle, groupTitle: groupTitle };
    }

    function focusFromSettingsSearch() {
        var p = root.parent;
        while (p) {
            if (p.hasOwnProperty("expanded") && p.hasOwnProperty("collapsible")) {
                p.expanded = true;
                break;
            }
            p = p.parent;
        }
        root.forceActiveFocus();
    }

    Component.onCompleted: {
        if (!enableSettingsSearch)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;

        var ctx = _findSettingsContext();
        var page = ctx.page;
        var pageIndex = page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1;
        if (pageIndex < 0)
            return;

        var sectionTitle = ctx.sectionTitle;
        var label = root.settingsSearchLabel || ctx.groupTitle || sectionTitle;

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: pageIndex,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: sectionTitle,
            label: label,
            description: root.settingsSearchDescription || "",
            keywords: root.settingsSearchKeywords || []
        });
    }

    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }
}
