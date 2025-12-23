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

    Layout.fillWidth: false
    Layout.alignment: Qt.AlignHCenter
    Layout.maximumWidth: SettingsMaterialPreset.maxContentWidth
    Layout.preferredWidth: {
        const parentWidth = root.parent ? root.parent.width : SettingsMaterialPreset.maxContentWidth
        return Math.min(SettingsMaterialPreset.maxContentWidth, parentWidth)
    }
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

                    OptionalMaterialSymbol {
                        icon: root.icon
                        iconSize: Appearance.font.pixelSize.hugeass
                    }

                    StyledText {
                        text: root.title
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSecondaryContainer
                        Layout.fillWidth: true
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
