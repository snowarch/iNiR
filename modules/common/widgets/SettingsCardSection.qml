import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool expanded: true
    property bool collapsible: true
    property int animationDuration: Appearance.animation.elementMove.duration
    property string settingsTaskSection: ""
    default property alias contentData: sectionContent.data

    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1

    Layout.fillWidth: true
    implicitHeight: card.implicitHeight

    function _findSettingsContext() {
        var page = null;
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
                break;
            }
            p = p.parent;
        }
        return { page: page };
    }

    function focusFromSettingsSearch() {
        root.expanded = true;
        root.forceActiveFocus();
    }

    Component.onCompleted: {
        if (!enableSettingsSearch || !root.title)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;

        if (SettingsSearchRegistry.registerCollapsibleSection) {
            SettingsSearchRegistry.registerCollapsibleSection(root);
        }

        var ctx = _findSettingsContext();
        var page = ctx.page;

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: root.title,
            label: root.title,
            description: "",
            keywords: []
        });
    }

    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            if (SettingsSearchRegistry.unregisterCollapsibleSection) {
                SettingsSearchRegistry.unregisterCollapsibleSection(root);
            }
            SettingsSearchRegistry.unregisterControl(root);
        }
    }

    // Shadow — lightweight offset for material/aurora, escalonado for angel
    // Material/aurora: simple offset rectangle instead of GPU-blurred RectangularShadow
    // for much better performance (especially with many cards visible at once).
    Rectangle {
        visible: !Appearance.angelEverywhere
            && !Appearance.zzzEverywhere
            && Appearance.effectsEnabled
        x: card.x + 0.5
        y: card.y + (Appearance.cookieEverywhere
            ? Appearance.cookie.cardShadowOffset : 1.5)
        width: card.width
        height: card.height
        radius: card.radius
        color: Appearance.cookieEverywhere
            ? Appearance.cookie.cardShadowColor : Appearance.colors.colShadow
        z: -1
    }
    Loader {
        active: Appearance.angelEverywhere
        sourceComponent: EscalonadoShadow {
            target: card
            hovered: root.expanded
        }
    }

    ZzzPlate {
        anchors.fill: card
        visible: Appearance.zzzEverywhere
        // A step darker than the content field (zzz.bg2) so the card reads as
        // its own sunken plate instead of blending into the page background.
        fillColor: Appearance.zzz.bg1
        strokeColor: Appearance.zzz.hairline
        strokeWidth: Appearance.zzz.hairlineThick
        chamfer: Appearance.zzz.cutCorner
        z: -0.5
    }

    // Non-ZZZ, non-angel: subtle left accent bar when expanded
    Rectangle {
        id: accentBar
        visible: !Appearance.angelEverywhere && !Appearance.regaliaEverywhere
            && !Appearance.zzzEverywhere && !Appearance.cookieEverywhere
        anchors {
            left: card.left
            top: card.top
            bottom: card.bottom
            leftMargin: 0
            topMargin: SettingsMaterialPreset.cardRadius
            bottomMargin: SettingsMaterialPreset.cardRadius
        }
        width: 2
        radius: 1
        color: SettingsMaterialPreset.accentColor
        opacity: root.expanded
            ? 0.6
            : (headerMouseArea.containsMouse ? 0.3 : 0)
        z: 1
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    Loader {
        anchors.fill: card
        active: Appearance.cookieEverywhere && root.visible
        sourceComponent: CookieFace {
            role: "card"
            color: SettingsMaterialPreset.cardColor
            radius: card.radius
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        implicitHeight: cardColumn.implicitHeight + SettingsMaterialPreset.cardPadding * 2
        radius: SettingsMaterialPreset.cardRadius
        color: Appearance.cookieEverywhere || Appearance.regaliaEverywhere
            ? "transparent" : SettingsMaterialPreset.cardColor
        border.width: Appearance.angelEverywhere ? 0
                     : (Appearance.regaliaEverywhere ? 0
                     : (Appearance.zzzEverywhere ? 0
                     : (Appearance.cookieEverywhere ? 0
                     : (Appearance.inirEverywhere ? 1
                     : (Appearance.auroraEverywhere ? 1 : 1)))))
        border.color: Appearance.angelEverywhere ? "transparent" : SettingsMaterialPreset.cardBorderColor

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        RegaliaPlate {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: SettingsMaterialPreset.cardColor
            radius: card.radius
            inset: Appearance.regalia.surfaceInset
            elevated: true
        }

        // Angel partial border
        AngelPartialBorder {
            targetRadius: card.radius
            hovered: root.expanded
        }

        ZzzDiagonalPattern {
            stripeSpacing: 36
            stripeThickness: 1
        }

        ColumnLayout {
            id: cardColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: SettingsMaterialPreset.cardPadding
            }
            spacing: SettingsMaterialPreset.groupSpacing

            Rectangle {
                id: headerBackground
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + SettingsMaterialPreset.headerPaddingY * 2
                radius: SettingsMaterialPreset.headerRadius
                color: Appearance.regaliaEverywhere ? "transparent"
                    : headerMouseArea.containsMouse && root.collapsible
                        ? SettingsMaterialPreset.headerHoverColor
                        : ColorUtils.applyAlpha(SettingsMaterialPreset.headerHoverColor, 0)

                Behavior on color {
                    animation: ColorAnimation { duration: Appearance.animation.stateChange.duration; easing.type: Appearance.animation.stateChange.type; easing.bezierCurve: Appearance.animation.stateChange.bezierCurve }
                }

                RegaliaControlFace {
                    anchors.fill: parent
                    visible: Appearance.regaliaEverywhere && root.collapsible && headerMouseArea.containsMouse
                    fillColor: Appearance.regalia.controlPlateHover
                    radius: Appearance.regalia.roundSmall
                }

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.leftMargin: SettingsMaterialPreset.headerPaddingX
                    anchors.rightMargin: SettingsMaterialPreset.headerPaddingX
                    spacing: 8

                    // Icon with expand-state color
                    Loader {
                        active: root.icon && root.icon.length > 0
                        visible: active
                        Layout.alignment: Qt.AlignVCenter

                        readonly property color _iconColor: root.expanded
                            ? SettingsMaterialPreset.iconExpandedColor
                            : SettingsMaterialPreset.iconCollapsedColor

                        sourceComponent: Item {
                            id: iconHost
                            // The cookie badge fills this host, and a scalloped
                            // polygon inscribed in a box is SMALLER than the box —
                            // its lobes cut inward. Sized to the glyph, the plate
                            // came out smaller than the glyph sitting on it, so the
                            // host has to clear the icon for the badge to contain it.
                            implicitWidth: Appearance.zzzEverywhere ? 26
                                : Appearance.cookieEverywhere ? Math.round(Appearance.font.pixelSize.larger * 1.75)
                                : Appearance.font.pixelSize.larger
                            implicitHeight: implicitWidth
                            readonly property color iconColor: root.expanded
                                ? (Appearance.cookieEverywhere
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : SettingsMaterialPreset.iconExpandedColor)
                                : (Appearance.cookieEverywhere
                                    ? Appearance.colors.colOnLayer2
                                    : SettingsMaterialPreset.iconCollapsedColor)

                            CookieFace {
                                anchors.fill: parent
                                visible: Appearance.cookieEverywhere
                                role: "badge"
                                selected: root.expanded
                                color: root.expanded
                                    ? Appearance.colors.colPrimaryContainer
                                    : Appearance.colors.colLayer2
                            }

                            MaterialSymbol {
                                visible: !Appearance.zzzEverywhere
                                anchors.centerIn: parent
                                text: root.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: iconHost.iconColor

                                Behavior on color {
                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                            ZzzGlyphBadge {
                                visible: Appearance.zzzEverywhere
                                anchors.centerIn: parent
                                symbol: root.icon
                                accentColor: root.expanded ? Appearance.zzz.sticker : Appearance.zzz.secondary
                                inkColor: root.expanded ? Appearance.zzz.onSticker : Appearance.zzz.onSecondary
                                badgeSize: 26
                            }
                        }
                    }

                    StyledText {
                        text: Appearance.zzzEverywhere ? root.title.toUpperCase() : root.title
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Appearance.zzzEverywhere ? Font.ExtraBold : Font.DemiBold
                        color: root.expanded
                            ? SettingsMaterialPreset.titleExpandedColor
                            : SettingsMaterialPreset.titleCollapsedColor
                        Layout.fillWidth: true

                        Behavior on color {
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    MaterialSymbol {
                        visible: root.collapsible
                        text: "expand_more"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.regaliaEverywhere
                            ? (root.expanded ? Appearance.regalia.onColor : Appearance.regalia.onMuted)
                            : Appearance.angelEverywhere
                                ? Appearance.angel.colTextMuted
                                : Appearance.colors.colSubtext
                        // One glyph that rotates instead of swapping icons
                        rotation: root.expanded ? 180 : 0
                        Behavior on rotation {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                }

                MouseArea {
                    id: headerMouseArea
                    anchors.fill: parent
                    hoverEnabled: root.collapsible
                    cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.collapsible) {
                            root.expanded = !root.expanded;
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                Layout.fillWidth: true
                implicitHeight: root.expanded ? sectionContent.implicitHeight : 0
                clip: true
                // clip only hides rendering — descendants outside the clipped
                // area still receive input. Without this, every collapsed
                // card leaves its full set of switches/sliders live and
                // clickable, stacked invisibly under whatever renders next.
                enabled: root.expanded

                Behavior on implicitHeight {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }

                ColumnLayout {
                    id: sectionContent
                    width: parent.width
                    spacing: SettingsMaterialPreset.groupSpacing
                    opacity: root.expanded ? 1 : 0

                    Behavior on opacity {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }
        }
    }
}
