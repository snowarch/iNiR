import qs.modules.common
import qs.modules.common.widgets
import Quickshell

// Alias to the generic ContextMenu with dock-specific defaults
ContextMenu {
    readonly property string dockPosition: Config.options?.dock?.position ?? "bottom"
    readonly property bool isVertical: dockPosition === "left" || dockPosition === "right"

    // Do not arm hover dismissal until the pointer has actually entered the
    // popup. That preserves the button -> popup handoff while still letting the
    // menu retire itself after the user moves away from the interaction.
    closeOnFocusLost: true
    closeOnHoverLost: true
    closeOnHoverLostAfterEntered: true
    closeOnHoverLostDelay: 650
    scaleContent: false
    fadeContent: true
    revealDistance: 8
    enterDuration: Appearance.calcEffectiveDuration(160, Appearance.animationSpeed.enterExit)
    exitDuration: Appearance.calcEffectiveDuration(120, Appearance.animationSpeed.enterExit)
    
    // Para posiciones verticales: popup hacia el centro (right para left, left para right)
    // Para posiciones horizontales: popup arriba para bottom, abajo para top
    popupAbove: !isVertical && dockPosition !== "top"
    
    // Para posiciones verticales, usar gravity/edges horizontales (0 = none/vertical)
    popupSide: isVertical ? (dockPosition === "left" ? Edges.Right : Edges.Left) : 0
}
