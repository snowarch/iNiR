pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common

// Where the shell's persistent surfaces sit (bar, dock, sidebars...), what can change about them, and the room they
// take on the desktop. The engine is here; every surface belongs to the active family's `layout` part (plugin.json),
// which answers for its own config:
//   surfaces, rebuilds               descriptors, and the ones a move rebuilds
//   surfaceState(id, desc, output)   where it is now ({ ok, slot, ... })
//   occupant?(id, slot, output)      the surface on that slot a move swaps with
//   moveSurface(id, slot, output, swapWith) -> bool
//   setProperty?(id, key, value, output) -> { ok, effectiveValue } or a failure
//   resetSurface?(id, output) or resetSlot?(id)
//   desktopInsets?(output, result)   barEdge, barThickness, dockEdge, dockThickness and the four insets
//   sidebarAssignments?()            which side each sidebar role takes
//   frameBand?(), frameCorners?()    a frame's band and cut corners
Singleton {
    id: root

    readonly property string activeFamily: Config.options?.panelFamily ?? "ii"
    readonly property int desktopWidgetOuterGap: 12

    FamilyPartLoader { id: familyLayout; part: "layout" }
    readonly property var _family: familyLayout.item
    readonly property var _descriptors: Array.from(root._family?.surfaces ?? [])

    function _clone(value: var): var {
        return JSON.parse(JSON.stringify(value))
    }

    function _failure(code: string, message: string): var {
        return {
            ok: false,
            code: code,
            message: message,
            effectiveSlot: "",
            scope: "",
            requiresRebuild: false
        }
    }

    function sidebarAssignments(): var {
        return root._family?.sidebarAssignments?.() ?? { featureSidebar: "left", systemSidebar: "right", sanitized: false }
    }

    function sidebarRoleForSlot(slot: string): string {
        const assignments = root.sidebarAssignments()
        if (assignments.featureSidebar === slot)
            return "featureSidebar"
        if (assignments.systemSidebar === slot)
            return "systemSidebar"
        return ""
    }

    // Physical-side sidebar helpers for spatial triggers (bar corner buttons):
    // a left-corner control always addresses whatever role currently occupies
    // the left slot, while feature-specific triggers keep semantic open state.
    function sidebarOpenAtSlot(slot: string, outputName): bool {
        const role = root.sidebarRoleForSlot(slot)
        const requestedOutput = String(outputName ?? "")
        if (role === "featureSidebar")
            return GlobalStates.sidebarLeftOpen
                && (requestedOutput.length === 0
                    || GlobalStates.sidebarLeftPresentationOutput === requestedOutput)
        if (role === "systemSidebar")
            return GlobalStates.sidebarRightOpen
                && (requestedOutput.length === 0
                    || GlobalStates.sidebarRightPresentationOutput === requestedOutput)
        return false
    }

    function setSidebarOpenAtSlot(slot: string, open: bool, outputName): void {
        const role = root.sidebarRoleForSlot(slot)
        if (role === "featureSidebar") {
            if (open)
                GlobalStates.openSidebarLeft(outputName)
            else
                GlobalStates.closeSidebarLeft()
        } else if (role === "systemSidebar") {
            if (open)
                GlobalStates.openSidebarRight(outputName)
            else
                GlobalStates.closeSidebarRight()
        }
    }

    function toggleSidebarAtSlot(slot: string, outputName): void {
        root.setSidebarOpenAtSlot(slot,
            !root.sidebarOpenAtSlot(slot, outputName), outputName)
    }

    function descriptor(surfaceId: string): var {
        const found = root._descriptors.find(item => item.id === surfaceId)
        return found ? root._clone(found) : null
    }

    function surfacesForFamily(family: string): var {
        const targetFamily = family.length > 0 ? family : root.activeFamily
        return root._descriptors
            .filter(item => item.families.includes(targetFamily))
            .map(item => root._clone(item))
    }

    function panelEnabled(identifier: string): bool {
        return (Config.options?.enabledPanels ?? []).includes(identifier)
    }

    function outputEnabled(configuredOutputs: var, outputName: string): bool {
        if (!Array.isArray(configuredOutputs) || configuredOutputs.length === 0)
            return true
        if (outputName.length > 0 && configuredOutputs.includes(outputName))
            return true
        const currentNames = Quickshell.screens.map(screen => screen?.name ?? "")
        return !configuredOutputs.some(name => currentNames.includes(name))
    }

    function applyInset(insets: var, edge: string, thickness: real): void {
        if (!(edge in insets))
            return
        insets[edge] = Math.max(insets[edge], Math.max(0, Math.round(thickness)))
    }

    // Physical desktop space the active family's persistent surfaces take on an output, and where its bar and dock
    // sit. Free desktop placement can overlap it deliberately; zone placement, diagnostics and shared surfaces that
    // keep clear of the bar (overview, picker, media controls, the mascot) read it.
    function desktopInsets(outputName: string): var {
        const result = {
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
            barEdge: "",
            barThickness: 0,
            dockEdge: "",
            dockThickness: 0
        }
        return root._family?.desktopInsets ? root._family.desktopInsets(String(outputName ?? ""), result) : result
    }

    function _workAreaFromInsets(insets: var, screenWidth: real,
            screenHeight: real, gap: real): var {
        const left = Math.max(0, (insets.left ?? 0) + gap)
        const top = Math.max(0, (insets.top ?? 0) + gap)
        const right = Math.max(left,
            Math.max(0, Number(screenWidth) || 0) - (insets.right ?? 0) - gap)
        const bottom = Math.max(top,
            Math.max(0, Number(screenHeight) || 0) - (insets.bottom ?? 0) - gap)
        return {
            insets: insets,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            width: Math.max(0, right - left),
            height: Math.max(0, bottom - top)
        }
    }

    function desktopWorkArea(outputName: string, screenWidth: real,
            screenHeight: real): var {
        const panelInsets = root.desktopInsets(outputName)
        // Free placement reaches the screen's edge, or where a family's frame lets widgets rest (iRiS: a breath inside
        // its band). The shell's own bodies are kept clear by arranging (DesktopArrange.bodies), not by bands.
        const band = root._family?.frameBand ? root._family.frameBand() : 0
        const area = root._workAreaFromInsets({
            left: band,
            top: band,
            right: band,
            bottom: band,
            barEdge: panelInsets.barEdge ?? "",
            dockEdge: panelInsets.dockEdge ?? ""
        }, screenWidth, screenHeight, 0)
        // A frame that cuts its corners: [tl, tr, br, bl], the least sum of a widget's two gaps there (ArrangeMath).
        area.corners = root._family?.frameCorners ? root._family.frameCorners() : null
        return area
    }

    // Zone placement is intentionally panel-aware while free placement spans
    // the full desktop. This keeps deliberate edge placement possible without
    // letting automatic zone snaps disappear underneath a movable bar or dock.
    function desktopZoneWorkArea(outputName: string, screenWidth: real,
            screenHeight: real): var {
        return root._workAreaFromInsets(root.desktopInsets(outputName),
            screenWidth, screenHeight, root.desktopWidgetOuterGap)
    }

    function currentState(surfaceId: string, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return root._failure("unknown-surface", "Unknown shell surface")
        return root._family?.surfaceState?.(surfaceId, desc, outputName)
            ?? root._failure("unsupported-surface", "Surface state adapter is unavailable")
    }

    function legalSlots(surfaceId: string, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return []
        return root._clone(desc.slots)
    }

    function validatePlacement(surfaceId: string, slot: string, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return root._failure("unknown-surface", "Unknown shell surface")
        if (!desc.families.includes(root.activeFamily))
            return root._failure("inactive-family", "Surface is unavailable in the active family")
        if (!desc.slots.includes(slot))
            return root._failure("invalid-slot", "Surface does not support that slot")

        // Surfaces exchange edges: dropping one on another's slot is an atomic swap, never a silent overlap.
        const current = root.currentState(surfaceId, outputName)
        const changed = !(current.ok && current.slot === slot)
        const occupiedBy = changed ? String(root._family?.occupant?.(surfaceId, slot, outputName) ?? "") : ""
        return {
            ok: true,
            code: "",
            message: "",
            effectiveSlot: slot,
            scope: desc.layoutScope,
            outputName: outputName,
            occupiedBy: occupiedBy,
            swapWith: occupiedBy,
            changed: changed,
            requiresRebuild: Array.from(root._family?.rebuilds ?? []).includes(surfaceId)
        }
    }

    function moveSurface(surfaceId: string, slot: string, outputName: string): var {
        const validation = root.validatePlacement(surfaceId, slot, outputName)
        if (!validation.ok || !validation.changed)
            return validation
        if (root._family?.moveSurface?.(surfaceId, slot, outputName, validation.swapWith ?? "") !== true)
            return root._failure("mutation-not-ready", "Placement mutation is not available for this surface yet")
        Config.flushWrites()
        const result = root._clone(validation)
        result.changed = true
        result.persisted = true
        return result
    }

    function setProperty(surfaceId: string, key: string, value: var, outputName: string): var {
        const desc = root.descriptor(surfaceId)
        if (!desc)
            return root._failure("unknown-surface", "Unknown shell surface")
        if (!desc.editableProperties.includes(key))
            return root._failure("unsupported-property", "Surface does not expose that property")
        const done = root._family?.setProperty?.(surfaceId, key, value, outputName)
        if (!done)
            return root._failure("mutation-not-ready", "Property mutation is not available for this surface yet")
        if (!done.ok)
            return root._failure(done.code ?? "invalid-value", done.message ?? "")
        Config.flushWrites()
        return {
            ok: true,
            code: "",
            message: "",
            property: key,
            effectiveValue: done.effectiveValue,
            scope: desc.layoutScope,
            outputName: outputName,
            persisted: true,
            requiresRebuild: false
        }
    }

    function resetSurface(surfaceId: string, outputName: string): var {
        if (!root.descriptor(surfaceId))
            return root._failure("unknown-surface", "Unknown shell surface")
        const reset = root._family?.resetSurface?.(surfaceId, outputName)
        if (reset)
            return reset
        const slot = root._family?.resetSlot?.(surfaceId) ?? ""
        if (slot)
            return root.moveSurface(surfaceId, slot, outputName)
        return root._failure("reset-not-ready", "Reset is not available for this surface yet")
    }

    function diagnosticState(outputName: string): var {
        const descriptors = root.surfacesForFamily(root.activeFamily)
        return {
            family: root.activeFamily,
            outputName: outputName,
            surfaces: descriptors.map(desc => ({
                descriptor: desc,
                current: root.currentState(desc.id, outputName),
                legalSlots: root.legalSlots(desc.id, outputName)
            }))
        }
    }
}
