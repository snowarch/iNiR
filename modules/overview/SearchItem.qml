pragma NativeMethodBehavior: AcceptThisObject
import qs
import qs.services
import qs.services.deferred
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
    property Item upTarget: null
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
    readonly property string desktopEntryId: String(root.entry?.desktopEntryId ?? "")
    readonly property bool draggableApplication: root.desktopEntryId.length > 0
    property bool suppressClick: false
    property bool nativeApplicationDragActive: false
    signal applicationDragChanged(bool active)
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere
    dragTarget: root.draggableApplication ? desktopEntryDrag : null
    pointerDragThreshold: 10
    
    visible: root.entryShown
    property int horizontalMargin: Appearance.sizes.elevationMargin
    property int buttonHorizontalPadding: Appearance.sizes.elevationMargin
    property int buttonVerticalPadding: Appearance.sizes.wallpaperSelectorItemPadding
    property bool keyboardDown: false
    readonly property bool isCurrentItem: ListView.isCurrentItem
    readonly property bool isHighlighted: root.isCurrentItem
    readonly property color normalTextColor: root.zzzEverywhere ? Appearance.zzz.ink
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color selectedTextColor: root.zzzEverywhere ? Appearance.zzz.onSticker
        : Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color descriptionTextColor: root.isHighlighted
        ? root.selectedTextColor
        : root.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color selectedBackgroundColor: root.zzzEverywhere ? Appearance.zzz.sticker
        : Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardHover
        : Appearance.colors.colLayer1
    readonly property color hoverBackgroundColor: root.zzzEverywhere ? Appearance.colors.colLayer1Hover
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateHover
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardHover
        : Appearance.colors.colLayer1
    readonly property color pressedBackgroundColor: root.zzzEverywhere ? Appearance.colors.colPrimaryActive
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateActive
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardActive
        : Appearance.colors.colLayer1Hover
    readonly property color activeRippleColor: root.zzzEverywhere ? Appearance.colors.colLayer1Active
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateActive
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardActive
        : Appearance.colors.colLayer1Hover

    // No fade-in animation - prevents flickering when results update rapidly
    opacity: 1

    implicitHeight: rowLayout.implicitHeight + root.buttonVerticalPadding * 2
    implicitWidth: rowLayout.implicitWidth + root.buttonHorizontalPadding * 2
    buttonRadius: root.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.normal
    colBackground: (root.down || root.keyboardDown)
        ? root.pressedBackgroundColor
        : (root.isHighlighted
            ? root.selectedBackgroundColor
            : (root.hovered ? root.hoverBackgroundColor : "transparent"))
    colBackgroundHover: root.hoverBackgroundColor
    colRipple: root.activeRippleColor

    releaseAction: () => {
        if (root.suppressClick)
            dragSuppressionResetTimer.restart()
    }
    cancelAction: () => {
        if (!root.nativeApplicationDragActive) {
            root.suppressClick = false
            dragSuppressionResetTimer.stop()
        }
    }
    onPointerDragActiveChanged: {
        if (root.pointerDragActive && root.draggableApplication) {
            root.nativeApplicationDragActive = true
            root.applicationDragChanged(true)
            root.suppressClick = true
        } else if (!root.nativeApplicationDragActive && root.suppressClick) {
            dragSuppressionResetTimer.restart()
        }
    }

    // Matched-char colour must contrast with the CURRENT row background: when the
    // row is selected the bg is the accent plate, so the accent-coloured match
    // would vanish into it — switch to onSignal (the readable on-accent ink).
    property string highlightPrefix: `<u><font color="${root.zzzEverywhere ? (root.isHighlighted ? Appearance.zzz.onSticker : Appearance.zzz.accent) : Appearance.regaliaEverywhere ? (root.isHighlighted ? Appearance.regalia.primaryPlateInk : Appearance.regalia.hardwarePrimary) : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary}">`
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
        if (root.suppressClick) {
            root.suppressClick = false
            return
        }
        GlobalStates.overviewOpen = false
        if (root.entry && root.entry.execute)
            root.entry.execute()
    }

    Timer {
        id: dragSuppressionResetTimer
        interval: 0
        onTriggered: root.suppressClick = false
    }

    Item {
        id: desktopEntryDrag
        width: root.width
        height: root.height
        z: -100

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.keys: ["application/x-inir-desktop-entry"]
        Drag.mimeData: ({
            "application/x-inir-desktop-entry": root.desktopEntryId
        })
        Drag.imageSource: Quickshell.iconPath(root.itemIcon, "application-x-executable")
        Drag.imageSourceSize: Qt.size(52, 52)
        Drag.hotSpot: Qt.point(26, 26)
        Drag.active: root.nativeApplicationDragActive && root.draggableApplication
        Drag.onDragFinished: dropAction => {
            desktopEntryDrag.x = 0
            desktopEntryDrag.y = 0
            root.nativeApplicationDragActive = false
            root.applicationDragChanged(false)
            if (dropAction === Qt.CopyAction)
                GlobalStates.closeOverview()
            dragSuppressionResetTimer.restart()
        }
    }

    Component.onDestruction: root.applicationDragChanged(false)

    Rectangle {
        anchors.fill: parent
        visible: root.pointerDragActive
        z: 3
        color: ColorUtils.applyAlpha(root.selectedBackgroundColor, 0.18)
        border.width: 2
        border.color: Appearance.colors.colPrimary
        radius: root.buttonRadius
        opacity: 0.95

        MaterialSymbol {
            anchors.centerIn: parent
            text: "open_with"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colPrimary
        }
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

    Rectangle {
        anchors.fill: root
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
        visible: root.zzzEverywhere
        radius: root.buttonRadius
        color: "transparent"
        border.width: root.isHighlighted || root.hovered ? Appearance.zzz.borderThick : 1
        border.color: root.isHighlighted ? Appearance.zzz.accent : Appearance.zzz.hairline

        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
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
                color: root.isHighlighted ? root.selectedTextColor : root.normalTextColor
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
        }

        Component {
            id: bigTextComponent
            StyledText {
                text: root.bigText
                font.pixelSize: Appearance.font.pixelSize.larger
                color: root.isHighlighted ? root.selectedTextColor : root.normalTextColor
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
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
                color: root.descriptionTextColor
                visible: root.itemType && root.itemType != Translation.tr("App")
                text: root.itemType
            }
            RowLayout {
                Loader { // Checkmark for copied clipboard entry
                    visible: itemName == Quickshell.clipboardText && root.cliphistRawString
                    active: itemName == Quickshell.clipboardText && root.cliphistRawString
                    sourceComponent: Rectangle {
                        implicitWidth: activeText.implicitHeight
                        implicitHeight: activeText.implicitHeight
                        radius: Appearance.zzzEverywhere ? Appearance.zzz.pillRadius : Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        Behavior on radius {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                        }
                        MaterialSymbol {
                            id: activeText
                            anchors.centerIn: parent
                            text: "check"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimary
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
                    color: root.isHighlighted ? root.selectedTextColor : root.normalTextColor
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: `${root.displayContent}`
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
            }
            Loader { // Clipboard image preview
                active: root.cliphistRawString && Cliphist.entryIsImage(root.cliphistRawString)
                sourceComponent: CliphistImage {
                    Layout.fillWidth: true
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
            opacity: (root.hovered || root.isHighlighted) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
            }
            id: clickAction
            font.pixelSize: Appearance.font.pixelSize.normal
            color: root.isHighlighted ? root.selectedTextColor : root.normalTextColor
            horizontalAlignment: Text.AlignRight
            text: root.itemClickActionName
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: root.buttonVerticalPadding
            Layout.bottomMargin: -root.buttonVerticalPadding // Why is this necessary? Good question.
            spacing: 4
            Repeater {
                model: (root.entry?.actions ?? []).slice(0, 4)
                delegate: RippleButton {
                    id: actionButton
                    required property var modelData
                    property string iconName: modelData.icon ?? ""
                    property string materialIconName: modelData.materialIcon ?? ""
                    implicitHeight: 34
                    implicitWidth: 34
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.pillRadius : Appearance.rounding.full

                    colBackgroundHover: root.hoverBackgroundColor
                    colRipple: root.activeRippleColor

                    contentItem: Item {
                        id: actionContentItem
                        anchors.centerIn: parent
                        Loader {
                            anchors.centerIn: parent
                            active: !(actionButton.iconName !== "") || actionButton.materialIconName
                            sourceComponent: MaterialSymbol {
                                text: actionButton.materialIconName || "video_settings"
                                font.pixelSize: Appearance.font.pixelSize.hugeass
                                color: root.normalTextColor
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                            }
                        }
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.materialIconName.length == 0 && actionButton.iconName && actionButton.iconName !== ""
                            sourceComponent: IconImage {
                                source: Quickshell.iconPath(actionButton.iconName)
                                implicitSize: 20
                            }
                        }
                    }

                    onClicked: {
                        if (modelData && modelData.execute)
                            modelData.execute()
                    }

                    StyledToolTip {
                        text: modelData.name
                    }
                }
            }
        }

    }
}
