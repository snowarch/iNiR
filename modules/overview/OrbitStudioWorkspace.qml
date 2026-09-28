pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

FocusScope {
    id: root

    required property var effectiveOptions
    required property bool dirty
    required property real availableWidth
    required property real availableHeight
    required property bool docked
    property real inspectorWidth: 392

    signal previewRequested(string path, var value)
    signal commitRequested()
    signal revertRequested()
    signal resetDefaultsRequested()
    signal dismissed()
    signal moveStarted()
    signal moveRequested(real deltaX, real deltaY)
    signal resizeStarted()
    signal resizeRequested(real deltaX, real deltaY)
    signal resetGeometryRequested()
    signal dockRequested(bool docked)
    signal heightHintRequested(real height)

    readonly property var studioOptions: effectiveOptions?.studio ?? ({})
    readonly property bool ricelinStudio: studioOptions.surfaceStyle === "ricelin"
    readonly property string studioDialect: ricelinStudio
        ? "island" : Appearance.surfaceDialectFor("")
    readonly property string activeView: inspector.activeView
    property bool resetArmed: false
    property alias section: inspector.section

    function focusFirst(): void {
        inspector.focusFirst()
    }

    function selectView(view: string): void {
        inspector.chooseView(view)
    }

    function applyProfile(profile: string): void {
        inspector.applyOrbitProfile(profile)
    }

    function saveUserProfile(): void {
        inspector.saveUserProfile()
    }

    function applyUserProfile(): void {
        inspector.applyUserProfile()
    }

    function finishEditing(): void {
        if (root.dirty)
            root.commitRequested()
        root.dismissed()
    }

    Timer {
        id: resetArmTimer
        interval: 3000
        onTriggered: root.resetArmed = false
    }

    component CommandChip: SelectionGroupButton {
        id: chip
        property bool selected: false
        buttonText: chip.text
        toggled: selected
        bounce: false
        horizontalPadding: 9
        verticalPadding: 5
        enableImplicitWidthAnimation: false
        enableImplicitHeightAnimation: false
    }

    OrbitStudio {
        id: inspector
        z: root.docked ? 20 : 1
        x: root.docked ? root.width - width - 18 : 0
        y: root.docked ? commandDeck.y + commandDeck.height + 14 : 0
        width: root.docked ? Math.max(340, Math.min(root.inspectorWidth,
            Math.min(420, root.width * 0.32))) : root.width
        height: root.docked ? Math.min(root.height - y - 18,
            Math.max(430, Math.min(680, idealHeight))) : root.height
        effectiveOptions: root.effectiveOptions
        dirty: root.dirty
        availableWidth: width
        availableHeight: height
        docked: root.docked
        workspaceMode: root.docked
        onPreviewRequested: (path, value) => root.previewRequested(path, value)
        onCommitRequested: root.commitRequested()
        onRevertRequested: root.revertRequested()
        onResetDefaultsRequested: root.resetDefaultsRequested()
        onDismissed: root.dismissed()
        onMoveStarted: root.moveStarted()
        onMoveRequested: (deltaX, deltaY) => root.moveRequested(deltaX, deltaY)
        onResizeStarted: root.resizeStarted()
        onResizeRequested: (deltaX, deltaY) => root.resizeRequested(deltaX, deltaY)
        onResetGeometryRequested: root.resetGeometryRequested()
        onDockRequested: docked => root.dockRequested(docked)
        onHeightHintRequested: height => root.heightHintRequested(height)
    }

    PanelSurface {
        id: commandDeck
        visible: root.docked
        z: 30
        anchors.top: parent.top
        anchors.topMargin: 16
        x: Math.round(Math.max(18,
            (root.width - inspector.width - 36 - width) / 2))
        width: Math.min(parent.width - 148, Math.max(680, deckRow.implicitWidth + 28))
        height: 52
        elevation: 3
        cardStyle: true
        outlined: true
        clipContent: true
        opaqueSurface: !root.ricelinStudio
        islandSkin: root.ricelinStudio
        surfaceDialect: root.studioDialect
        wallpaperBackdrop: root.ricelinStudio

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        RowLayout {
            id: deckRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 8

            RowLayout {
                spacing: 7
                MaterialSymbol {
                    text: "orbit"
                    iconSize: 20
                    textRenderType: Text.QtRendering
                    color: Appearance.colors.colPrimary
                }
                ColumnLayout {
                    spacing: 0
                    StyledText {
                        text: Translation.tr("Orbit Studio")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: root.dirty ? Translation.tr("Unsaved · Done saves")
                            : Translation.tr("Live scene")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.dirty ? Appearance.colors.colPrimary
                            : Appearance.colors.colSubtext
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.5)
            }

            ButtonGroup {
                spacing: 3
                CommandChip { text: Translation.tr("Stage"); selected: root.activeView === "stage"; onClicked: root.selectView("stage") }
                CommandChip { text: Translation.tr("Orbit"); selected: root.activeView === "orbit"; onClicked: root.selectView("orbit") }
                CommandChip { text: Translation.tr("Horizon"); selected: root.activeView === "horizon"; onClicked: root.selectView("horizon") }
                CommandChip { text: Translation.tr("Gallery"); selected: root.activeView === "gallery"; onClicked: root.selectView("gallery") }
                CommandChip { text: Translation.tr("Deck"); selected: root.activeView === "deck"; onClicked: root.selectView("deck") }
                CommandChip { text: Translation.tr("Atlas"); selected: root.activeView === "atlas"; onClicked: root.selectView("atlas") }
            }

            Item { Layout.fillWidth: true }

            IconToolbarButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: false
                text: "undo"
                enabled: root.dirty
                iconRenderType: Text.QtRendering
                onClicked: root.revertRequested()
                M3ToolTip { text: Translation.tr("Revert preview") }
            }
            IconToolbarButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: false
                text: root.resetArmed ? "warning" : "restart_alt"
                toggled: root.resetArmed
                iconRenderType: Text.QtRendering
                onClicked: {
                    if (!root.resetArmed) {
                        root.resetArmed = true
                        resetArmTimer.restart()
                        return
                    }
                    resetArmTimer.stop()
                    root.resetArmed = false
                    root.resetDefaultsRequested()
                }
                M3ToolTip {
                    text: root.resetArmed ? Translation.tr("Confirm reset Orbit")
                        : Translation.tr("Reset Orbit defaults")
                }
            }
            IconToolbarButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: false
                text: "settings"
                iconRenderType: Text.QtRendering
                onClicked: {
                    root.dismissed()
                    GlobalStates.openSettingsPage(27)
                }
                M3ToolTip { text: Translation.tr("Orbit settings") }
            }
            IconToolbarButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: false
                text: "open_in_full"
                iconRenderType: Text.QtRendering
                onClicked: root.dockRequested(false)
                M3ToolTip { text: Translation.tr("Detach editor") }
            }
            IconToolbarButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.fillHeight: false
                text: "done"
                toggled: true
                iconRenderType: Text.QtRendering
                onClicked: root.finishEditing()
                M3ToolTip { text: root.dirty ? Translation.tr("Save changes and close") : Translation.tr("Done") }
            }
        }
    }

}
