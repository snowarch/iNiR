pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.functions

// Persistent shell editing owns a dedicated layer-shell surface. Do not embed
// this HUD in Background.qml or bind it to widgetEditMode: widgets and edge
// surfaces have different geometry, input and stacking contracts.
Scope {
    id: root

    required property string family
    required property string styleKey
    required property color accentColor
    required property color surfaceColor
    required property color elevatedSurfaceColor
    required property color textColor
    required property color secondaryTextColor
    required property color borderColor
    required property string fontFamily
    required property int titlePixelSize
    required property int bodyPixelSize
    required property int smallPixelSize
    required property real panelRadius
    required property real controlRadius
    required property int animationDuration

    readonly property bool familyActive:
        ShellLayoutController.activeFamily === root.family

    readonly property color accentLit: Qt.lighter(root.accentColor, 1.12)
    readonly property color hairColor: ColorUtils.applyAlpha(root.textColor, 0.12)
    readonly property color frameBgColor: ColorUtils.applyAlpha(root.textColor, 0.06)
    readonly property color frameBgHoverColor: ColorUtils.applyAlpha(root.textColor, 0.11)
    readonly property bool compactChrome: root.styleKey === "inir"
        || root.styleKey === "zzz"
    readonly property bool strongOutline: root.styleKey === "inir"
        || root.styleKey === "angel"

    function surfaceLabel(surfaceId: string): string {
        switch (surfaceId) {
        case "featureSidebar": return Translation.tr("Feature sidebar")
        case "systemSidebar": return Translation.tr("System sidebar")
        case "iiBar": return Translation.tr("Bar")
        case "iiDock": return Translation.tr("Dock")
        case "waffleBar": return Translation.tr("Taskbar")
        default: return surfaceId
        }
    }

    function slotLabel(slot: string): string {
        switch (slot) {
        case "top": return Translation.tr("Top")
        case "right": return Translation.tr("Right")
        case "bottom": return Translation.tr("Bottom")
        case "left": return Translation.tr("Left")
        default: return slot
        }
    }

    function scopeLabel(scope: string): string {
        if (scope === "global")
            return Translation.tr("Global")
        if (scope === "enabledOutputs")
            return Translation.tr("Enabled outputs")
        return ""
    }

    component EditorButton: Rectangle {
        id: button

        required property string label
        property string icon: ""
        property bool selected: false
        property bool emphasized: false
        property string accessibleDescription: ""
        readonly property color resolvedBorderColor: button.emphasized
            ? root.accentColor
            : button.selected
                ? ColorUtils.applyAlpha(root.accentColor, 0.85)
                : buttonHover.hovered
                    ? ColorUtils.applyAlpha(root.textColor, 0.22)
                    : root.borderColor
        readonly property color resolvedFillColor: button.emphasized
            ? ColorUtils.applyAlpha(root.accentColor,
                buttonInput.pressed ? 0.42 : buttonHover.hovered ? 0.34 : 0.26)
            : button.selected
                ? ColorUtils.applyAlpha(root.accentColor,
                    buttonInput.pressed ? 0.28 : 0.18)
                : buttonInput.pressed ? ColorUtils.applyAlpha(root.textColor, 0.16)
                    : buttonHover.hovered ? root.frameBgHoverColor : root.frameBgColor

        signal triggered()

        implicitWidth: Math.max(42, buttonContent.implicitWidth + 22)
        implicitHeight: 32
        width: implicitWidth
        height: implicitHeight
        radius: root.compactChrome ? Math.min(root.controlRadius, 8)
            : root.controlRadius
        border.width: root.styleKey !== "zzz" && (root.strongOutline || button.selected
            || button.emphasized) ? 1 : 0
        border.color: button.resolvedBorderColor
        color: root.styleKey === "zzz" ? "transparent"
            : button.resolvedFillColor
        opacity: button.enabled ? 1 : 0.45

        Accessible.role: Accessible.Button
        Accessible.name: button.label
        Accessible.description: button.accessibleDescription
        Accessible.focusable: button.enabled
        activeFocusOnTab: button.enabled

        Behavior on border.color {
            enabled: root.animationDuration > 0
            ColorAnimation { duration: root.animationDuration }
        }

        ZzzPlate {
            anchors.fill: parent
            visible: root.styleKey === "zzz"
            z: -1
            chamfer: 6
            fillColor: button.resolvedFillColor
            strokeColor: button.selected || button.emphasized
                ? button.resolvedBorderColor : root.hairColor
            strokeWidth: button.selected || button.emphasized ? 1 : 0
        }

        Row {
            id: buttonContent
            anchors.centerIn: parent
            spacing: button.icon.length > 0 ? 6 : 0

            MaterialSymbol {
                visible: button.icon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: button.icon
                iconSize: root.smallPixelSize + 4
                color: root.textColor
            }

            Text {
                id: buttonLabel
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                color: root.textColor
                font.family: root.fontFamily
                font.pixelSize: root.smallPixelSize
                font.weight: Font.DemiBold
            }
        }

        Keys.onPressed: event => {
            if (!button.enabled)
                return
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Space) {
                button.triggered()
                event.accepted = true
            }
        }

        HoverHandler { id: buttonHover }
        TapHandler {
            id: buttonInput
            enabled: button.enabled
            onTapped: {
                button.forceActiveFocus()
                button.triggered()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: editorWindow

            required property ShellScreen modelData
            screen: modelData

            property bool presentationReady: false

            readonly property string screenName: modelData?.name ?? ""
            readonly property bool isTargetOutput:
                ShellEditSession.targetOutputName.length === 0
                || ShellEditSession.targetOutputName === screenName
            readonly property var descriptors:
                ShellLayoutController.surfacesForFamily(root.family)
            readonly property string placementFingerprint: {
                void Config.revision
                const parts = []
                for (let i = 0; i < editorWindow.descriptors.length; i++) {
                    const descriptor = editorWindow.descriptors[i]
                    const state = ShellLayoutController.currentState(
                        descriptor.id, editorWindow.screenName)
                    parts.push(descriptor.id + ":" + String(state?.slot ?? ""))
                }
                return parts.join("|")
            }
            readonly property var selectedDescriptor:
                ShellLayoutController.descriptor(ShellEditSession.selectedSurfaceId)
            readonly property var selectedState: {
                void Config.revision
                if (!selectedDescriptor)
                    return null
                return ShellLayoutController.currentState(
                    ShellEditSession.selectedSurfaceId, screenName)
            }
            readonly property bool sidebarSelected:
                ShellEditSession.selectedSurfaceId === "featureSidebar"
                || ShellEditSession.selectedSurfaceId === "systemSidebar"
            readonly property var targetValidations: {
                void Config.revision
                const surfaceId = ShellEditSession.liftedSurfaceId
                const descriptor = ShellLayoutController.descriptor(surfaceId)
                if (!descriptor)
                    return ({})
                const results = ({})
                for (let i = 0; i < descriptor.slots.length; i++) {
                    const slot = descriptor.slots[i]
                    results[slot] = ShellLayoutController.validatePlacement(
                        surfaceId, slot, editorWindow.screenName)
                }
                return results
            }
            onPlacementFingerprintChanged: {
                if (ShellEditSession.active && editorWindow.presentationReady)
                    editorWindow.schedulePresentation()
            }

            readonly property string dropHintText: {
                if (ShellEditSession.previewSlot.length > 0) {
                    const validation = editorWindow.targetValidations[
                        ShellEditSession.previewSlot]
                    const swapId = String(validation?.swapWith ?? "")
                    if (swapId.length > 0)
                        return Translation.tr("Swap with %1")
                            .arg(root.surfaceLabel(swapId))
                    return root.slotLabel(ShellEditSession.previewSlot)
                }
                return Translation.tr("Release over an edge · center cancels")
            }

            readonly property string statusText: {
                if (ShellEditSession.statusMessage.length > 0)
                    return ShellEditSession.statusMessage
                if (ShellEditSession.dragActive)
                    return editorWindow.dropHintText
                if (ShellEditSession.liftedSurfaceId.length > 0)
                    return Translation.tr("Choose an edge. Occupied sidebar targets require confirmation.")
                if (sidebarSelected)
                    return Translation.tr("Drag the panel to another edge, or resize it from its handles.")
                return Translation.tr("Drag a highlighted surface to a screen edge, or select it here.")
            }

            visible: ShellEditSession.active && root.familyActive
                && editorWindow.isTargetOutput && editorWindow.presentationReady
            implicitWidth: modelData?.width ?? 1920
            implicitHeight: modelData?.height ?? 1080
            color: "transparent"
            exclusiveZone: 0

            WlrLayershell.namespace: "quickshell:shell-layout-editor-" + root.family
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: true
                right: true
                bottom: true
                left: true
            }

            function schedulePresentation(): void {
                editorWindow.presentationReady = false
                presentationTimer.restart()
            }

            Component.onCompleted: {
                if (ShellEditSession.active) {
                    editorWindow.schedulePresentation()
                    deferredRaiseTimer.restart()
                }
            }

            Timer {
                id: presentationTimer
                interval: 60
                onTriggered: {
                    if (ShellEditSession.active && root.familyActive
                            && editorWindow.isTargetOutput)
                        editorWindow.presentationReady = true
                }
            }

            Timer {
                id: deferredRaiseTimer
                interval: 700
                onTriggered: {
                    if (ShellEditSession.active)
                        editorWindow.schedulePresentation()
                }
            }

            Connections {
                target: ShellEditSession

                function onActiveChanged(): void {
                    if (ShellEditSession.active) {
                        editorWindow.schedulePresentation()
                        deferredRaiseTimer.restart()
                    } else {
                        presentationTimer.stop()
                        deferredRaiseTimer.stop()
                        editorWindow.presentationReady = false
                    }
                }

                function onPresentationRevisionChanged(): void {
                    if (ShellEditSession.active)
                        editorWindow.schedulePresentation()
                }
            }

            Item { id: emptyInputItem; width: 0; height: 0 }

            mask: Region {
                Region {
                    item: editorHud.visible ? editorHud : emptyInputItem
                }
                Region {
                    item: edgeTargets.topTargetItem?.visible
                        ? edgeTargets.topTargetItem : emptyInputItem
                }
                Region {
                    item: edgeTargets.rightTargetItem?.visible
                        ? edgeTargets.rightTargetItem : emptyInputItem
                }
                Region {
                    item: edgeTargets.bottomTargetItem?.visible
                        ? edgeTargets.bottomTargetItem : emptyInputItem
                }
                Region {
                    item: edgeTargets.leftTargetItem?.visible
                        ? edgeTargets.leftTargetItem : emptyInputItem
                }
            }

            ShellEditEdgeTargets {
                id: edgeTargets
                anchors.fill: parent
                active: editorWindow.visible
                    && ShellEditSession.liftedSurfaceId.length > 0
                slots: editorWindow.selectedDescriptor?.slots ?? []
                currentSlot: editorWindow.selectedState?.slot ?? ""
                previewedSlot: ShellEditSession.previewSlot
                validations: editorWindow.targetValidations
                topLabel: Translation.tr("Top")
                rightLabel: Translation.tr("Right")
                bottomLabel: Translation.tr("Bottom")
                leftLabel: Translation.tr("Left")
                accentColor: root.accentColor
                surfaceColor: root.surfaceColor
                textColor: root.textColor
                radius: root.panelRadius
                fontFamily: root.fontFamily
                fontPixelSize: root.bodyPixelSize
                animationDuration: root.animationDuration
                topEdgeMargin: ShellEditSession.dragActive
                    ? 14 : editorHud.height + 30
                bottomEdgeMargin: 14
                onPreviewRequested: slot => ShellEditSession.previewPlacement(slot)
                onPlacementRequested: slot => ShellEditSession.commitPlacement(slot)
            }

            Rectangle {
                anchors.fill: editorHud
                z: editorHud.z - 1
                radius: editorHud.radius
                color: ColorUtils.applyAlpha(root.textColor,
                    root.styleKey === "angel" ? 0.16 : 0.10)
                visible: editorHud.visible
                opacity: editorHud.opacity
                transform: Translate { y: 2 }
            }

            Rectangle {
                id: editorHud

                anchors {
                    top: parent.top
                    topMargin: 18
                }
                x: Math.round((parent.width - width) / 2)
                width: Math.round(Math.min(
                    hudColumn.implicitWidth + 36, parent.width - 36))
                height: Math.round(hudColumn.implicitHeight + 26)
                z: 100000
                radius: root.compactChrome ? Math.min(root.panelRadius, 12)
                    : root.panelRadius
                border.width: root.styleKey !== "zzz" && root.strongOutline ? 1 : 0
                border.color: root.borderColor
                color: root.styleKey === "zzz" ? "transparent"
                    : ColorUtils.applyAlpha(root.elevatedSurfaceColor, 0.98)
                // The HUD steps aside while the pointer drag owns the screen;
                // the ghost chip carries the status until release.
                opacity: ShellEditSession.dragActive ? 0 : 1
                visible: opacity > 0.02

                Behavior on opacity {
                    enabled: root.animationDuration > 0
                    NumberAnimation { duration: root.animationDuration }
                }

                ZzzPlate {
                    anchors.fill: parent
                    visible: root.styleKey === "zzz"
                    z: -2
                    chamfer: 12
                    chamferTopRight: false
                    fillColor: root.elevatedSurfaceColor
                    strokeColor: root.borderColor
                    strokeWidth: 1
                }

                ZzzTechFrame {
                    anchors.fill: parent
                    visible: root.styleKey === "zzz"
                    z: -1
                    margin: 7
                    showGrid: false
                    showCornerMarks: true
                    showLabels: false
                    showTicks: false
                    accentColor: root.accentColor
                }

                Column {
                    id: hudColumn
                    anchors {
                        top: parent.top
                        topMargin: 12
                    }
                    x: Math.round((parent.width - width) / 2)
                    spacing: 8

                    Row {
                        id: hudTopRow
                        spacing: 10

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "dashboard_customize"
                            iconSize: root.titlePixelSize + 5
                            color: root.accentColor
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: Translation.tr("Shell layout")
                                color: root.textColor
                                font.family: root.fontFamily
                                font.pixelSize: root.titlePixelSize
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: editorWindow.screenName
                                    + (editorWindow.selectedState?.scope
                                        ? " · " + root.scopeLabel(
                                            editorWindow.selectedState.scope) : "")
                                color: root.secondaryTextColor
                                font.family: root.fontFamily
                                font.pixelSize: root.smallPixelSize
                                font.features: { "tnum": 1 }
                            }
                        }

                        Item { width: 8; height: 1 }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Repeater {
                                model: editorWindow.descriptors

                                EditorButton {
                                    required property var modelData
                                    label: root.surfaceLabel(modelData.id)
                                    icon: modelData.icon ?? ""
                                    selected: ShellEditSession.selectedSurfaceId
                                        === modelData.id
                                    accessibleDescription: Translation.tr(
                                        "Select this shell surface")
                                    onTriggered: ShellEditSession.selectSurface(
                                        modelData.id)
                                }
                            }
                        }

                        Item { width: 8; height: 1 }

                        EditorButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: ShellEditSession.liftedSurfaceId.length > 0
                                ? Translation.tr("Cancel move")
                                : Translation.tr("Move")
                            icon: ShellEditSession.liftedSurfaceId.length > 0
                                ? "close" : "open_with"
                            selected: ShellEditSession.liftedSurfaceId.length > 0
                            enabled: editorWindow.selectedDescriptor !== null
                            onTriggered: {
                                if (ShellEditSession.liftedSurfaceId.length > 0)
                                    ShellEditSession.cancelPending()
                                else
                                    ShellEditSession.beginLift(
                                        ShellEditSession.selectedSurfaceId)
                            }
                        }

                        EditorButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: Translation.tr("Reset")
                            icon: "restart_alt"
                            enabled: editorWindow.selectedDescriptor !== null
                            onTriggered: ShellEditSession.resetSurface(
                                ShellEditSession.selectedSurfaceId)
                        }

                        EditorButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: Translation.tr("Done")
                            icon: "done"
                            emphasized: true
                            onTriggered: ShellEditSession.exit()
                        }
                    }

                    Rectangle {
                        width: hudTopRow.width
                        height: 1
                        color: root.hairColor
                    }

                    Row {
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: editorWindow.selectedDescriptor
                                ? root.surfaceLabel(editorWindow.selectedDescriptor.id)
                                    + " · " + root.slotLabel(
                                        editorWindow.selectedState?.slot ?? "")
                                : Translation.tr("No surface selected")
                            color: root.textColor
                            font.family: root.fontFamily
                            font.pixelSize: root.bodyPixelSize
                            font.weight: Font.DemiBold
                        }

                        Row {
                            visible: editorWindow.sidebarSelected
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5

                            Repeater {
                                model: ["full", "fit", "custom"]

                                EditorButton {
                                    required property string modelData
                                    label: modelData === "full"
                                        ? Translation.tr("Full")
                                        : modelData === "fit"
                                            ? Translation.tr("Fit")
                                            : Translation.tr("Custom")
                                    selected: editorWindow.selectedState?.sizeMode
                                        === modelData
                                    onTriggered: ShellLayoutController.setProperty(
                                        ShellEditSession.selectedSurfaceId,
                                        "sizeMode", modelData,
                                        editorWindow.screenName)
                                }
                            }
                        }

                        Text {
                            visible: editorWindow.sidebarSelected
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(editorWindow.selectedState?.width ?? 0)
                                + " × "
                                + Math.round(editorWindow.selectedState?.customHeight ?? 0)
                            color: root.secondaryTextColor
                            font.family: root.fontFamily
                            font.pixelSize: root.smallPixelSize
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 420)
                            text: editorWindow.statusText
                            color: ShellEditSession.statusMessage.length > 0
                                ? root.accentColor : root.secondaryTextColor
                            font.family: root.fontFamily
                            font.pixelSize: root.smallPixelSize
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Drag ghost: a compact chip that follows the grabbed pointer. It
            // never enters the input mask, so it cannot steal the grab.
            Rectangle {
                anchors.fill: dragGhost
                z: dragGhost.z - 1
                radius: dragGhost.radius
                color: ColorUtils.applyAlpha(root.textColor, 0.10)
                visible: dragGhost.visible
                transform: Translate { y: 2 }
            }

            Rectangle {
                id: dragGhost
                visible: ShellEditSession.dragActive && editorWindow.visible
                x: Math.round(Math.max(10, Math.min(parent.width - width - 10,
                    ShellEditSession.dragX + 20)))
                y: Math.round(Math.max(10, Math.min(parent.height - height - 10,
                    ShellEditSession.dragY + 24)))
                width: Math.round(ghostRow.implicitWidth + 32)
                height: Math.round(ghostRow.implicitHeight + 20)
                z: 100001
                radius: height / 2
                border.width: 1
                border.color: ShellEditSession.previewSlot.length > 0
                    ? ColorUtils.applyAlpha(root.accentLit, 0.95)
                    : root.hairColor
                color: ColorUtils.applyAlpha(root.elevatedSurfaceColor, 0.97)
                Behavior on border.color {
                    enabled: root.animationDuration > 0
                    ColorAnimation { duration: root.animationDuration }
                }

                Row {
                    id: ghostRow
                    anchors.centerIn: parent
                    spacing: 10

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: editorWindow.selectedDescriptor?.icon ?? "open_with"
                        iconSize: root.bodyPixelSize + 5
                        color: ShellEditSession.previewSlot.length > 0
                            ? root.accentLit : root.secondaryTextColor
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: root.surfaceLabel(
                                ShellEditSession.liftedSurfaceId)
                            color: root.textColor
                            font.family: root.fontFamily
                            font.pixelSize: root.smallPixelSize
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: editorWindow.dropHintText
                            color: ShellEditSession.previewSlot.length > 0
                                ? root.accentLit : root.secondaryTextColor
                            font.family: root.fontFamily
                            font.pixelSize: root.smallPixelSize
                            font.features: { "tnum": 1 }

                            Behavior on color {
                                enabled: root.animationDuration > 0
                                ColorAnimation { duration: root.animationDuration }
                            }
                        }
                    }
                }
            }

            Shortcut {
                enabled: editorWindow.visible
                sequences: ["Escape"]
                onActivated: ShellEditSession.handleEscape()
            }

            Shortcut {
                enabled: editorWindow.visible
                sequences: ["M"]
                onActivated: {
                    if (ShellEditSession.selectedSurfaceId.length === 0)
                        return
                    if (ShellEditSession.liftedSurfaceId.length > 0)
                        ShellEditSession.cancelPending()
                    else
                        ShellEditSession.beginLift(
                            ShellEditSession.selectedSurfaceId)
                }
            }

            Shortcut {
                enabled: editorWindow.visible
                sequences: ["R"]
                onActivated: ShellEditSession.resetSurface(
                    ShellEditSession.selectedSurfaceId)
            }
        }
    }
}
