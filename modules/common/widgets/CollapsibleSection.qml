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
        if (typeof SettingsSearchRegistry !== "undefined" && !SettingsSearchRegistry.dynamicRegistrationEnabled)
            return;
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
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
                text: "expand_more"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext

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

    // Content container with animation
    Item {
        id: contentContainer
        Layout.fillWidth: true
        implicitHeight: root.expanded ? sectionContent.implicitHeight : 0
        clip: true
        
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        ColumnLayout {
            id: sectionContent
            width: parent.width
            spacing: 4
            opacity: root.expanded ? 1 : 0
            y: root.expanded ? 0 : -8
            
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            Behavior on y {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
        }
    }
}
