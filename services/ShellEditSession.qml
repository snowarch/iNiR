pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.services

Singleton {
    id: root

    readonly property bool active: GlobalStates.shellLayoutEditMode
    property string targetOutputName: ""
    property string selectedSurfaceId: ""
    property string liftedSurfaceId: ""
    property string previewSlot: ""
    property string confirmationSurfaceId: ""
    property string confirmationSlot: ""
    property string gestureKind: ""
    property var gestureBaseline: ({})
    property string statusMessage: ""
    property var hostReports: ({})
    property int presentationRevision: 0
    property bool dragActive: false
    property real dragX: 0
    property real dragY: 0
    property string _dragCandidateSlot: ""

    // Fraction of the output dimension that counts as an edge drop zone while
    // dragging. The center remains a cancel zone.
    readonly property real dragZoneFraction: 0.26

    readonly property bool hasPendingAction: root.liftedSurfaceId.length > 0
        || root.previewSlot.length > 0
        || root.confirmationSlot.length > 0
        || root.gestureKind.length > 0

    function interactionMode(surfaceId: string): string {
        if (!root.active)
            return "normal"
        const desc = ShellLayoutController.descriptor(surfaceId)
        if (!desc || !desc.families.includes(ShellLayoutController.activeFamily))
            return "unavailable"
        if (desc.kind === "desktop")
            return "direct-manipulation"
        if (root.liftedSurfaceId === surfaceId) {
            if (root.confirmationSurfaceId === surfaceId
                    && root.confirmationSlot.length > 0)
                return "placement-confirmation"
            return root.previewSlot.length > 0 ? "placement-preview" : "lifted"
        }
        if (root.selectedSurfaceId === surfaceId)
            return "selected"
        return "select-only"
    }

    function blocksNormalActions(surfaceId: string): bool {
        const mode = root.interactionMode(surfaceId)
        return mode === "select-only" || mode === "selected"
            || mode === "lifted" || mode === "placement-preview"
            || mode === "placement-confirmation"
    }

    function _interactionSnapshot(): var {
        const snapshot = {}
        const descriptors = ShellLayoutController.surfacesForFamily(
            ShellLayoutController.activeFamily)
        for (let i = 0; i < descriptors.length; ++i) {
            const surfaceId = descriptors[i].id
            snapshot[surfaceId] = {
                mode: root.interactionMode(surfaceId),
                blocksNormalActions: root.blocksNormalActions(surfaceId)
            }
        }
        return snapshot
    }

    function reportHost(edge: string, report: var): void {
        if (edge !== "left" && edge !== "right")
            return
        const next = Object.assign({}, root.hostReports)
        next[edge] = Object.assign({}, report ?? ({}))
        root.hostReports = next
    }

    function _boundedMessage(message: string): string {
        const text = String(message ?? "")
        return text.length <= 180 ? text : text.slice(0, 177) + "..."
    }

    function _surfaceAvailable(surfaceId: string): bool {
        if (String(surfaceId ?? "").length === 0)
            return false
        const desc = ShellLayoutController.descriptor(surfaceId)
        return desc !== null
            && desc.families.includes(ShellLayoutController.activeFamily)
    }

    function reconcileEnvironment(reason: string): void {
        let message = ""
        if (root.targetOutputName.length > 0
                && !Quickshell.screens.some(screen =>
                    (screen?.name ?? "") === root.targetOutputName)) {
            root._clearPending(false)
            root.targetOutputName = root._resolvedOutputName("")
            message = "Target output changed"
        }
        if (root.selectedSurfaceId.length > 0
                && !root._surfaceAvailable(root.selectedSurfaceId)) {
            root._clearPending(false)
            root.selectedSurfaceId = ""
            message = "Selection cleared after " + String(reason ?? "layout change")
        }
        root.statusMessage = root._boundedMessage(message)
    }

    function reportSurfaceFailure(surfaceId: string, message: string): void {
        if (root.selectedSurfaceId !== surfaceId
                && root.liftedSurfaceId !== surfaceId)
            return
        root._clearPending(false)
        root.statusMessage = root._boundedMessage(message)
    }

    function _resolvedOutputName(requested: string): string {
        const requestedName = String(requested ?? "")
        if (requestedName.length > 0
                && Quickshell.screens.some(screen => (screen?.name ?? "") === requestedName))
            return requestedName

        if (CompositorService.isNiri && (NiriService.currentOutput ?? "").length > 0)
            return NiriService.currentOutput

        if (CompositorService.isHyprland && (Hyprland.focusedMonitor?.name ?? "").length > 0)
            return Hyprland.focusedMonitor.name

        return GlobalStates.primaryScreen?.name ?? Quickshell.screens[0]?.name ?? ""
    }

    function _clearPending(clearStatus: bool): void {
        root.liftedSurfaceId = ""
        root.previewSlot = ""
        root.confirmationSurfaceId = ""
        root.confirmationSlot = ""
        root.gestureKind = ""
        root.gestureBaseline = ({})
        root.dragActive = false
        root._dragCandidateSlot = ""
        if (clearStatus)
            root.statusMessage = ""
    }

    function _clearTransient(): void {
        root.targetOutputName = ""
        root.selectedSurfaceId = ""
        root._clearPending(true)
    }

    function enter(outputName: string): void {
        const resolved = root._resolvedOutputName(outputName)
        if (root.targetOutputName !== resolved) {
            root._clearPending(false)
            root.targetOutputName = resolved
        }
        root.statusMessage = ""
        if (!GlobalStates.shellLayoutEditMode)
            GlobalStates.setShellLayoutEditMode(true)
    }

    function toggle(): void {
        if (root.active)
            root.exit()
        else
            root.enter("")
    }

    function exit(): void {
        if (GlobalStates.shellLayoutEditMode)
            GlobalStates.setShellLayoutEditMode(false)
        else
            root._clearTransient()
    }

    function selectSurface(surfaceId: string): bool {
        const desc = ShellLayoutController.descriptor(surfaceId)
        if (!desc || !desc.families.includes(ShellLayoutController.activeFamily)) {
            root.statusMessage = root._boundedMessage("Surface is unavailable in the active family")
            return false
        }
        if (!root.active)
            root.enter("")
        if (root.selectedSurfaceId !== surfaceId)
            root._clearPending(false)
        root.selectedSurfaceId = surfaceId
        root.statusMessage = ""
        return true
    }

    function beginLift(surfaceId: string): bool {
        if (!root.selectSurface(surfaceId))
            return false
        root._clearPending(false)
        root.liftedSurfaceId = surfaceId
        root.gestureKind = "move"
        root.gestureBaseline = ShellLayoutController.currentState(surfaceId, root.targetOutputName)
        root.statusMessage = ""
        return true
    }

    function previewPlacement(slot: string): bool {
        if (root.liftedSurfaceId.length === 0) {
            root.statusMessage = root._boundedMessage("Select a surface before choosing a slot")
            return false
        }
        const validation = ShellLayoutController.validatePlacement(
            root.liftedSurfaceId, slot, root.targetOutputName)
        if (!validation.ok) {
            root.previewSlot = ""
            root.statusMessage = root._boundedMessage(validation.message)
            return false
        }
        if (root.previewSlot !== slot) {
            root.confirmationSurfaceId = ""
            root.confirmationSlot = ""
        }
        root.previewSlot = slot
        if (!(root.confirmationSurfaceId === root.liftedSurfaceId
                && root.confirmationSlot === slot))
            root.statusMessage = ""
        return true
    }

    function commitPlacement(slot: string): bool {
        return root._commit(slot, false)
    }

    // A pointer drop on a labeled target is already an explicit confirmation,
    // so the drag path skips the two-step swap handshake used by click/IPC.
    function _commit(slot: string, skipConfirmation: bool): bool {
        if (!root.previewPlacement(slot))
            return false
        const validation = ShellLayoutController.validatePlacement(
            root.liftedSurfaceId, slot, root.targetOutputName)
        if (!validation.ok) {
            root.statusMessage = root._boundedMessage(validation.message)
            return false
        }
        if (!skipConfirmation
                && (validation.swapWith ?? "").length > 0
                && !(root.confirmationSurfaceId === root.liftedSurfaceId
                    && root.confirmationSlot === slot)) {
            root.confirmationSurfaceId = root.liftedSurfaceId
            root.confirmationSlot = slot
            const otherLabel = ShellLayoutController.descriptor(
                validation.swapWith)?.labelKey ?? validation.swapWith
            root.statusMessage = root._boundedMessage(
                "Confirm swap with " + otherLabel)
            return false
        }
        const result = ShellLayoutController.moveSurface(
            root.liftedSurfaceId, slot, root.targetOutputName)
        if (!result.ok) {
            root.statusMessage = root._boundedMessage(result.message)
            return false
        }
        root.selectedSurfaceId = root.liftedSurfaceId
        if (result.requiresRebuild ?? false)
            root.presentationRevision = (root.presentationRevision + 1) % 2147483647
        root._clearPending(true)
        return true
    }

    function beginGesture(surfaceId: string, kind: string, baseline: var): bool {
        if (!root.selectSurface(surfaceId))
            return false
        root._clearPending(false)
        root.gestureKind = String(kind ?? "")
        root.gestureBaseline = baseline ?? ({})
        root.statusMessage = ""
        return root.gestureKind.length > 0
    }

    function _targetScreen(): var {
        const found = Quickshell.screens.find(screen =>
            (screen?.name ?? "") === root.targetOutputName)
        return found ?? GlobalStates.primaryScreen ?? Quickshell.screens[0] ?? null
    }

    function _dragSlotAt(x: real, y: real): string {
        const screen = root._targetScreen()
        const width = Math.max(1, screen?.width ?? 1920)
        const height = Math.max(1, screen?.height ?? 1080)
        const distances = {
            left: x / width,
            right: (width - x) / width,
            top: y / height,
            bottom: (height - y) / height
        }
        const legal = ShellLayoutController.descriptor(root.liftedSurfaceId)?.slots ?? []
        let best = ""
        let bestDistance = root.dragZoneFraction
        for (let i = 0; i < legal.length; ++i) {
            const slot = legal[i]
            if (distances[slot] < bestDistance) {
                best = slot
                bestDistance = distances[slot]
            }
        }
        return best
    }

    function beginDrag(surfaceId: string): bool {
        if (!root.beginLift(surfaceId))
            return false
        root.dragActive = true
        root._dragCandidateSlot = ""
        return true
    }

    function updateDrag(x: real, y: real): void {
        if (!root.dragActive)
            return
        root.dragX = x
        root.dragY = y
        const slot = root._dragSlotAt(x, y)
        if (slot === root._dragCandidateSlot)
            return
        root._dragCandidateSlot = slot
        if (slot.length === 0) {
            root.previewSlot = ""
            root.statusMessage = ""
            return
        }
        root.previewPlacement(slot)
    }

    function endDrag(): bool {
        if (!root.dragActive)
            return false
        const slot = root.previewSlot
        root.dragActive = false
        root._dragCandidateSlot = ""
        if (slot.length > 0)
            return root._commit(slot, true)
        root.cancelPending()
        return false
    }

    function cancelDrag(): void {
        if (!root.dragActive)
            return
        root.cancelPending()
    }

    function resetSurface(surfaceId: string): bool {
        const targetId = String(surfaceId ?? "").length > 0
            ? String(surfaceId) : root.selectedSurfaceId
        if (!root.selectSurface(targetId))
            return false
        const result = ShellLayoutController.resetSurface(
            targetId, root.targetOutputName)
        if (!result.ok) {
            root.statusMessage = root._boundedMessage(result.message)
            return false
        }
        if (result.requiresRebuild ?? false)
            root.presentationRevision = (root.presentationRevision + 1) % 2147483647
        root._clearPending(true)
        return true
    }

    function finishGesture(): void {
        root.gestureKind = ""
        root.gestureBaseline = ({})
        root.statusMessage = ""
    }

    function cancelPending(): bool {
        if (!root.hasPendingAction)
            return false
        root._clearPending(true)
        return true
    }

    function handleEscape(): bool {
        if (!root.active)
            return false
        if (root.cancelPending())
            return true
        root.exit()
        return true
    }

    Connections {
        target: ShellLayoutController

        function onActiveFamilyChanged(): void {
            Qt.callLater(() => root.reconcileEnvironment("panel family change"))
        }
    }

    Connections {
        target: Quickshell
        ignoreUnknownSignals: true

        function onScreensChanged(): void {
            Qt.callLater(() => root.reconcileEnvironment("output change"))
        }
    }

    Connections {
        target: GlobalStates

        function onShellLayoutEditModeChanged(): void {
            if (GlobalStates.shellLayoutEditMode) {
                if (root.targetOutputName.length === 0)
                    root.targetOutputName = root._resolvedOutputName("")
                if (root.selectedSurfaceId.length === 0) {
                    const surfaces = ShellLayoutController.surfacesForFamily(
                        ShellLayoutController.activeFamily)
                    if (surfaces.length > 0)
                        root.selectedSurfaceId = surfaces[0].id
                }
            } else {
                root._clearTransient()
            }
        }
    }

    IpcHandler {
        target: "shellLayout"

        function toggle(): string {
            root.toggle()
            return root.active ? "edit mode on" : "edit mode off"
        }

        function open(): string {
            root.enter("")
            return "edit mode on"
        }

        function openOn(outputName: string): string {
            root.enter(outputName)
            return root.targetOutputName.length > 0
                ? "edit mode on: " + root.targetOutputName
                : "edit mode on"
        }

        function close(): string {
            root.exit()
            return "edit mode off"
        }

        function select(surfaceId: string): string {
            return root.selectSurface(surfaceId)
                ? "selected: " + surfaceId
                : root.statusMessage
        }

        function lift(surfaceId: string): string {
            return root.beginLift(surfaceId)
                ? "moving: " + surfaceId
                : root.statusMessage
        }

        function preview(slot: string): string {
            return root.previewPlacement(slot)
                ? "preview: " + slot
                : root.statusMessage
        }

        function place(slot: string): string {
            return root.commitPlacement(slot)
                ? "placed: " + slot
                : root.statusMessage
        }

        function cancel(): string {
            return root.cancelPending() ? "move canceled" : "nothing to cancel"
        }

        function dragStart(surfaceId: string): string {
            return root.beginDrag(surfaceId)
                ? "dragging: " + surfaceId
                : root.statusMessage
        }

        function dragUpdate(x: real, y: real): string {
            root.updateDrag(x, y)
            return JSON.stringify({
                dragActive: root.dragActive,
                previewSlot: root.previewSlot,
                statusMessage: root.statusMessage
            })
        }

        function dragEnd(): string {
            if (root.endDrag())
                return "dropped: " + root.selectedSurfaceId
            return root.statusMessage.length > 0
                ? root.statusMessage : "drop canceled"
        }

        function reset(surfaceId: string): string {
            const targetId = String(surfaceId ?? "").length > 0
                ? String(surfaceId) : root.selectedSurfaceId
            return root.resetSurface(targetId)
                ? "reset: " + targetId
                : root.statusMessage
        }

        function setProperty(surfaceId: string, key: string, value: string): string {
            const result = ShellLayoutController.setProperty(
                surfaceId, key, value, root.targetOutputName)
            if (!result.ok) {
                root.statusMessage = root._boundedMessage(result.message)
                return root.statusMessage
            }
            root.statusMessage = ""
            return JSON.stringify(result)
        }

        function handleEscape(): string {
            return root.handleEscape() ? "handled" : "inactive"
        }

        function status(): string {
            return JSON.stringify({
                session: {
                    active: root.active,
                    targetOutputName: root.targetOutputName,
                    selectedSurfaceId: root.selectedSurfaceId,
                    liftedSurfaceId: root.liftedSurfaceId,
                    previewSlot: root.previewSlot,
                    confirmationSurfaceId: root.confirmationSurfaceId,
                    confirmationSlot: root.confirmationSlot,
                    gestureKind: root.gestureKind,
                    dragActive: root.dragActive,
                    statusMessage: root.statusMessage,
                    interactions: root._interactionSnapshot(),
                    hosts: root.hostReports
                },
                layout: ShellLayoutController.diagnosticState(root.targetOutputName)
            }, null, 2)
        }

        function validate(surfaceId: string, slot: string): string {
            return JSON.stringify(ShellLayoutController.validatePlacement(
                surfaceId, slot, root.targetOutputName), null, 2)
        }
    }
}
