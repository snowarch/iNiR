pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects as GE
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.pill

// One workspace thumbnail in the rail.
//
// Preview protocol: Niri has no per-toplevel wlr-screencopy, so the reliable
// path is WindowPreviewService — it screenshots each window through Niri's own
// `screenshot-window` IPC and caches the PNG. We display that cached frame,
// refreshed whenever the strip opens, and fall back to the focused app icon.
//
// Style frame is token-driven; zzz uses a chamfered ZzzPlate silhouette.
Item {
    id: card

    required property var workspace
    property bool selected: false
    property bool shown: false
    property bool isRight: true
    // Ricelin island dialect opt-in (owned by the strip); false = each global
    // style's own stock look.
    property bool islandChrome: false
    property bool showPreviews: true
    property bool showAppIcons: true
    // Niri-only: windows for this workspace, pre-bucketed by the parent strip so
    // the card doesn't re-filter the full window list itself. Null falls back to
    // self-filtering (keeps the component usable standalone / on Hyprland).
    property var injectedWindows: null
    // True while a dragged window hovers this card as a move target.
    property bool dropTargeted: false

    signal activated()

    readonly property bool _isNiri: CompositorService.isNiri
    readonly property bool isActiveWs: _isNiri
        ? (workspace?.is_active ?? false)
        : (workspace?.active ?? false)
    readonly property int wsId: workspace?.id ?? 0
    readonly property int wsIndex: _isNiri
        ? (workspace?.idx ?? 0)
        : (workspace?.id ?? 0)
    readonly property string wsName: workspace?.name || String(wsIndex)
    readonly property var wsWindows: _isNiri
        ? (injectedWindows !== null
            ? injectedWindows
            : (NiriService.windows ?? []).filter(w => w.workspace_id === wsId))
        : (CompositorService.isHyprland ? (workspace?.toplevels?.values ?? []) : [])
    readonly property var focusedWindow: wsWindows.find(w => _isNiri ? (w?.is_focused ?? false) : (w?.activated ?? false)) ?? wsWindows[0] ?? null
    readonly property int focusedWindowId: _isNiri ? (focusedWindow?.id ?? 0) : 0
    readonly property string focusedAppId: _isNiri
        ? (focusedWindow?.app_id ?? "")
        : (focusedWindow?.appId ?? "")
    readonly property string focusedTitle: focusedWindow?.title
        || focusedAppId || Translation.tr("Empty workspace")
    // Distinct app identities for the selected-card stack. The strip already
    // owns the workspace window slice, so this is a tiny local projection and
    // does not trigger any extra preview capture or service lookup.
    readonly property var visibleAppIds: {
        if (!showAppIcons) return []
        const ids = []
        const seen = ({})
        for (let i = 0; i < wsWindows.length && ids.length < 3; i++) {
            const win = wsWindows[i]
            const appId = _isNiri ? (win?.app_id ?? "") : (win?.appId ?? "")
            if (appId.length === 0 || seen[appId]) continue
            seen[appId] = true
            ids.push(appId)
        }
        return ids
    }

    // ── Per-style frame tokens ──
    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property real _radius: _zzz ? 0
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    readonly property color _ringColor: dropTargeted
        ? (_zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary)
        : _zzz
        ? ((isActiveWs || selected) ? Appearance.zzz.accent : Appearance.zzz.hairlineStrong)
        : (isActiveWs || selected) ? Appearance.colors.colPrimary
        : islandChrome ? PillTheme.border
        : Appearance.colors.colOutlineVariant

    z: selected ? 10 : 1
    // No sub-pixel scale: a fractional `scale` resamples the whole layered card
    // (preview + icon) every frame and is what made the app icons look blurry.
    // The resting state also dims the preview only (see clipBox): fading the whole
    // card made its plate translucent too, so the wallpaper came through the one
    // surface the thumbnail needs to sit on.
    readonly property real contentDim: selected || isActiveWs ? 1 : 0.82

    StyledRectangularShadow {
        target: clipBox
        visible: card.selected && !card._zzz
            && (Appearance.angelEverywhere
                || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
    }

    Rectangle {
        anchors.fill: parent
        visible: !card._zzz
        radius: card._radius
        // The card only signalled hover through its border and opacity, which reads
        // as nothing under the Material style. Lift the fill with the state layer.
        // One layer above the rail plate (PanelSurface at elevation 0 = colLayer0):
        // at the same layer the two solid surfaces stack and neither reads.
        color: card.selected ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementResize.duration }
        }
    }
    ZzzPlate {
        anchors.fill: parent
        visible: card._zzz
        // Same reason as the Material branch: the rail plate is already bg0.
        fillColor: card.selected ? Appearance.zzz.bg3 : Appearance.zzz.bg2
        chamfer: card.selected ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.5
        chamferBottomRight: card.isRight && !Appearance.zzz.round
        chamferBottomLeft: !card.isRight && !Appearance.zzz.round
    }

    Item {
        id: clipBox
        anchors.fill: parent
        opacity: card.contentDim
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        layer.enabled: card.shown
        layer.effect: GE.OpacityMask {
            maskSource: Item {
                width: clipBox.width
                height: clipBox.height
                visible: false
                Rectangle {
                    anchors.fill: parent
                    visible: !card._zzz
                    radius: card._radius
                    color: "white"
                }
                ZzzPlate {
                    anchors.fill: parent
                    visible: card._zzz
                    fillColor: "white"
                    chamfer: card.selected ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.5
                    chamferBottomRight: card.isRight && !Appearance.zzz.round
                    chamferBottomLeft: !card.isRight && !Appearance.zzz.round
                }
            }
        }

        Image {
            id: preview
            anchors.fill: parent
            property string url: ""
            readonly property bool ready: status === Image.Ready && url.length > 0
            source: card.shown ? url : ""
            asynchronous: true
            cache: true
            // Decode at card size (~2x the largest selected card), never at the
            // window's full capture resolution — keeps hover-selection instant.
            sourceSize.width: 384
            sourceSize.height: 240
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            visible: card.showPreviews && url.length > 0
            opacity: ready ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            function refresh(): void {
                const next = (card.shown && card.showPreviews && card.focusedWindowId > 0)
                    ? WindowPreviewService.getPreviewUrl(card.focusedWindowId)
                    : ""
                // captureComplete() fires on every strip open even when nothing
                // re-captured; skip the reassignment when the URL (incl. its
                // timestamp query) is identical so cache:false doesn't reload.
                if (next === url) return
                url = next
            }
            Component.onCompleted: Qt.callLater(refresh)
            onVisibleChanged: if (card.shown) Qt.callLater(refresh)

            Connections {
                target: card
                function onShownChanged(): void { if (card.shown) Qt.callLater(preview.refresh) }
                function onFocusedWindowIdChanged(): void { Qt.callLater(preview.refresh) }
            }
            Connections {
                target: WindowPreviewService
                function onPreviewUpdated(id: int): void {
                    if (id === card.focusedWindowId) preview.refresh()
                }
                function onCaptureComplete(): void { preview.refresh() }
            }
        }

        // Icon fallback — honest empty state.
        IconImage {
            anchors.centerIn: parent
            implicitSize: Math.round(Math.min(parent.width, parent.height) * 0.42)
            source: card.showAppIcons && card.focusedAppId.length > 0
                ? AppSearch.getIconSource(card.focusedAppId) : ""
            visible: !preview.ready && source.toString().length > 0
            opacity: 0.72
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "space_dashboard"
            iconSize: Math.round(Math.min(parent.width, parent.height) * 0.34)
            color: card._zzz ? Appearance.zzz.onColor : Appearance.colors.colSubtext
            visible: !preview.ready
                && (!card.showAppIcons || card.focusedAppId.length === 0)
            opacity: card.wsWindows.length === 0 ? 0.5 : 0.7
        }

        // Bottom scrim so the number badge stays legible over busy previews.
        Rectangle {
            anchors.fill: parent
            visible: preview.ready
            gradient: Gradient {
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1; color: ColorUtils.transparentize(Appearance.colors.colScrim, 0.5) }
            }
        }

        // Top sheen on the selected card — the lit inner edge every Ricelin
        // surface carries; reads as the card catching light when it grows.
        Rectangle {
            visible: card.islandChrome && card.selected
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 1
                leftMargin: card._radius * 0.6
                rightMargin: card._radius * 0.6
            }
            height: 1
            color: PillTheme.sheen
        }
    }

    // Workspace number badge.
    Rectangle {
        anchors {
            top: parent.top
            left: card.isRight ? parent.left : undefined
            right: card.isRight ? undefined : parent.right
            margins: 6
        }
        width: wsNum.implicitWidth + 12
        height: wsNum.implicitHeight + 5
        radius: card._zzz ? Appearance.zzz.controlRadius
            : card.islandChrome ? PillMotion.rSmall : Appearance.rounding.small
        color: card._zzz
            ? (card.isActiveWs ? Appearance.zzz.sticker
                : card.selected ? Appearance.zzz.bg4 : Appearance.zzz.bg3)
            : card.isActiveWs ? Appearance.colors.colPrimary
            : card.selected
                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.78)
                : ColorUtils.transparentize(Appearance.colors.colLayer3, 0.15)
        // Island chrome: the active workspace burns — lit-top vermilion ramp.
        property Gradient _lit: Gradient {
            GradientStop { position: 0.0; color: PillTheme.vermLit }
            GradientStop { position: 1.0; color: PillTheme.verm }
        }
        gradient: (card.islandChrome && card.isActiveWs) ? _lit : null

        StyledText {
            id: wsNum
            anchors.centerIn: parent
            text: String(card.wsIndex)
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: card._zzz
                ? (card.isActiveWs ? Appearance.zzz.onSticker
                    : card.selected ? Appearance.zzz.accent : Appearance.zzz.onColor)
                : card.isActiveWs ? Appearance.colors.colOnPrimary
                : card.selected ? Appearance.colors.colPrimary
                : Appearance.colors.colOnLayer3
        }
    }

    // App stack on the selected card. This makes the App icons setting honest:
    // it represents the workspace, not only the focused window fallback.
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: card.isRight ? parent.left : undefined
            right: card.isRight ? undefined : parent.right
            margins: 6
        }
        visible: card.selected && card.visibleAppIds.length > 1
        width: appIconRow.implicitWidth + 10
        height: 26
        radius: card._zzz ? Appearance.zzz.controlRadius : Appearance.rounding.full
        color: ColorUtils.transparentize(
            card._zzz ? Appearance.zzz.bg4 : Appearance.colors.colLayer3, 0.08)
        border.width: card._zzz ? Appearance.zzz.hairline : 0
        border.color: card._zzz ? Appearance.zzz.hairlineStrong : "transparent"

        Row {
            id: appIconRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: card.visibleAppIds

                IconImage {
                    required property string modelData
                    implicitSize: 16
                    source: AppSearch.getIconSource(modelData)
                }
            }
        }
    }

    // Window-count chip (only when there's something to count and room to show it).
    Rectangle {
        anchors {
            bottom: parent.bottom
            right: card.isRight ? parent.right : undefined
            left: card.isRight ? undefined : parent.left
            margins: 6
        }
        visible: card.wsWindows.length > 1 && card.selected
        width: countText.implicitWidth + 10
        height: countText.implicitHeight + 4
        radius: card._zzz ? Appearance.zzz.controlRadius : Appearance.rounding.full
        color: ColorUtils.transparentize(card._zzz ? Appearance.zzz.bg4 : Appearance.colors.colLayer3, 0.1)

        StyledText {
            id: countText
            anchors.centerIn: parent
            text: String(card.wsWindows.length)
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
            color: card._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer3
        }
    }

    // Selection / active ring.
    Rectangle {
        anchors.fill: parent
        visible: !card._zzz
        color: card.dropTargeted
            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
            : "transparent"
        radius: card._radius
        border.width: card.dropTargeted ? 2.5
            : card.isActiveWs ? 2 : (card.selected ? 1.5 : 1)
        border.color: card._ringColor
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }
    ZzzPlate {
        anchors.fill: parent
        visible: card._zzz
        fillColor: "transparent"
        strokeColor: card._ringColor
        strokeWidth: card.dropTargeted ? Appearance.zzz.hairlineThick * 1.5
            : card.isActiveWs ? Appearance.zzz.hairlineThick : Appearance.zzz.hairline
        chamfer: card.selected ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.5
        chamferBottomRight: card.isRight && !Appearance.zzz.round
        chamferBottomLeft: !card.isRight && !Appearance.zzz.round
    }

    TapHandler {
        onTapped: card.activated()
    }
}
