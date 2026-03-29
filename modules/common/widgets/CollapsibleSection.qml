import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property string title
    property string icon: ""
    property bool expanded: true
    property bool collapsible: true
    property int animationDuration: Appearance.animation.elementMove.duration
    default property alias contentData: sectionContent.data
    
    // Settings search integration
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1

    Layout.fillWidth: true
    spacing: 6

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
        // Registrar como collapsible section para manejo de expand/collapse
        if (typeof SettingsSearchRegistry !== "undefined" && root.collapsible) {
            SettingsSearchRegistry.registerCollapsibleSection(root);
        }
        
        if (!enableSettingsSearch || !root.title)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;

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
            SettingsSearchRegistry.unregisterCollapsibleSection(root);
            SettingsSearchRegistry.unregisterControl(root);
        }
    }

    // Header row - clickable to expand/collapse
    Rectangle {
        id: headerBackground
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + 12
        radius: Appearance.rounding.normal
        color: headerMouseArea.containsMouse && root.collapsible 
            ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
              : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
              : Appearance.colors.colLayer1Hover)
            : "transparent"
        
        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 8
            spacing: 6

            OptionalMaterialSymbol {
                icon: root.icon
                iconSize: Appearance.font.pixelSize.hugeass
            }
            
            StyledText {
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : Appearance.inirEverywhere ? Appearance.inir.colText
                     : Appearance.colors.colOnSecondaryContainer
                Layout.fillWidth: true
            }

            // Expand/collapse indicator
            MaterialSymbol {
                visible: root.collapsible
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
                
                rotation: root.expanded ? 0 : 0
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

    // Content container with animation
    Item {
        id: contentContainer
        Layout.fillWidth: true
        implicitHeight: root.expanded ? sectionContent.implicitHeight : 0
        clip: true
        
        Behavior on implicitHeight {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: sectionContent
            width: parent.width
            spacing: 4
            opacity: root.expanded ? 1 : 0
            
            Behavior on opacity {
                NumberAnimation {
                    duration: root.animationDuration / 2
                }
            }
        }
    }
}
