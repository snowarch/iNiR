// pragma NativeMethodBehavior: AcceptThisObject
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

RippleButton {
    id: root
    property var entry
    property string query
    property bool entryShown: entry?.shown ?? true
    property string itemType: entry?.type ?? Translation.tr("App")
    property string itemName: entry?.name ?? ""
    property string itemIcon: entry?.icon ?? ""
    property string fontType: entry?.fontType ?? "main"
    property string itemClickActionName: entry?.clickActionName ?? "Open"
    property string bigText: entry?.bigText ?? ""
    property string materialSymbol: entry?.materialSymbol ?? ""
    property string cliphistRawString: entry?.cliphistRawString ?? ""
    property bool blurImage: entry?.blurImage ?? false
    property string blurImageText: entry?.blurImageText ?? "Image hidden"
    property bool compactClipboardPreview: entry?.compactClipboardPreview ?? false
    
    visible: root.entryShown
    property int horizontalMargin: Appearance.sizes.spacingSmall
    property int buttonHorizontalPadding: Appearance.sizes.spacingSmall
    property int buttonVerticalPadding: 6
    property bool keyboardDown: false
    property bool isSelected: false
    property bool copiedFromPanel: false

    implicitHeight: rowLayout.implicitHeight + root.buttonVerticalPadding * 2
    implicitWidth: rowLayout.implicitWidth + root.buttonHorizontalPadding * 2
    buttonRadius: Appearance.rounding.small
    // M3 consistent colors: transparent by default, layer3 on hover/select, primaryContainer on press
    colBackground: (root.down || root.keyboardDown) ? Appearance.colors.colPrimaryContainerActive : 
        ((root.hovered || root.focus || root.isSelected) ? Appearance.colors.colLayer3 : 
        "transparent")
    colBackgroundHover: Appearance.colors.colLayer3Hover
    colRipple: Appearance.colors.colPrimaryContainerActive

    property string highlightPrefix: `<u><font color="${Appearance.colors.colPrimary}">`
    property string highlightSuffix: `</font></u>`
    function highlightContent(content, query) {
        if (!query || query.length === 0 || content == query || fontType === "monospace")
            return StringUtils.escapeHtml(content);

        let contentLower = content.toLowerCase();
        let queryLower = query.toLowerCase();

        let result = "";
        let lastIndex = 0;
        let qIndex = 0;

        for (let i = 0; i < content.length && qIndex < query.length; i++) {
            if (contentLower[i] === queryLower[qIndex]) {
                // Add non-highlighted part (escaped)
                if (i > lastIndex)
                    result += StringUtils.escapeHtml(content.slice(lastIndex, i));
                // Add highlighted character (escaped)
                result += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix;
                lastIndex = i + 1;
                qIndex++;
            }
        }
        // Add the rest of the string (escaped)
        if (lastIndex < content.length)
            result += StringUtils.escapeHtml(content.slice(lastIndex));

        return result;
    }
    property string displayContent: highlightContent(root.itemName, root.query)

    property list<string> urls: {
        if (!root.itemName) return [];
        // Regular expression to match URLs
        const urlRegex = /https?:\/\/[^\s<>"{}|\\^`[\]]+/gi;
        const matches = root.itemName?.match(urlRegex)
            ?.filter(url => !url.includes("…")) // Elided = invalid
        return matches ? matches : [];
    }
    
    PointingHandInteraction {}

    background {
        anchors.fill: root
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
    }

    onClicked: {
        GlobalStates.clipboardOpen = false
        if (root.entry && root.entry.execute)
            root.entry.execute()
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Delete && event.modifiers === Qt.ShiftModifier) {
            const actions = (root.entry?.actions ?? [])
            const deleteAction = actions.find(action => action.name == "Delete");

            if (deleteAction && deleteAction.execute) {
                deleteAction.execute()
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = true
            root.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = false
            event.accepted = true;
        }
    }

    RowLayout {
        id: rowLayout
        spacing: iconLoader.sourceComponent === null ? 0 : 10
        anchors.fill: parent
        anchors.leftMargin: root.horizontalMargin + root.buttonHorizontalPadding
        anchors.rightMargin: root.horizontalMargin + root.buttonHorizontalPadding

        // Icon
        Loader {
            id: iconLoader
            active: true
            sourceComponent: root.materialSymbol !== "" ? materialSymbolComponent :
                root.bigText ? bigTextComponent :
                root.itemIcon !== "" ? iconImageComponent : 
                null
        }

        Component {
            id: iconImageComponent
            IconImage {
                source: Quickshell.iconPath(root.itemIcon, "image-missing")
                width: 35
                height: 35
            }
        }

        Component {
            id: materialSymbolComponent
            MaterialSymbol {
                text: root.materialSymbol
                iconSize: 30
                color: Appearance.m3colors.m3onSurface
            }
        }

        Component {
            id: bigTextComponent
            StyledText {
                text: root.bigText
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSurface
            }
        }

        // Main text
        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: (root.isSelected || root.hovered || root.focus) ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colSubtext
                visible: root.itemType && root.itemType != Translation.tr("App")
                text: root.itemType
            }
            RowLayout {
                Loader { // Checkmark for entries copied from this panel
                    visible: root.copiedFromPanel && root.cliphistRawString
                    active: root.copiedFromPanel && root.cliphistRawString
                    sourceComponent: Rectangle {
                        implicitWidth: activeText.implicitHeight
                        implicitHeight: activeText.implicitHeight
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            id: activeText
                            anchors.centerIn: parent
                            text: "check"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }
                Repeater { // Favicons for links
                    model: root.query == root.itemName ? [] : root.urls
                    Favicon {
                        required property var modelData
                        size: parent.height
                        url: modelData
                    }
                }
                StyledText { // Item name/content
                    Layout.fillWidth: true
                    id: nameText
                    textFormat: Text.StyledText // RichText also works, but StyledText ensures elide work
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family[root.fontType]
                    color: (root.isSelected || root.hovered || root.focus) ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: `${root.displayContent}`
                }
            }
            Loader { // Clipboard image preview
                // Don't use Layout.fillWidth - let the image determine its own size
                active: root.cliphistRawString && Cliphist.entryIsImage(root.cliphistRawString)
                sourceComponent: CliphistImage {
                    entry: root.cliphistRawString
                    maxWidth: contentColumn.width
                    maxHeight: root.compactClipboardPreview ? 80 : 140
                    blur: root.blurImage
                    blurText: root.blurImageText
                }
            }
        }

        // Action text
        StyledText {
            Layout.fillWidth: false
            visible: (root.hovered || root.focus)
            id: clickAction
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnPrimaryContainer
            horizontalAlignment: Text.AlignRight
            text: root.itemClickActionName
        }

        RowLayout {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: root.buttonVerticalPadding
            Layout.bottomMargin: -root.buttonVerticalPadding
            spacing: 4
            visible: root.hovered || root.focus || root.isSelected
            
            Repeater {
                model: (root.entry?.actions ?? []).slice(0, 4)
                delegate: RippleButton {
                    id: actionButton
                    required property var modelData
                    property string iconName: modelData.icon ?? ""
                    property string materialIconName: modelData.materialIcon ?? ""
                    implicitHeight: 32
                    implicitWidth: 32
                    buttonRadius: Appearance.rounding.small

                    colBackgroundHover: Appearance.colors.colLayer4Hover
                    colRipple: Appearance.colors.colLayer4Active

                    contentItem: Item {
                        id: actionContentItem
                        anchors.centerIn: parent
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.materialIconName.length > 0
                            sourceComponent: MaterialSymbol {
                                text: actionButton.materialIconName
                                font.pixelSize: Appearance.font.pixelSize.large
                                color: Appearance.m3colors.m3onSurface
                            }
                        }
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.materialIconName.length === 0 && actionButton.iconName.length > 0
                            sourceComponent: IconImage {
                                source: Quickshell.iconPath(actionButton.iconName)
                                implicitSize: 18
                            }
                        }
                    }

                    onClicked: modelData.execute()

                    StyledToolTip {
                        text: modelData.name
                    }
                }
            }
        }

    }
}
