pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.frame
import qs.modules.iris.pieces
import qs.modules.iris.bar

ColumnLayout {
    id: page
    required property Item island
    readonly property bool current: page.island.effectivePage === "desktop"
    readonly property bool grouped: String(page.island.options?.blockStyle ?? "plain") === "grouped"
    property real navOffset: 0
    spacing: 14 * IrisStyle.density

    component DesktopBlock: Item {
        id: block
        required property string kind
        property int row: -1
        property real gap: 0
        default property alias content: blockContent.data
        property real contentHeight: 0
        readonly property bool placeholder: page.island.studio && block.contentHeight < 8
        implicitHeight: block.placeholder ? Math.round(40 * IrisStyle.density) : block.contentHeight
        readonly property int index: page.island.desktopBlocks.indexOf(block.kind)
        readonly property bool carried: page.island.arrangeKind === block.kind
        Layout.fillWidth: true
        Layout.row: Math.max(0, block.row)
        visible: block.row >= 0
        z: block.carried ? 10 : 0

        readonly property real shift: {
            if (page.island.arrangeKind.length === 0 || block.carried) return 0
            const from = page.island.desktopBlocks.indexOf(page.island.arrangeKind)
            const to = from + page.island.arrangeSteps
            const span = page.island.arrangeSpan + block.gap
            if (from < block.index && to >= block.index) return -span
            if (from > block.index && to <= block.index) return span
            return 0
        }
        property real offset: block.carried ? page.island.arrangeTravel : block.shift
        Behavior on offset {
            enabled: !gripDrag.active
            NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
        }
        Behavior on y {
            enabled: page.island.studio
            NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
        }
        transform: Translate { y: block.offset }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Math.round(6 * IrisStyle.density)
            radius: IrisStyle.radiusTile
            color: block.carried ? IrisStyle.fillHover : IrisStyle.fillQuiet
            opacity: page.island.studio ? 1 : 0
            visible: opacity > 0
            scale: block.carried ? 1.02 : 1
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        property real inset: page.island.studio ? Math.round(10 * IrisStyle.density) : 0
        Behavior on inset { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        Item {
            id: blockContent
            anchors.fill: parent
            visible: !block.placeholder
            transform: Translate { x: block.inset }
        }
        RowLayout {
            visible: block.placeholder
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studioHandlesWidth
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11 * IrisStyle.density
            Item {
                Layout.preferredWidth: Math.round(40 * IrisStyle.density)
                Layout.preferredHeight: Math.round(28 * IrisStyle.density)
                Glyph { anchors.centerIn: parent; text: page.island.desktopBlockGlyph(block.kind); iconSize: 20 * IrisStyle.density; color: IrisStyle.textTertiary }
            }
            IrisText {
                Layout.fillWidth: true
                text: page.island.desktopBlockLabel(block.kind) + " · " + Translation.tr("nothing to show right now")
                color: IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
        }
        IrisButton {
            id: removeBadge
            readonly property real size: Math.round(20 * IrisStyle.density)
            x: -Math.round(6 * IrisStyle.density) - removeBadge.size / 2 + Math.round(4 * IrisStyle.density)
            y: -Math.round(6 * IrisStyle.density) - removeBadge.size / 2 + Math.round(4 * IrisStyle.density)
            implicitWidth: removeBadge.size
            implicitHeight: removeBadge.size
            buttonRadius: removeBadge.size / 2
            buttonRadiusPressed: removeBadge.size / 2
            colBackground: IrisStyle.danger
            colBackgroundHover: IrisStyle.danger
            visible: page.island.studio && !block.carried
            scale: page.island.studio ? 1 : 0.4
            Behavior on scale { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }
            Accessible.name: Translation.tr("Remove %1").arg(page.island.desktopBlockLabel(block.kind))
            onClicked: page.island.setDesktopBlock(block.kind, false)
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(9 * IrisStyle.density)
                height: Math.max(2, Math.round(2 * IrisStyle.density))
                radius: height / 2
                color: IrisStyle.inkOnDanger
            }
        }
        Item {
            id: grip
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: page.island.studioHandlesWidth
            visible: page.island.studio
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Move %1").arg(page.island.desktopBlockLabel(block.kind))
            Glyph {
                anchors.centerIn: parent
                text: "drag_indicator"
                iconSize: 20 * IrisStyle.density
                color: gripHover.hovered || gripDrag.active ? IrisStyle.text : IrisStyle.textTertiary
            }
            HoverHandler { id: gripHover; cursorShape: gripDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
            DragHandler {
                id: gripDrag
                target: null
                xAxis.enabled: false
                onActiveChanged: {
                    if (active) {
                        page.island.arrangeSpan = block.height
                        page.island.arrangeTravel = 0
                        page.island.arrangeSteps = 0
                        page.island.arrangeKind = block.kind
                        return
                    }
                    const steps = page.island.arrangeSteps
                    page.island.arrangeKind = ""
                    page.island.arrangeSteps = 0
                    if (steps !== 0) page.island.moveDesktopBlock(block.kind, steps)
                }
                onTranslationChanged: {
                    if (!active) return
                    const count = page.island.desktopBlocks.length
                    page.island.arrangeTravel = translation.y
                    page.island.arrangeSteps = Math.max(-block.index, Math.min(count - 1 - block.index,
                        Math.round(translation.y / Math.max(1, block.height + block.gap))))
                }
            }
        }
    }


    readonly property var workspaces: CompositorService.isNiri
        ? (NiriService.allWorkspaces ?? []).filter(ws => ws.output === page.island.targetScreen?.name) : []
    readonly property var activeWorkspace: page.workspaces.find(ws => ws.is_active) ?? null
    readonly property var focusedWindow: {
        const ws = page.activeWorkspace
        if (!ws) return null
        const onWorkspace = (NiriService.windows ?? []).filter(w => w.workspace_id === ws.id)
        const stamp = w => (w.focus_timestamp?.secs ?? 0) * 1e9 + (w.focus_timestamp?.nanos ?? 0)
        return onWorkspace.find(w => w.id === ws.active_window_id)
            ?? onWorkspace.slice().sort((a, b) => stamp(b) - stamp(a))[0] ?? null
    }
    readonly property var customModules: ["left", "center", "right"]
        .reduce((all, slot) => all.concat(page.island.options?.[slot + "Modules"] ?? []), [])
        .filter(id => String(id).startsWith("custom:"))
    readonly property bool weatherReady: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property string bannerSource: String(page.island.options?.desktopBanner ?? "wallpaper") === "wallpaper"
        ? WallpaperListener.wallpaperUrlForScreen(page.island.targetScreen) : ""
    readonly property bool showBanner: page.bannerSource.length > 0
    function bannerPart(key: string, fallback: int): real {
        return Math.max(0, Math.min(100, Number(page.island.options?.[key] ?? fallback))) / 100
    }
    readonly property real bannerFade: page.bannerPart("desktopBannerFade", 100)
    readonly property real bannerTop: page.bannerPart("desktopBannerTop", 100)
    readonly property real bannerVeil: page.bannerPart("desktopBannerVeil", 100)
    readonly property real bannerBlur: page.bannerPart("desktopBannerBlur", 0)
    function blockAvailable(kind: string): bool {
        if (kind === "context") return page.focusedWindow !== null || page.workspaces.length > 1
        if (kind === "modules") return page.customModules.length > 0
        if (kind === "forecast") return page.weatherReady && page.hours.length > 1
        if (kind === "agenda") return page.nextEvent !== null || page.pendingTasks > 0
        return page.island.desktopBlockKinds.includes(kind)
    }
    readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, 6)
    readonly property var nextEvent: {
        void DateTime.clock.date
        return Events.getUpcomingEvents(7)[0] ?? null
    }
    readonly property int pendingTasks: Todo.list.filter(task => !task.done).length
    readonly property var blockRows: page.island.desktopBlocks.filter(kind => page.island.studio || page.blockAvailable(kind))
    function rowOf(kind: string): int { return page.blockRows.indexOf(kind) }

    Item {
        id: hero
        Layout.fillWidth: true
        implicitHeight: page.showBanner
            ? Math.max(Math.round(112 * IrisStyle.density), heroRow.implicitHeight + Math.round(26 * IrisStyle.density))
            : heroRow.implicitHeight

        Item {
            id: heroBleed
            visible: page.showBanner
            readonly property real navBand: page.island.bottomEdge ? 0 : page.navOffset
            readonly property real topBleed: page.island.padding + page.island.chassisItem.topInset + heroBleed.navBand
            // Always layered: toggling layers inside the chassis stops it painting.
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: heroFade
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                blurEnabled: page.bannerBlur > 0
                blur: page.bannerBlur
                blurMax: 48
            }
            opacity: heroImage.ready ? 1 : 0
            x: -page.island.padding
            y: -heroBleed.topBleed
            width: hero.width + page.island.padding * 2
            height: hero.height + heroBleed.topBleed + Math.round(12 * IrisStyle.density)

            Item {
                id: heroContent
                anchors.fill: parent
                // Always layered, like heroBleed: toggling layers inside the chassis stops it painting.
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: sideJoin.active
                    maskSource: sideJoin
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
                IrisWallpaperView {
                    id: heroImage
                    // The wallpaper as this screen shows it, its band taken from the upper third: heads and skies sit
                    // there, where a centred band of a portrait shows the subject's knees.
                    readonly property real screenAspect: (page.island.targetScreen?.height ?? 1080) / Math.max(1, page.island.targetScreen?.width ?? 1920)
                    width: parent.width
                    height: Math.max(parent.height, Math.round(parent.width * heroImage.screenAspect))
                    y: -Math.round((heroImage.height - parent.height) * 0.3)
                    active: page.showBanner
                    screen: page.island.targetScreen
                    live: page.current && page.island.visualExpanded
                    asynchronous: page.island.heroPreloadItem.status !== Image.Ready
                    decodeSize: Qt.size(page.island.heroDecodeWidth, 0)
                }
                IrisHeaderScrim {
                    id: heroScrim
                    anchors.fill: parent
                    hangs: (page.island.notch && !page.island.bottomEdge) || heroBleed.navBand > 0
                    solidTop: (page.island.notch && !page.island.bottomEdge ? page.island.chassisItem.topInset : 0)
                        + (heroBleed.navBand > 0 ? page.island.padding + heroBleed.navBand * 0.5 : 0)
                    navBand: heroBleed.navBand
                    topJoin: page.island.notch && page.island.edge === "top"
                    // Measured from the chassis, not the header: while the Island opens the page rides above the body's
                    // top, and a join fixed in the header's coordinates slid off the screen, letting the image touch the band.
                    joinDepth: page.island.chassisItem.topInset + page.island.fillet + 4 * IrisStyle.density - heroScrim.chassisTop
                    readonly property real chassisTop: {
                        void (page.island.chassisItem.bodyHeight + page.island.chassisItem.height + heroBleed.height + heroBleed.y)
                        return heroBleed.mapToItem(page.island.chassisItem, 0, 0).y
                    }
                    meltTop: page.bannerTop
                    meltFade: page.bannerFade
                    meltVeil: page.bannerVeil
                }
            }
        }

        Item {
            id: sideJoin
            readonly property string edge: page.island.notch ? String(page.island.edge) : ""
            readonly property bool active: sideJoin.edge === "left" || sideJoin.edge === "right"
            readonly property real depth: IrisFrame.band + page.island.fillet + 4 * IrisStyle.density
            readonly property real edgeX: {
                void (heroBleed.width + heroBleed.x + page.island.chassisItem.width + page.island.chassisItem.x)
                const window = heroBleed.Window.window
                if (!window) return 0
                return heroBleed.mapFromItem(null, sideJoin.edge === "right" ? window.width : 0, 0).x
            }
            readonly property real solid: Math.max(0, Math.min(1, (sideJoin.edge === "right"
                ? sideJoin.edgeX - sideJoin.depth : sideJoin.edgeX + sideJoin.depth) / Math.max(1, width)))
            readonly property real ramp: Math.max(0, Math.min(1, (sideJoin.edge === "right"
                ? sideJoin.edgeX - sideJoin.depth / 0.45 : sideJoin.edgeX + sideJoin.depth / 0.45) / Math.max(1, width)))
            x: heroBleed.x
            y: heroBleed.y
            width: heroBleed.width
            height: heroBleed.height
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: sideJoin.edge === "right" ? "white" : "transparent" }
                    GradientStop { position: Math.min(sideJoin.solid, sideJoin.ramp); color: sideJoin.edge === "right" ? "white" : "transparent" }
                    GradientStop { position: Math.max(sideJoin.solid, sideJoin.ramp); color: sideJoin.edge === "right" ? "transparent" : "white" }
                    GradientStop { position: 1; color: sideJoin.edge === "right" ? "transparent" : "white" }
                }
            }
        }

        IrisHeaderFade {
            id: heroFade
            scrim: heroScrim
            x: heroBleed.x
            y: heroBleed.y
            width: heroBleed.width
            height: heroBleed.height
        }

        IrisControlPlate {
            id: heroTools
            anchors.right: parent.right
            anchors.rightMargin: -heroTools.inset
            anchors.top: parent.top
            anchors.topMargin: -Math.round(6 * IrisStyle.density) - heroTools.inset
            material: page.island.pagePlate
            controlHeight: Math.round(32 * IrisStyle.density)

            RowLayout {
                spacing: heroTools.framed ? Math.round(2 * IrisStyle.density) : Math.round(6 * IrisStyle.density)

                GlyphButton {
                    glyph: page.island.studio ? "check" : "edit"
                    glyphSize: 17 * IrisStyle.density
                    glyphColor: page.showBanner ? IrisStyle.onMedia : IrisStyle.text
                    implicitWidth: Math.round(32 * IrisStyle.density)
                    buttonRadius: heroTools.framed ? heroTools.controlRadius : height / 2
                    buttonRadiusPressed: heroTools.framed ? heroTools.controlRadius : height / 2
                    quiet: heroTools.framed
                    colBackground: heroTools.framed ? "transparent" : page.showBanner ? IrisStyle.veil : IrisStyle.fillQuiet
                    colBackgroundHover: heroTools.framed ? IrisStyle.fillHover : page.showBanner ? IrisStyle.veilStrong : IrisStyle.fillHover
                    Accessible.name: page.island.studio ? Translation.tr("Done") : Translation.tr("Arrange this page")
                    onClicked: {
                        page.island.pinned = true
                        GlobalStates.irisArrange = !page.island.studio
                    }
                }
                GlyphButton {
                    id: wallpaperButton
                    visible: page.showBanner
                    glyph: "wallpaper"
                    glyphSize: 17 * IrisStyle.density
                    glyphColor: IrisStyle.onMedia
                    implicitWidth: Math.round(32 * IrisStyle.density)
                    buttonRadius: heroTools.framed ? heroTools.controlRadius : height / 2
                    buttonRadiusPressed: heroTools.framed ? heroTools.controlRadius : height / 2
                    quiet: heroTools.framed
                    colBackground: heroTools.framed ? "transparent" : IrisStyle.veil
                    colBackgroundHover: heroTools.framed ? IrisStyle.fillHover : IrisStyle.veilStrong
                    Accessible.name: Translation.tr("Change wallpaper")
                    onClicked: {
                        GlobalStates.wallpaperSelectorTargetMonitor = page.island.targetScreen?.name ?? ""
                        GlobalStates.wallpaperSelectorOpen = true
                    }
                }
            }
        }

        RowLayout {
            id: heroRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 12 * IrisStyle.density
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                spacing: -2 * IrisStyle.density
                IrisText {
                    textFormat: Text.StyledText
                    text: "<font color='" + (page.showBanner ? IrisStyle.textStrong : IrisStyle.secondaryAccent) + "'><b>"
                        + Translation.locale.toString(DateTime.clock.date, "dddd") + "</b></font> "
                        + Translation.locale.toString(DateTime.clock.date, "d MMMM")
                    color: (page.showBanner ? IrisStyle.textStrong : IrisStyle.textSecondary)
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.Medium)
                }
                IrisClock {
                    id: heroClock
                    pixelSize: 46 * IrisStyle.typeScale
                    opacity: page.island.clockFlightItem.hides(heroClock) ? 0 : 1
                    Component.onCompleted: page.island.heroClock = heroClock
                }
            }
            ColumnLayout {
                visible: page.weatherReady
                Layout.alignment: Qt.AlignBottom
                spacing: 0
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6 * IrisStyle.density
                    Glyph {
                        text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                        iconSize: 22 * IrisStyle.density
                    }
                    Metric {
                        readonly property string raw: String(Weather.data?.temp ?? "")
                        value: raw.replace(/°?[CF]$/, "")
                        unit: raw.length > value.length ? raw.slice(value.length) : ""
                        pixelSize: 26 * IrisStyle.typeScale
                        weight: Font.DemiBold
                    }
                }
                IrisText {
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: 150 * IrisStyle.density
                    text: String(Weather.data?.description ?? "")
                    color: (page.showBanner ? IrisStyle.textStrong : IrisStyle.textSecondary)
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 1
        columnSpacing: 0
        rowSpacing: page.spacing
        visible: page.blockRows.length > 0 || page.island.studio

    DesktopBlock {
        kind: "profile"
        row: page.rowOf("profile")
        gap: page.spacing
        contentHeight: profileBlock.implicitHeight
        RowLayout {
            id: profileBlock
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studio ? page.island.studioHandlesWidth : 0
            enabled: !page.island.studio
            spacing: 11 * IrisStyle.density

            Item {
                id: avatar
                Layout.preferredWidth: Math.round(40 * IrisStyle.density)
                Layout.preferredHeight: Layout.preferredWidth
                property int sourceIndex: 0
                readonly property string primarySource: Directories.userAvatarSourcePrimary
                onPrimarySourceChanged: avatar.sourceIndex = 0
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Change profile picture")

                HoverHandler { id: avatarHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: page.island.chooseAvatar() }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: IrisStyle.fill
                    scale: avatarHover.hovered ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

                    IrisImage {
                        id: avatarImage
                        anchors.fill: parent
                        source: Directories.avatarSourceAt(avatar.sourceIndex)
                        onStatusChanged: {
                            if (status === Image.Error && avatar.sourceIndex + 1 < Directories.userAvatarPaths.length)
                                Qt.callLater(() => avatar.sourceIndex++)
                        }
                    }
                    IrisText {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
                        font.pixelSize: IrisStyle.typeTitle
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: (avatarHover.hovered ? IrisStyle.veil : ColorUtils.applyAlpha(IrisStyle.bodySurface, 0))
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        Glyph {
                            anchors.centerIn: parent
                            text: "edit"
                            iconSize: 17 * IrisStyle.density
                            color: IrisStyle.onMedia
                            opacity: avatarHover.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: SystemInfo.displayName || SystemInfo.username || "user"
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    readonly property string distro: String(SystemInfo.distroId ?? "").trim()
                    text: (SystemInfo.username || "user")
                        + (distro.length > 0 && distro !== "unknown" ? "@" + distro : "")
                        + " · " + Translation.tr("Up %1").arg(DateTime.uptime)
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
            }

            GlyphButton {
                glyph: "lock"
                glyphSize: 18 * IrisStyle.density
                implicitWidth: Math.round(34 * IrisStyle.density)
                colBackground: IrisStyle.fillQuiet
                colBackgroundHover: IrisStyle.fillHover
                Accessible.name: Translation.tr("Lock")
                onClicked: {
                    page.island.expanded = false
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])
                }
            }
            GlyphButton {
                glyph: "power_settings_new"
                glyphSize: 18 * IrisStyle.density
                implicitWidth: Math.round(34 * IrisStyle.density)
                colBackground: IrisStyle.fillQuiet
                colBackgroundHover: IrisStyle.tintFill(IrisStyle.danger)
                Accessible.name: Translation.tr("Session")
                onClicked: { page.island.expanded = false; GlobalStates.sessionOpen = true }
            }
        }
    }

    DesktopBlock {
        kind: "context"
        row: page.rowOf("context")
        gap: page.spacing
        contentHeight: contextRow.implicitHeight
        RowLayout {
            id: contextRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studio ? page.island.studioHandlesWidth : 0
            enabled: !page.island.studio
            visible: page.focusedWindow !== null || page.workspaces.length > 1
            spacing: 11 * IrisStyle.density

            readonly property string workspaceName: page.activeWorkspace
                ? (String(page.activeWorkspace.name ?? "").length > 0
                    ? page.activeWorkspace.name
                    : Translation.tr("Workspace %1").arg(page.activeWorkspace.idx))
                : ""
            readonly property var entry: AppSearch.lookupDesktopEntry(page.focusedWindow?.app_id ?? "")

            Item {
                Layout.preferredWidth: Math.round(40 * IrisStyle.density)
                Layout.preferredHeight: Math.round(30 * IrisStyle.density)
                Glyph {
                    visible: page.focusedWindow === null
                    anchors.centerIn: parent
                    text: "desktop_windows"
                    iconSize: 22 * IrisStyle.density
                    color: IrisStyle.textTertiary
                }
                SmartAppIcon {
                    visible: page.focusedWindow !== null
                    anchors.centerIn: parent
                    icon: IrisPieces.appIcon(page.focusedWindow?.app_id ?? "")
                    fallback: "application-x-executable"
                    iconSize: Math.round(28 * IrisStyle.density)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: page.focusedWindow ? String(page.focusedWindow.title ?? "") : contextRow.workspaceName
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    readonly property string app: contextRow.entry?.name ?? String(page.focusedWindow?.app_id ?? "")
                    text: page.focusedWindow
                        ? app + (contextRow.workspaceName.length > 0 ? " · " + contextRow.workspaceName : "")
                        : Translation.tr("No windows")
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
            }
            Row {
                visible: page.workspaces.length > 1
                spacing: 2 * IrisStyle.density
                Repeater {
                    model: page.workspaces
                    MouseArea {
                        id: dot
                        required property var modelData
                        readonly property bool active: dot.modelData.is_active
                        readonly property bool occupied: (NiriService.windows ?? []).some(w => w.workspace_id === dot.modelData.id)
                        width: indicator.width + 6 * IrisStyle.density
                        height: 20 * IrisStyle.density
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Workspace %1").arg(dot.modelData.idx)
                        onClicked: NiriService.switchToWorkspaceById(dot.modelData.id)
                        Rectangle {
                            id: indicator
                            anchors.centerIn: parent
                            width: dot.active ? 20 * IrisStyle.density : 7 * IrisStyle.density
                            height: 7 * IrisStyle.density
                            radius: height / 2
                            color: dot.active ? IrisStyle.accent
                                : (dot.containsMouse ? IrisStyle.textStrong : dot.occupied ? IrisStyle.textTertiary : IrisStyle.fillHover)
                            Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
            }
        }
    }

    DesktopBlock {
        kind: "forecast"
        row: page.rowOf("forecast")
        gap: page.spacing
        contentHeight: forecast.implicitHeight
        Rectangle {
            id: forecast
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studio ? page.island.studioHandlesWidth : 0
            enabled: !page.island.studio
            implicitHeight: Math.round((page.grouped ? 74 : 58) * IrisStyle.density)
            radius: IrisStyle.radiusTile
            color: page.grouped ? IrisStyle.fillQuiet : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: page.grouped ? Math.round(8 * IrisStyle.density) : 0
                anchors.rightMargin: page.grouped ? Math.round(8 * IrisStyle.density) : 0
                spacing: 0
                IrisText {
                    visible: page.hours.length === 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("No forecast yet")
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeMeta
                }
                Repeater {
                    model: page.hours
                    ColumnLayout {
                        id: hour
                        required property var modelData
                        required property int index
                        readonly property string glyph: Icons.getWeatherIcon(hour.modelData.code, hour.modelData.isNight) ?? "cloud"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.maximumWidth: Number.POSITIVE_INFINITY
                        spacing: Math.round(3 * IrisStyle.density)
                        Accessible.name: hour.modelData.label + ", " + hour.modelData.temp
                        IrisText {
                            Layout.alignment: Qt.AlignHCenter
                            text: hour.index === 0 ? Translation.tr("Now") : String(hour.modelData.label).slice(0, 2)
                            color: hour.index === 0 ? IrisStyle.text : IrisStyle.textTertiary
                            font.pixelSize: IrisStyle.typeFootnote
                            font.weight: hour.index === 0 ? Font.DemiBold : Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        Glyph {
                            Layout.alignment: Qt.AlignHCenter
                            text: hour.glyph
                            iconSize: 19 * IrisStyle.density
                            color: IrisStyle.skyLight(hour.glyph)
                        }
                        IrisText {
                            Layout.alignment: Qt.AlignHCenter
                            text: String(hour.modelData.temp)
                            font.pixelSize: IrisStyle.typeLabel
                            font.weight: IrisStyle.weight(Font.DemiBold)
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }

    DesktopBlock {
        kind: "agenda"
        row: page.rowOf("agenda")
        gap: page.spacing
        contentHeight: agenda.implicitHeight
        RowLayout {
            id: agenda
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studio ? page.island.studioHandlesWidth : 0
            enabled: !page.island.studio
            spacing: 11 * IrisStyle.density

            readonly property var event: page.nextEvent
            readonly property date when: agenda.event ? new Date(agenda.event.dateTime) : DateTime.clock.date
            readonly property string whenText: {
                if (!agenda.event) return ""
                const now = DateTime.clock.date
                const minutes = Math.round((agenda.when.getTime() - now.getTime()) / 60000)
                const time = Qt.locale().toString(agenda.when, Qt.locale().timeFormat(Locale.ShortFormat))
                if (minutes < 1) return Translation.tr("Now")
                if (minutes < 60) return Translation.tr("In %1 min").arg(minutes)
                const today = new Date(now); today.setHours(0, 0, 0, 0)
                const day = new Date(agenda.when); day.setHours(0, 0, 0, 0)
                const days = Math.round((day.getTime() - today.getTime()) / 86400000)
                if (days === 0) return Translation.tr("Today · %1").arg(time)
                if (days === 1) return Translation.tr("Tomorrow · %1").arg(time)
                return Translation.locale.toString(agenda.when, "dddd") + " · " + time
            }

            Rectangle {
                Layout.preferredWidth: Math.round(40 * IrisStyle.density)
                Layout.preferredHeight: Layout.preferredWidth
                radius: IrisStyle.radiusRow
                color: IrisStyle.fillQuiet
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: -Math.round(3 * IrisStyle.density)
                    IrisText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.locale.toString(agenda.when, "ddd").toUpperCase()
                        color: IrisStyle.danger
                        font.pixelSize: 8.5 * IrisStyle.typeScale
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    IrisText {
                        Layout.alignment: Qt.AlignHCenter
                        text: agenda.when.getDate()
                        font.pixelSize: IrisStyle.typeTitle
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        font.features: { "tnum": 1 }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: agenda.event ? String(agenda.event.title || Translation.tr("Event"))
                        : Translation.tr("Nothing scheduled")
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    text: agenda.event ? agenda.whenText : Translation.tr("This week is clear")
                    color: IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
            }
            IrisButton {
                id: tasksButton
                visible: page.pendingTasks > 0
                implicitHeight: Math.round(30 * IrisStyle.density)
                implicitWidth: tasksRow.implicitWidth + Math.round(20 * IrisStyle.density)
                buttonRadius: height / 2
                buttonRadiusPressed: height / 2
                colBackground: IrisStyle.fillQuiet
                colBackgroundHover: IrisStyle.fillHover
                Accessible.name: Translation.tr("%1 open tasks").arg(page.pendingTasks)
                onClicked: { page.island.expanded = false; GlobalStates.sidebarRightOpen = true }
                Row {
                    id: tasksRow
                    anchors.centerIn: parent
                    spacing: Math.round(5 * IrisStyle.density)
                    Glyph { anchors.verticalCenter: parent.verticalCenter; text: "checklist"; iconSize: 16 * IrisStyle.density }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.pendingTasks
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        font.features: { "tnum": 1 }
                    }
                }
            }
            GlyphButton {
                glyph: "chevron_right"
                glyphSize: 18 * IrisStyle.density
                implicitWidth: Math.round(30 * IrisStyle.density)
                colBackground: IrisStyle.fillQuiet
                colBackgroundHover: IrisStyle.fillHover
                Accessible.name: Translation.tr("Open Today")
                onClicked: { page.island.expanded = false; GlobalStates.sidebarRightOpen = true }
            }
        }
    }

    DesktopBlock {
        kind: "vitals"
        row: page.rowOf("vitals")
        gap: page.spacing
        contentHeight: vitals.implicitHeight
        Rectangle {
            id: vitals
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studio ? page.island.studioHandlesWidth : 0
            enabled: !page.island.studio
            implicitHeight: Math.round((page.grouped ? 44 : 34) * IrisStyle.density)
            radius: IrisStyle.radiusTile
            color: page.grouped ? IrisStyle.fillQuiet : "transparent"
            readonly property bool polling: page.current && page.island.visualExpanded
            property bool holdingSensors: false
            onPollingChanged: {
                if (polling && !holdingSensors) { ResourceUsage.keepAlive(); holdingSensors = true }
                else if (!polling && holdingSensors) { ResourceUsage.releaseKeepAlive(); holdingSensors = false }
            }
            Component.onDestruction: if (holdingSensors) ResourceUsage.releaseKeepAlive()

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: page.grouped ? Math.round(10 * IrisStyle.density) : 0
                anchors.rightMargin: page.grouped ? Math.round(10 * IrisStyle.density) : 0
                spacing: 6 * IrisStyle.density
                Repeater {
                    model: [
                        { label: Translation.tr("CPU"), glyph: "memory", level: ResourceUsage.cpuUsage, value: Math.round(ResourceUsage.cpuUsage * 100), unit: "%", warn: 0.85 },
                        { label: Translation.tr("Memory"), glyph: "memory_alt", level: ResourceUsage.memoryUsedPercentage, value: Math.round(ResourceUsage.memoryUsedPercentage * 100), unit: "%", warn: 0.85 },
                        { label: Translation.tr("Heat"), glyph: "device_thermostat", level: ResourceUsage.tempPercentage, value: ResourceUsage.maxTemp, unit: "°", warn: ResourceUsage.tempWarningThreshold / 100 },
                        { label: Translation.tr("Disk"), glyph: "hard_drive", level: ResourceUsage.diskUsedPercentage, value: Math.round(ResourceUsage.diskUsedPercentage * 100), unit: "%", warn: 0.9 }
                    ]
                    RowLayout {
                        id: vital
                        required property var modelData
                        readonly property real level: Math.max(0, Math.min(1, Number(vital.modelData.level) || 0))
                        readonly property color tint: vital.level >= vital.modelData.warn ? IrisStyle.danger : IrisStyle.accent
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6 * IrisStyle.density
                        Accessible.name: vital.modelData.label + ", " + vital.modelData.value + vital.modelData.unit
                        Item { Layout.fillWidth: true }
                        Item {
                            Layout.preferredWidth: Math.round(26 * IrisStyle.density)
                            Layout.preferredHeight: Layout.preferredWidth
                            ProgressRing {
                                anchors.fill: parent
                                stroke: Math.max(2, 2.2 * IrisStyle.density)
                                tint: vital.tint
                                progress: vital.level
                                Behavior on progress { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                            }
                            Glyph {
                                anchors.centerIn: parent
                                text: vital.modelData.glyph
                                iconSize: 12 * IrisStyle.density
                                color: vital.tint
                            }
                        }
                        ColumnLayout {
                            id: vitalText
                            Layout.fillWidth: true
                            Layout.maximumWidth: vitalText.implicitWidth
                            spacing: -2 * IrisStyle.density
                            IrisText {
                                Layout.fillWidth: true
                                text: vital.modelData.label
                                color: IrisStyle.muted
                                font.pixelSize: IrisStyle.typeCaption
                                font.weight: IrisStyle.weight(Font.Medium)
                                elide: Text.ElideRight
                            }
                            Metric {
                                value: vital.modelData.value
                                unit: vital.modelData.unit
                                pixelSize: IrisStyle.typeLabel
                                weight: Font.Bold
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    DesktopBlock {
        kind: "modules"
        row: page.rowOf("modules")
        gap: page.spacing
        contentHeight: modulesBlock.implicitHeight
        Flow {
            id: modulesBlock
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: page.island.studio ? page.island.studioHandlesWidth : 0
            enabled: !page.island.studio
            visible: page.customModules.length > 0
            spacing: 6 * IrisStyle.density
            Repeater {
                model: page.customModules
                IrisCustomModule {
                    required property string modelData
                    widgetId: modelData.slice("custom:".length)
                    targetScreen: page.island.targetScreen
                    slot: "island.desktop"
                }
            }
        }
    }

        Flow {
            Layout.fillWidth: true
            Layout.row: page.blockRows.length
            visible: page.island.studio
            spacing: 6 * IrisStyle.density
            Repeater {
                model: page.island.desktopBlockKinds.filter(kind => !page.island.desktopBlocks.includes(kind))
                IrisChip {
                    required property string modelData
                    glyph: page.island.desktopBlockGlyph(modelData)
                    label: page.island.desktopBlockLabel(modelData)
                    onClicked: page.island.setDesktopBlock(modelData, true)
                }
            }
            IrisChip {
                glyph: "check"
                label: Translation.tr("Done")
                emphasized: true
                onClicked: GlobalStates.irisArrange = false
            }
        }
    }
}
