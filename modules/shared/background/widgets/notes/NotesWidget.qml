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
import qs.modules.shared.background.widgets
AbstractBackgroundWidget {
    id: root

    configEntryName: "notes"

    visibleWhenLocked: false
    needsColText: true
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

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                surfaceRadius: root.cornerRadiusOverride >= 0
                    ? root.cornerRadiusOverride : root.cardRadius
                shown: !root.familyFaced && !root.instrument && (root.backgroundOpacity > 0 || root.borderWidth > 0
                    || root.effectiveBlur)
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            Rectangle {
                anchors.fill: parent
                visible: !root.familyFaced
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
        x: 16 * root.scaleFactor
        y: 14 * root.scaleFactor
        width: root.width - 32 * root.scaleFactor
        visible: !root.familyFaced && root.height >= 120 * root.scaleFactor
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
            font.pixelSize: Appearance.font.pixelSize.smaller * root.scaleFactor
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
        anchors.margins: root.familyFaced ? root.sizeGutter : Math.round(14 * root.scaleFactor)
        anchors.topMargin: root.familyFaced ? Math.round(root.sizeGutter * 2.75)
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
            cursorDelegate: TextCursor {}
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

        // A blank page is an invitation, not a stub line (iRiS draws its own, IrisNotesFace).
        WidgetBlank {
            anchors.fill: parent
            visible: !root.familyFaced && textEdit.text.length === 0 && !textEdit.activeFocus
                && height >= 70 * root.scaleFactor
            widget: root
            icon: "edit_note"
            title: Translation.tr("Write something")
            detail: Translation.tr("Click anywhere on the page to start")
        }
        StyledText {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 2
                rightMargin: 2
            }
            visible: !root.familyFaced && textEdit.text.length === 0 && !textEdit.activeFocus
                && parent.height < 70 * root.scaleFactor
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
