pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "notes"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 240, contentHeight: 160,
        text: "",
        fontSize: 14,
        fontFamily: "sans",
        textAlign: "left",
        style: "card",
        showRules: true,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.10, borderWidth: 1, borderOpacity: 0.12,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 80, y: 80
    })

    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round(Number(root._readConfigKey("contentWidth") ?? 240)
        * root.scaleFactor)
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.round(Number(root._readConfigKey("contentHeight") ?? 160)
        * root.scaleFactor)
    irisFace: Component { IrisNotesFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 120
    resizeMinHeight: 80
    resizeMaxWidth: 800
    resizeMaxHeight: 600

    // Normal mode belongs to the editor; widget edit mode belongs to dragging.
    draggable: GlobalStates.widgetEditMode && !GlobalStates.screenLocked
        && !root.locked

    readonly property string noteText:
        root._readConfigKey("text") ?? ""
    readonly property int fontSize: Math.round(
        Number(root._readConfigKey("fontSize") ?? 14) * root.scaleFactor)
    readonly property string fontFamily:
        root._readConfigKey("fontFamily") ?? "sans"
    readonly property string textAlign:
        root._readConfigKey("textAlign") ?? "left"
    readonly property string noteStyle: root._readConfigKey("style") ?? "card"
    readonly property bool instrument: root.noteStyle === "instrument"
    readonly property bool showRules: root._readConfigKey("showRules") ?? true
    readonly property real cardRadius: root.widgetCardRadius
    widgetSurfaceEnabled: !root.instrument
    property bool _syncingText: false

    function _loadPersistedText(): void {
        if (textEdit.text === root.noteText)
            return
        root._syncingText = true
        textEdit.text = root.noteText
        root._syncingText = false
    }

    function _commitText(): void {
        saveDebounce.stop()
        if (!root._syncingText && textEdit.text !== root.noteText)
            root._setOutputValue("text", textEdit.text)
    }

    function _beginEditing(localX: real, localY: real): void {
        if (GlobalStates.widgetEditMode || GlobalStates.screenLocked)
            return
        textEdit.forceActiveFocus()
        const mapped = focusCatcher.mapToItem(textEdit, localX, localY)
        textEdit.cursorPosition = textEdit.positionAt(mapped.x, mapped.y)
    }

    readonly property bool editing: textEdit.activeFocus && !GlobalStates.widgetEditMode
    function _finishEditing(): void {
        root._commitText()
        noteFocusSink.forceActiveFocus()
    }

    onNoteTextChanged: {
        if (!textEdit.activeFocus)
            root._loadPersistedText()
    }

    Component.onCompleted: root._loadPersistedText()

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void {
            if (GlobalStates.widgetEditMode)
                root._finishEditing()
        }
        function onScreenLockedChanged(): void {
            if (GlobalStates.screenLocked)
                root._finishEditing()
        }
    }

    Timer {
        id: saveDebounce
        interval: 400
        repeat: false
        onTriggered: root._commitText()
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.noteStyle
                    model: [
                        { label: Translation.tr("Card"), icon: "sticky_note_2", value: "card" },
                        { label: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Text")
                WidgetQuickChoices {
                    current: root.fontFamily
                    model: [
                        { label: Translation.tr("Sans"), icon: "text_fields", value: "sans" },
                        { label: Translation.tr("Mono"), icon: "code", value: "mono" }
                    ]
                    onPicked: value => root._setOutputValue("fontFamily", value)
                }
                WidgetQuickChoices {
                    current: root.textAlign
                    model: [
                        { icon: "format_align_left", value: "left", tooltip: Translation.tr("Align left") },
                        { icon: "format_align_center", value: "center", tooltip: Translation.tr("Center") },
                        { icon: "format_align_right", value: "right", tooltip: Translation.tr("Align right") }
                    ]
                    onPicked: value => root._setOutputValue("textAlign", value)
                }
                WidgetQuickToggle {
                    visible: root.instrument
                    Layout.fillWidth: true
                    iconName: "horizontal_rule"
                    label: Translation.tr("Writing guides")
                    checked: root.showRules
                    onToggled: root._setOutputValue("showRules", !root.showRules)
                }
            }
            WidgetQuickSlider {
                title: Translation.tr("Text size")
                from: 10; to: 48; stepSize: 1; unit: " px"
                value: Number(root._readConfigKey("fontSize") ?? 14)
                onMoved: v => root.previewIrisValue("fontSize", v)
                onCommitted: v => root.commitIrisValue("fontSize", v)
            }
        }
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0
            ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        shown: !root.irisFaced && !root.instrument && (root.backgroundOpacity > 0 || root.borderWidth > 0
            || root.effectiveBlur)
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.irisFaced
        color: "transparent"
        radius: root.cornerRadiusOverride >= 0
            ? root.cornerRadiusOverride : root.cardRadius
        border.width: textEdit.activeFocus ? (root.instrument ? 1 : 2) : 0
        border.color: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.72)

        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    FocusScope {
        id: noteFocusSink
        width: 0
        height: 0
        focus: false
    }

    RowLayout {
        id: noteHeading
        x: 14 * root.scaleFactor
        y: 10 * root.scaleFactor
        width: root.width - 28 * root.scaleFactor
        visible: !root.irisFaced && root.height >= 120 * root.scaleFactor
        spacing: 6 * root.scaleFactor
        MaterialSymbol {
            visible: !root.instrument
            text: "edit_note"
            iconSize: 18 * root.scaleFactor
            color: root.widgetAccentVisible
        }
        StyledText {
            Layout.fillWidth: true
            text: root.instrument ? Translation.tr("NOTE") : Translation.tr("Notes")
            color: root.instrument ? root.widgetInk : root.widgetInkMuted
            font.family: root.instrument ? Appearance.font.family.monospace : root.widgetTitleFamily
            font.pixelSize: (root.instrument ? Appearance.font.pixelSize.smaller
                : Appearance.font.pixelSize.smallest) * root.scaleFactor
            font.weight: root.instrument ? Font.DemiBold : root.widgetLabelWeight
            font.letterSpacing: root.instrument ? Math.round(1.2 * root.scaleFactor) : 0
            elide: Text.ElideRight
        }
        StyledText {
            visible: root.instrument
            text: String(textEdit.text.length).padStart(3, "0")
            color: root.widgetAccentVisible
            font.family: root.widgetNumbersFamily
            font.pixelSize: Appearance.font.pixelSize.smaller * root.scaleFactor
            font.weight: Font.DemiBold
        }
        Rectangle {
            visible: !root.instrument && !root.editing
            Layout.preferredWidth: 24 * root.scaleFactor
            Layout.preferredHeight: 3 * root.scaleFactor
            radius: height / 2
            color: root.widgetAccentVisible
        }
        // Notes save as you type; "Done" only lets go of the keyboard, where the title already is.
        StyledText {
            visible: root.editing
            text: Translation.tr("Done")
            color: doneArea.containsMouse ? root.widgetInk : root.widgetAccentVisible
            font.family: root.widgetTitleFamily
            font.pixelSize: Appearance.font.pixelSize.smaller * root.scaleFactor
            font.weight: Font.DemiBold
            MouseArea {
                id: doneArea
                anchors.fill: parent
                anchors.margins: -Math.round(6 * root.scaleFactor)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._finishEditing()
            }
        }
    }

    Flickable {
        id: editorFlick
        anchors.fill: parent
        anchors.margins: root.irisFaced ? root.irisGutter : Math.round(14 * root.scaleFactor)
        anchors.topMargin: root.irisFaced ? Math.round(root.irisGutter * 2.75)
            : noteHeading.visible ? noteHeading.y + noteHeading.height + 10 * root.scaleFactor : anchors.margins
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, textEdit.contentHeight)
        boundsBehavior: Flickable.StopAtBounds
        interactive: !GlobalStates.widgetEditMode

        Repeater {
            model: root.instrument && root.showRules
                ? Math.max(0, Math.floor(editorFlick.height / Math.max(18, root.fontSize * 1.55))) : 0
            Rectangle {
                required property int index
                x: 0
                y: Math.round((index + 1) * Math.max(18, root.fontSize * 1.55))
                width: editorFlick.width
                height: 1
                color: ColorUtils.applyAlpha(root.widgetInk, 0.13)
            }
        }

        TextEdit {
            id: textEdit
            width: editorFlick.width
            height: Math.max(editorFlick.height, contentHeight)
            wrapMode: TextEdit.Wrap
            color: root.widgetInk
            selectionColor: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.36)
            selectedTextColor: root.widgetInk
            selectByMouse: true
            selectByKeyboard: true
            persistentSelection: true
            renderType: Text.NativeRendering
            enabled: !GlobalStates.widgetEditMode && !GlobalStates.screenLocked

            font.pixelSize: root.fontSize
            font.family: root.fontFamily === "mono"
                ? Appearance.font.family.monospace : root.widgetBodyFamily
            font.weight: root.instrument ? Font.Medium : Font.Normal

            horizontalAlignment: root.textAlign === "center"
                ? TextEdit.AlignHCenter
                : root.textAlign === "right" ? TextEdit.AlignRight
                : TextEdit.AlignLeft

            onCursorRectangleChanged: {
                const rectangle = cursorRectangle
                if (rectangle.y < editorFlick.contentY)
                    editorFlick.contentY = rectangle.y
                else if (rectangle.y + rectangle.height
                        > editorFlick.contentY + editorFlick.height)
                    editorFlick.contentY = rectangle.y + rectangle.height
                        - editorFlick.height
            }

            onTextChanged: {
                if (!root._syncingText)
                    saveDebounce.restart()
            }
            onActiveFocusChanged: {
                if (!activeFocus)
                    root._commitText()
            }

            Keys.onEscapePressed: root._finishEditing()
            Keys.onPressed: event => {
                if ((event.modifiers & Qt.ControlModifier)
                        && (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter)) {
                    root._finishEditing()
                    event.accepted = true
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: mouse => mouse.accepted = true
            }

            Component.onDestruction: root._commitText()
        }

        // The first click explicitly gives the TextEdit focus and places its
        // cursor. Once focused, this catcher disappears and selection behaves
        // like a normal editor instead of fighting the Flickable.
        MouseArea {
            id: focusCatcher
            anchors.fill: parent
            visible: !textEdit.activeFocus && !GlobalStates.widgetEditMode
                && !GlobalStates.screenLocked
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.IBeamCursor
            onPressed: mouse => {
                root._beginEditing(mouse.x, mouse.y)
                mouse.accepted = true
            }
        }

        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 2
                rightMargin: 2
            }
            visible: textEdit.text.length === 0 && !textEdit.activeFocus
            text: Translation.tr("Write a note…")
            color: root.widgetInkSubtle
            font.pixelSize: root.fontSize
            font.family: textEdit.font.family
            horizontalAlignment: root.textAlign === "center"
                ? Text.AlignHCenter : root.textAlign === "right"
                    ? Text.AlignRight : Text.AlignLeft
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
    }

    RippleButton {
        anchors {
            top: parent.top
            right: parent.right
            margins: Math.round(7 * root.scaleFactor)
        }
        z: 5
        width: Math.round(30 * root.scaleFactor)
        height: width
        visible: root.editing && !noteHeading.visible
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.applyAlpha(root.widgetInk, 0.1)
        colRipple: ColorUtils.applyAlpha(root.widgetInk, 0.16)
        downAction: root._finishEditing

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: "check"
            iconSize: Math.round(17 * root.scaleFactor)
            color: root.widgetAccentVisible
        }
        StyledToolTip { text: Translation.tr("Done editing") }
    }
}
