pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects as GE
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.pill

// Detached "now playing"-style flyout shown to the side of the selected card.
// Carries the selected workspace's identity and a live, interactive list of its
// open windows: click a row to focus, hover to reveal a close (×) control, and
// drag a row onto any rail card to move that window to another workspace.
//
// Chrome: the Ricelin island card (gradient + hairline + sheen, themed through
// PillTheme onto the generated palette) in every style except zzz, which keeps
// its chamfered PanelSurface identity.
PanelSurface {
    id: detail

    // Ricelin island dialect opt-in (owned by the strip); false = the global
    // style's own PanelSurface card.
    property bool islandChrome: false

    property string wsName: ""
    property int wsIndex: 0
    property string focusedTitle: ""
    property string focusedAppId: ""
    property var wsWindows: []
    property bool isActiveWs: false
    property bool showAppIcons: true
    property bool showPreviews: true

    // Shared drag proxy owned by WorkspaceStrip; rows drive it so a window can be
    // dragged onto a rail card. Null disables drag-to-move.
    property Item dragProxy: null

    signal workspaceActivated()
    signal windowActivated(var win)
    signal windowCloseRequested(var win)

    readonly property bool _zzz: Appearance.zzzEverywhere
    readonly property bool _isNiri: CompositorService.isNiri

    // Stable row identity. NiriService reassigns `windows` on every real event
    // (title change — media players retitle constantly —, focus, layout), and
    // each reassignment rebuilds the filtered array this flyout receives. A
    // Repeater bound to that raw array tears down and recreates every row each
    // time, resetting hover state and fill animations mid-pointer — the
    // reported hover flicker. Key the rows by window id instead and let row
    // content rebind reactively; delegates only rebuild when the id sequence
    // actually changes.
    property var _rowKeys: []
    onWsWindowsChanged: {
        const next = (wsWindows ?? []).map((w, i) => _isNiri ? (w?.id ?? -(i + 1)) : i)
        if (next.join(",") !== _rowKeys.join(","))
            _rowKeys = next
    }
    // Accent used by the hold-to-close heat gesture in every dialect.
    readonly property color _heat: _zzz ? Appearance.zzz.accent
        : islandChrome ? PillTheme.vermLit : Appearance.colors.colPrimary

    // Compact, capped window list — scroll when a workspace is busy.
    readonly property int rowHeight: 38
    readonly property int rowSpacing: 4
    readonly property int maxVisibleRows: 6

    elevation: 2
    cardStyle: true
    borderless: islandChrome
    // Aurora stock dialect: frosted wallpaper behind the translucent card
    // (inert in every other style; PanelSurface gates it).
    wallpaperBackdrop: true

    implicitHeight: column.implicitHeight + 32

    IslandPanel {
        anchors.fill: parent
        visible: detail.islandChrome
        z: -1
        glassEnabled: true
        glassScreenX: detail.backdropScreenX
        glassScreenY: detail.backdropScreenY
        glassScreenWidth: detail.backdropScreenWidth
        glassScreenHeight: detail.backdropScreenHeight
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
    }

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        spacing: 10

        // ── Header: focused app icon + workspace identity ──
        Row {
            spacing: 10
            width: parent.width

            IconImage {
                id: appIcon
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 34
                source: detail.showAppIcons && detail.focusedAppId.length > 0
                    ? AppSearch.getIconSource(detail.focusedAppId) : ""
                visible: source.toString().length > 0
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                    - (appIcon.visible ? appIcon.implicitSize + 10 : 0)
                    - (activateWorkspace.visible ? activateWorkspace.implicitWidth + 10 : 0)
                spacing: 1

                Item {
                    width: parent.width
                    height: kicker.implicitHeight

                    // Kanji furniture — the workspace seal, swappable like every
                    // other pill glyph (bar.pill.glyphs.workspaces).
                    Text {
                        id: wsGlyph
                        anchors.left: parent.left
                        anchors.baseline: kicker.baseline
                        visible: detail.islandChrome && PillTheme.showGlyphs
                        text: PillTheme.glyph("workspaces")
                        font.family: PillTheme.fontJp
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        id: kicker
                        anchors.left: wsGlyph.visible ? wsGlyph.right : parent.left
                        anchors.leftMargin: wsGlyph.visible ? 6 : 0
                        anchors.right: winCount.left
                        anchors.rightMargin: 8
                        text: detail.isActiveWs
                            ? Translation.tr("Now active").toUpperCase()
                            : Translation.tr("Workspace").toUpperCase()
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.6
                        color: detail._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
                    }

                    // Right-aligned status in dim tracked caps — window count.
                    StyledText {
                        id: winCount
                        anchors.right: parent.right
                        anchors.baseline: kicker.baseline
                        visible: detail.wsWindows.length > 0
                        text: detail.wsWindows.length === 1
                            ? Translation.tr("1 window").toUpperCase()
                            : Translation.tr("%1 windows").arg(detail.wsWindows.length).toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        font.features: { "tnum": 1 }
                        color: detail._zzz ? Appearance.zzz.onColor : PillTheme.dim
                        opacity: 0.85
                    }
                }

                StyledText {
                    width: parent.width
                    text: detail._zzz
                        ? `${Translation.tr("WS")} / ${detail.wsName}`.toUpperCase()
                        : `${Translation.tr("Workspace")} ${detail.wsName}`
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: detail._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer1
                }
            }

            RippleButton {
                id: activateWorkspace
                anchors.verticalCenter: parent.verticalCenter
                visible: !detail.isActiveWs && detail.wsIndex > 0
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: detail._zzz
                    ? Appearance.zzz.controlRadius : Appearance.rounding.full
                colBackground: detail._zzz
                    ? Appearance.zzz.bg3 : Appearance.colors.colLayer2
                colBackgroundHover: detail._zzz
                    ? Appearance.zzz.bg4 : Appearance.colors.colLayer2Hover
                colRipple: detail._zzz
                    ? Appearance.zzz.accent : Appearance.colors.colPrimary
                onClicked: detail.workspaceActivated()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "desktop_windows"
                    iconSize: 18
                    color: detail._zzz
                        ? Appearance.zzz.accent : Appearance.colors.colPrimary
                }

                StyledToolTip {
                    text: Translation.tr("Switch to workspace %1").arg(detail.wsName)
                }
            }
        }

        // ── Window list (focus / close / drag-to-move) ──
        Flickable {
            id: listFlick
            width: parent.width
            height: Math.min(
                listColumn.implicitHeight,
                detail.maxVisibleRows * detail.rowHeight
                    + (detail.maxVisibleRows - 1) * detail.rowSpacing)
            contentHeight: listColumn.implicitHeight
            contentWidth: width
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height

            ScrollBar.vertical: StyledScrollBar {
                policy: listFlick.contentHeight > listFlick.height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const max = Math.max(0, listFlick.contentHeight - listFlick.height)
                    listFlick.contentY = Math.max(0, Math.min(max,
                        listFlick.contentY - event.angleDelta.y))
                }
            }

            Column {
                id: listColumn
                width: listFlick.width
                spacing: detail.rowSpacing

                // Honest empty state.
                Item {
                    visible: detail.wsWindows.length === 0
                    width: parent.width
                    height: visible ? detail.rowHeight : 0
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "check_box_outline_blank"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                            opacity: 0.7
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Empty workspace")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Repeater {
                    model: detail._rowKeys

                    Item {
                        id: row
                        required property var modelData
                        required property int index

                        // Live lookup by id so title/focus updates flow into the
                        // existing delegate instead of recreating it.
                        readonly property var win: detail._isNiri
                            ? (detail.wsWindows.find(w => (w?.id ?? -1) === row.modelData)
                                ?? detail.wsWindows[row.index] ?? null)
                            : (detail.wsWindows[row.index] ?? null)
                        readonly property int winId: detail._isNiri ? (win?.id ?? 0) : 0
                        readonly property string winAppId: detail._isNiri
                            ? (win?.app_id ?? "")
                            : (win?.appId ?? "")
                        readonly property string winTitle: win?.title
                            || winAppId || Translation.tr("Untitled window")
                        readonly property bool winFocused: detail._isNiri
                            ? (win?.is_focused ?? false)
                            : (win?.activated ?? false)
                        readonly property bool dragging: detail.dragProxy
                            && detail.dragProxy.dragging
                            && (detail.dragProxy.win === win
                                || (detail._isNiri && (detail.dragProxy.win?.id ?? -2) === row.winId))

                        width: listColumn.width
                        height: detail.rowHeight
                        opacity: dragging ? 0.35 : 1
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        Rectangle {
                            id: rowBg
                            anchors.fill: parent
                            radius: detail._zzz ? Appearance.zzz.controlRadius : 9
                            // The × is a hover-enabled MouseArea ON TOP of the row:
                            // it takes hover exclusively, so the row highlight must
                            // also count the button's own hover or the fill blinks
                            // off while crossing it (reported flicker).
                            readonly property bool rowLit: rowHover.hovered
                                || closeArea.containsMouse || closeHeat.holding
                            color: detail._zzz
                                ? (row.winFocused ? Appearance.zzz.bg3
                                    : rowLit ? Appearance.zzz.bg2 : "transparent")
                                : (row.winFocused || rowLit)
                                // The flyout is a PanelSurface at elevation 2, so its
                                // own fill IS colLayer2 — laying colLayer2 back over
                                // itself at any alpha composites to exactly colLayer2
                                // and the state vanished (1.00:1). Only aurora and
                                // angel hid it, because their layer tokens carry alpha
                                // of their own. colLayer2Hover is the state layer for
                                // this surface: colLayer2 lifted toward its ink.
                                ? (detail.islandChrome ? PillTheme.frameBg
                                    : Appearance.colors.colLayer2Hover)
                                : "transparent"
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: PillMotion.fast }
                            }
                            border.width: row.winFocused && !detail._zzz ? 1 : 0
                            border.color: detail.islandChrome
                                ? PillTheme.frameBorder : Appearance.colors.colOutlineVariant
                        }

                        // Hairline divider under every row but the last —
                        // internal structure by 1px hairlines, never outlines.
                        Rectangle {
                            visible: !detail._zzz && row.index < detail.wsWindows.length - 1
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                leftMargin: 6
                                rightMargin: 6
                                bottomMargin: -Math.ceil(detail.rowSpacing / 2)
                            }
                            height: 1
                            color: PillTheme.hairSoft
                        }

                        Row {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 6
                                rightMargin: 6
                            }
                            spacing: 8

                            // Per-window thumbnail (Niri preview) with icon fallback.
                            Item {
                                id: thumb
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42
                                height: 26

                                Rectangle {
                                    anchors.fill: parent
                                    radius: detail._zzz ? 0 : Appearance.rounding.unsharpen
                                    color: detail._zzz ? Appearance.zzz.bg0 : Appearance.colors.colLayer2
                                    visible: detail.showPreviews && preview.ready
                                }

                                Image {
                                    id: preview
                                    anchors.fill: parent
                                    readonly property bool ready: status === Image.Ready && source.toString().length > 0
                                    source: (detail.showPreviews && detail._isNiri && row.winId > 0)
                                        ? WindowPreviewService.getPreviewUrl(row.winId) : ""
                                    asynchronous: true
                                    // Preview URLs carry a capture timestamp, so a new
                                    // frame is a new cache entry: caching is safe and
                                    // makes re-hovering a workspace instant instead of
                                    // re-decoding every screenshot from disk.
                                    cache: true
                                    // Decode at thumb size (2x for hidpi), not at the
                                    // window's full capture resolution — full-size
                                    // decodes were the visible lag when moving hover
                                    // across workspaces.
                                    sourceSize.width: 84
                                    sourceSize.height: 52
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    visible: ready
                                    layer.enabled: ready
                                    layer.effect: GE.OpacityMask {
                                        maskSource: Rectangle {
                                            width: preview.width
                                            height: preview.height
                                            radius: detail._zzz ? 0 : Appearance.rounding.unsharpen
                                        }
                                    }
                                    // Reassign only when the URL actually changes
                                    // (captureComplete fires on every open even
                                    // with no new capture); cache:false would
                                    // otherwise reload an identical frame.
                                    function _apply(): void {
                                        const next = WindowPreviewService.getPreviewUrl(row.winId)
                                        if (next === source.toString()) return
                                        source = next
                                    }
                                    Connections {
                                        target: WindowPreviewService
                                        enabled: detail._isNiri && row.winId > 0
                                        function onPreviewUpdated(id: int): void {
                                            if (id === row.winId) preview._apply()
                                        }
                                        function onCaptureComplete(): void {
                                            if (row.winId > 0) preview._apply()
                                        }
                                    }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 22
                                    source: detail.showAppIcons && row.winAppId.length > 0
                                        ? AppSearch.getIconSource(row.winAppId) : ""
                                    visible: !preview.visible
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 42 - 8
                                    - (closeBtn.visible ? closeBtn.width + 8 : 0)
                                text: row.winTitle
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: row.winFocused ? Font.DemiBold : Font.Normal
                                color: row.winFocused
                                    ? (detail._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer1)
                                    : Appearance.colors.colOnLayer1
                            }
                        }

                        // Close (×) — revealed on hover. Destructive gesture, so it
                        // follows the Ricelin doctrine: hold to commit, release early
                        // and the heat drains. No confirm dialog.
                        Item {
                            id: closeBtn
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                rightMargin: 6
                            }
                            width: 24
                            height: 24
                            visible: (rowHover.hovered || closeArea.containsMouse
                                || closeHeat.holding) && !row.dragging

                            HeatHold {
                                id: closeHeat
                                onConfirmed: detail.windowCloseRequested(row.win)
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: detail._zzz ? Appearance.zzz.controlRadius : width / 2
                                color: closeHeat.holding
                                    ? Qt.alpha(detail._heat, 0.12 + 0.24 * closeHeat.hold)
                                    : closeArea.containsMouse
                                    ? (detail._zzz ? Appearance.zzz.bg4
                                        : ColorUtils.transparentize(Appearance.colors.colLayer3, 0.2))
                                    : "transparent"
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 16
                                color: closeHeat.holding ? detail._heat : Appearance.colors.colOnLayer1
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: closeHeat.press()
                                onReleased: closeHeat.release()
                                onCanceled: closeHeat.cancel()
                            }
                        }

                        // Heat sweep: while the × is held, a flame line sweeps from
                        // the button across the row's bottom edge; full sweep closes.
                        Item {
                            visible: closeHeat.holding
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                rightMargin: 6
                                bottomMargin: 1
                            }
                            height: 2
                            width: (row.width - 12) * closeHeat.hold

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: detail._heat }
                                    GradientStop {
                                        position: 1.0
                                        color: detail.islandChrome ? PillTheme.vermDim : detail._heat
                                    }
                                }
                            }
                            // Lit head at the leading (left) edge — island flame.
                            Rectangle {
                                visible: detail.islandChrome
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 2.5
                                radius: width / 2
                                color: PillTheme.flameCore
                            }
                        }

                        HoverHandler { id: rowHover }

                        // Click to focus; press-drag to move onto a rail card.
                        MouseArea {
                            id: rowDrag
                            anchors.fill: parent
                            anchors.rightMargin: closeBtn.visible ? closeBtn.width + 10 : 0
                            hoverEnabled: false
                            preventStealing: true
                            cursorShape: _dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                            property real _pressX: 0
                            property real _pressY: 0
                            property bool _dragging: false

                            onPressed: mouse => {
                                _pressX = mouse.x
                                _pressY = mouse.y
                                _dragging = false
                                if (detail.dragProxy)
                                    detail.dragProxy.placeAt(this, mouse.x, mouse.y)
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || !detail.dragProxy) return
                                if (!_dragging) {
                                    const dx = Math.abs(mouse.x - _pressX)
                                    const dy = Math.abs(mouse.y - _pressY)
                                    if (dx > 8 || dy > 8) {
                                        _dragging = true
                                        detail.dragProxy.beginDrag(row.win, row.winTitle, row.winAppId)
                                    }
                                }
                                if (_dragging)
                                    detail.dragProxy.moveTo(this, mouse.x, mouse.y)
                            }
                            onReleased: {
                                if (_dragging && detail.dragProxy) {
                                    detail.dragProxy.endDrag()
                                } else if (!_dragging) {
                                    detail.windowActivated(row.win)
                                }
                                _dragging = false
                            }
                            onCanceled: {
                                if (detail.dragProxy) detail.dragProxy.cancelDrag()
                                _dragging = false
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: detail.wsWindows.length > 0
            width: parent.width
            text: Translation.tr("Click to focus, drag to move, hold × to close")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: detail._zzz ? Appearance.zzz.onColor : Appearance.colors.colSubtext
            opacity: 0.72
        }

        // ── Active-state filament: thread track, warm gradient fill and a lit
        // cap at the leading edge (zzz keeps its flat hairline treatment).
        Rectangle {
            width: parent.width
            height: 3
            radius: detail._zzz ? 0 : Appearance.rounding.full
            color: detail._zzz ? Appearance.zzz.hairlineStrong : PillTheme.threadBg

            Item {
                id: filamentFill
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: parent.width * (detail.isActiveWs ? 1 : 0.34)
                Behavior on width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: PillMotion.morph
                        easing.type: PillMotion.easeMorph
                        easing.bezierCurve: PillMotion.morphCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: detail._zzz ? 0 : Appearance.rounding.full
                    visible: !detail.islandChrome
                    color: detail._zzz ? Appearance.zzz.accent : Appearance.colors.colPrimary
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.full
                    visible: detail.islandChrome
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: PillTheme.vermDim }
                        GradientStop { position: 1.0; color: PillTheme.vermLit }
                    }
                }
                // Lit cap on the leading edge — island flame.
                Rectangle {
                    visible: detail.islandChrome
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 2.5
                    radius: width / 2
                    color: PillTheme.flameCore
                }
            }
        }
    }
}
