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
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.10, borderWidth: 1, borderOpacity: 0.12,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 80, y: 80
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 240)
        * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 160)
        * root.scaleFactor)

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
    readonly property real cardRadius: root.widgetCardRadius
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
            Config.setNestedValue("background.widgets.notes.text", textEdit.text)
    }

    function _beginEditing(localX: real, localY: real): void {
        if (GlobalStates.widgetEditMode || GlobalStates.screenLocked)
            return
        textEdit.forceActiveFocus()
        const mapped = focusCatcher.mapToItem(textEdit, localX, localY)
        textEdit.cursorPosition = textEdit.positionAt(mapped.x, mapped.y)
    }

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
            spacing: 8

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: Translation.tr("Sans"), value: "sans" },
                        { label: Translation.tr("Mono"), value: "mono" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonText: modelData.label
                        toggled: root.fontFamily === modelData.value
                        onClicked: Config.setNestedValue(
                            "background.widgets.notes.fontFamily", modelData.value)
                    }
                }
            }

            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    text: Translation.tr("Text size")
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledSpinBox {
                    from: 10
                    to: 48
                    stepSize: 1
                    value: Number(root._readConfigKey("fontSize") ?? 14)
                    onValueModified: Config.setNestedValue(
                        "background.widgets.notes.fontSize", value)
                }
            }

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { icon: "format_align_left", value: "left" },
                        { icon: "format_align_center", value: "center" },
                        { icon: "format_align_right", value: "right" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        toggled: root.textAlign === modelData.value
                        onClicked: Config.setNestedValue(
                            "background.widgets.notes.textAlign", modelData.value)
                    }
                }
            }
        }
    }

    WidgetSurface {
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
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
            || root.effectiveBlur
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.cornerRadiusOverride >= 0
            ? root.cornerRadiusOverride : root.cardRadius
        border.width: textEdit.activeFocus ? 2 : 0
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

    Flickable {
        id: editorFlick
        anchors.fill: parent
        anchors.margins: Math.round(13 * root.scaleFactor)
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, textEdit.contentHeight)
        boundsBehavior: Flickable.StopAtBounds
        interactive: !GlobalStates.widgetEditMode

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
                ? Appearance.font.family.monospace : Appearance.font.family.main

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
        visible: textEdit.activeFocus && !GlobalStates.widgetEditMode
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.applyAlpha(root.widgetAccent, 0.12)
        colBackgroundHover: ColorUtils.applyAlpha(root.widgetAccent, 0.22)
        colRipple: ColorUtils.applyAlpha(root.widgetAccent, 0.28)
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
