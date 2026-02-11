import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool expanded: true
    property bool collapsible: true
    property int animationDuration: Appearance.animation.elementMove.duration
    default property alias data: sectionContent.data

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

    StyledRectangularShadow {
        target: card
    }

    // Subtle left accent bar when expanded
    Rectangle {
        id: accentBar
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
        color: Appearance.m3colors.m3primary
        opacity: root.expanded ? 0.6 : 0
        z: 1

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        implicitHeight: cardColumn.implicitHeight + SettingsMaterialPreset.cardPadding * 2
        radius: SettingsMaterialPreset.cardRadius
        color: SettingsMaterialPreset.cardColor
        border.width: 1
        border.color: SettingsMaterialPreset.cardBorderColor

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
                color: headerMouseArea.containsMouse && root.collapsible
                    ? Appearance.colors.colLayer1Hover
                    : "transparent"

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
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
                            ? Appearance.m3colors.m3primary
                            : Appearance.colors.colOnSurfaceVariant

                        sourceComponent: MaterialSymbol {
                            text: root.icon
                            iconSize: Appearance.font.pixelSize.hugeass
                            color: parent._iconColor

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }

                    StyledText {
                        text: root.title
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Medium
                        color: root.expanded
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnSurfaceVariant
                        Layout.fillWidth: true

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }

                    MaterialSymbol {
                        visible: root.collapsible
                        text: root.expanded ? "expand_less" : "expand_more"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colSubtext
                        Behavior on text {
                            enabled: false
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

                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                ColumnLayout {
                    id: sectionContent
                    width: parent.width
                    spacing: 8
                    opacity: root.expanded ? 1 : 0

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
