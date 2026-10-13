pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.field as Field

Loader {
    id: root

    property var model: []
    // What the open menu shows, fixed when it opens: a live model rebuilt the rows while the popup was
    // mapped, the popup resized, and its input landed rows away from what was drawn.
    property var shown: []
    property Item anchorItem: parent
    // "" opens at the point, up/down/left/right beside the anchor, "over" lays entry `overIndex` on the anchor (a pop-up
    // button: what is chosen opens under the pointer, its text where the button's text was, `overTextX` into the anchor).
    property string opensToward: ""
    property int overIndex: -1
    property real overTextX: 0
    // Where the opening click landed, in the anchor's coordinates. A Niri window cannot know where it sits on screen, so
    // a menu anchored in one places itself from the pointer: the screen position under it, less this point.
    property point pointerAt: Qt.point(-1, -1)
    // A menu where no entry carries a mark gives its text the whole row instead of an empty column.
    readonly property bool marked: (root.shown ?? []).some(entry => String(entry?.iconName ?? "").length > 0
        || String(entry?.image ?? "").length > 0 || String(entry?.tint ?? "").length > 0)
    readonly property real d: IrisStyle.density
    readonly property bool compact: IrisStyle.menuCompact
    readonly property real rowHeight: Math.round((root.compact ? 28 : 34) * root.d)
    readonly property int textSize: root.compact ? IrisStyle.typeLabel : IrisStyle.typeBody
    readonly property real glyphSize: Math.round((root.compact ? 15 : 17) * root.d)
    readonly property real pad: Math.round((root.compact ? 4 : 6) * root.d)

    function requestOpen(): void {
        const other = GlobalStates.activeContextMenu
        if (other && other !== root && !openAfterOther.waited) {
            other.active = false
            openAfterOther.waited = true
            openAfterOther.restart()
            return
        }
        openAfterOther.waited = false
        closeFallback.stop()
        // The rows exist before the window does, so its first frame (and the entry it lights) is the right one.
        root.shown = root.model
        // The click that asks again has usually already ended this popup's grab; moving a popup the
        // compositor dismissed left a ghost that opened anywhere and could not be closed.
        if (root.active) {
            root.active = false
            openAgain.restart()
            return
        }
        root.active = true
    }
    // Wayland parents a new grabbing popup to the topmost one: open only once the other is gone.
    Timer { id: openAfterOther; property bool waited: false; interval: 50; onTriggered: root.requestOpen() }
    Timer { id: openAgain; interval: 80; onTriggered: root.active = true }
    function close(): void {
        if (root.item) root.item.dismiss()
        else root.active = false
    }
    Timer {
        id: closeFallback
        interval: IrisStyle.duration(IrisStyle.recedeDuration) + 250
        onTriggered: root.active = false
    }

    // A grabbing popup left open under the region selector steals its input and resizes it.
    Connections {
        target: GlobalStates
        function onRegionSelectorOpenChanged(): void { if (GlobalStates.regionSelectorOpen) root.active = false }
    }

    active: false
    onActiveChanged: {
        if (active) root.shown = root.model
        if (active) {
            GlobalStates.activeContextMenu = root
            GlobalStates.activeContextMenuCount++
        } else {
            if (GlobalStates.activeContextMenu === root) GlobalStates.activeContextMenu = null
            GlobalStates.activeContextMenuCount--
        }
    }

    // A full-screen Overlay layer, not an xdg-popup: the menu is drawn where the surface already is,
    // so input can never land elsewhere, and the rest of the surface is the outside click.
    sourceComponent: PanelWindow {
        id: popup
        readonly property var anchorWindow: root.anchorItem?.QsWindow.window ?? null
        screen: popup.anchorWindow?.screen ?? null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:iris-menu"
        Field.IrisBlurRegion {
            id: placeBlur
            window: popup
            shapes: menu.blurShapes
            windowWidth: popup.width
            windowHeight: popup.height
        }
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real edge: Math.round(8 * root.d)
        readonly property real gap: Math.round(6 * root.d)

        // Where a layer window sits on its output follows from its anchors, size and margins; a Niri window's from the
        // pointer (`pointerAt`), once it is over this layer.
        readonly property bool anchorPlaced: popup.anchorWindow?.anchors !== undefined
        property point pointerOrigin: Qt.point(NaN, NaN)
        readonly property bool placed: popup.anchorPlaced || Number.isFinite(popup.pointerOrigin.x) || pointerWait.expired
        Timer { id: pointerWait; property bool expired: false; interval: 250; running: !popup.anchorPlaced; onTriggered: expired = true }
        function takePointer(px: real, py: real): void {
            if (popup.anchorPlaced || Number.isFinite(popup.pointerOrigin.x) || root.pointerAt.x < 0 || !root.anchorItem) return
            const at = root.anchorItem.mapToItem(null, root.pointerAt.x, root.pointerAt.y)
            popup.pointerOrigin = Qt.point(Math.round(px - at.x), Math.round(py - at.y))
        }
        function originOf(w: var): point {
            if (!w || !w.screen) return Qt.point(0, 0)
            if (w === popup.anchorWindow && Number.isFinite(popup.pointerOrigin.x)) return popup.pointerOrigin
            const a = w.anchors ?? ({})
            const m = w.margins ?? ({})
            const x = a.left ? Number(m.left ?? 0) : a.right ? w.screen.width - w.width - Number(m.right ?? 0) : (w.screen.width - w.width) / 2
            const y = a.top ? Number(m.top ?? 0) : a.bottom ? w.screen.height - w.height - Number(m.bottom ?? 0) : (w.screen.height - w.height) / 2
            return Qt.point(x, y)
        }
        readonly property rect target: {
            void (popup.width + popup.height)
            const item = root.anchorItem
            if (!item) return Qt.rect(popup.width / 2, popup.height / 2, 1, 1)
            const o = popup.originOf(popup.anchorWindow)
            const p = item.mapToItem(null, 0, 0)
            return Qt.rect(o.x + p.x, o.y + p.y, root.opensToward.length > 0 ? item.width : 1, root.opensToward.length > 0 ? item.height : 1)
        }
        function clampX(x: real): real { return Math.round(Math.max(popup.edge, Math.min(popup.width - menu.width - popup.edge, x))) }
        function clampY(y: real): real { return Math.round(Math.max(popup.edge, Math.min(popup.height - menu.height - popup.edge, y))) }
        readonly property bool flipX: root.opensToward.length === 0 && popup.target.x + menu.width + popup.edge > popup.width
        readonly property bool flipY: root.opensToward.length === 0 && popup.target.y + menu.height + popup.edge > popup.height

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: !popup.anchorPlaced
            // The layer maps under a pointer that has not moved: its entry already says where it is.
            onEntered: popup.takePointer(mouseX, mouseY)
            onPositionChanged: mouse => popup.takePointer(mouse.x, mouse.y)
            onPressed: root.close()
        }
        // The entry laid over the anchor, measured from the menu's top: rows, separators and headers above it.
        readonly property real overTop: {
            let top = root.pad
            const list = root.shown ?? []
            for (let i = 0; i < Math.min(root.overIndex, list.length); i++) {
                const type = list[i]?.type
                top += (type === "separator" ? Math.round((root.compact ? 9 : 13) * root.d)
                    : type === "header" ? Math.round((root.compact ? 34 : 42) * root.d) : root.rowHeight) + column.spacing
            }
            return top
        }
        readonly property real textInset: Math.round((root.compact ? 8 : 10) * root.d)
            + (root.marked ? Math.round((root.compact ? 18 : 20) * root.d) + Math.round((root.compact ? 8 : 10) * root.d) : 0)

        readonly property var stops: {
            const list = []
            ;(root.shown ?? []).forEach((entry, index) => {
                if (entry?.type !== "separator" && entry?.type !== "place" && entry?.type !== "header" && entry?.enabled !== false) list.push({ entry: index, tile: -1 })
                if (entry?.type === "hero" && entry?.secondary) list.push({ entry: index, tile: 0 })
            })
            return list
        }
        property int stop: -1
        // The rows that a digit takes, in order: 1 to 9 choose them from the keyboard.
        readonly property var rowStops: popup.stops.filter(s => s.tile < 0 && root.shown[s.entry]?.type !== "hero")
        function codeOf(entry: int): int {
            const i = popup.rowStops.findIndex(s => s.entry === entry)
            return i >= 0 && i < 9 ? i + 1 : 0
        }
        function isStop(entry: int, tile: int): bool {
            const s = popup.stops[popup.stop]
            return s !== undefined && s.entry === entry && s.tile === tile
        }
        function focusStop(entry: int, tile: int): void {
            popup.stop = popup.stops.findIndex(s => s.entry === entry && s.tile === tile)
        }
        function run(action): void {
            popup.dismiss()
            if (action) action()
        }
        function choose(entry): void {
            if (entry?.keepOpen) {
                if (entry.action) entry.action()
                Qt.callLater(() => { root.shown = root.model })
            } else popup.run(entry?.action)
        }
        function runStop(): void {
            const s = popup.stops[popup.stop]
            if (!s) return
            const entry = root.shown[s.entry]
            if (s.tile >= 0) popup.run(entry.type === "hero" ? entry.secondary?.action : entry.items[s.tile].action)
            else popup.choose(entry)
        }

        function dismiss(): void {
            menu.open = false
            closeFallback.restart()
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Component.onCompleted: {
                Qt.callLater(() => keys.forceActiveFocus())
                if (root.opensToward === "over" && root.overIndex >= 0) popup.focusStop(root.overIndex, -1)
            }

            Keys.onPressed: event => {
                const count = popup.stops.length
                if (event.key === Qt.Key_Escape) popup.dismiss()
                else if (count > 0 && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Right))
                    popup.stop = (popup.stop + 1) % count
                else if (count > 0 && (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_Left))
                    popup.stop = (popup.stop - 1 + count) % count
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) popup.runStop()
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && popup.rowStops[event.key - Qt.Key_1]) {
                    popup.focusStop(popup.rowStops[event.key - Qt.Key_1].entry, -1)
                    popup.runStop()
                } else return
                event.accepted = true
            }
        }

        IrisMorphSurface {
            motionSurface: "menus"
            id: menu
            compositorBlurred: true
            blurWhileReceding: false
            ownField: true
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; z: -1 }
            open: popup.placed
            readonly property real seed: Math.round(28 * root.d)
            origin: ({ x: root.opensToward === "left" ? menu.x + menu.width - menu.seed
                    : root.opensToward === "right" ? menu.x
                    : root.opensToward.length > 0 ? Math.max(menu.x, Math.min(menu.x + menu.width - menu.seed, popup.target.x + popup.target.width / 2 - menu.seed / 2))
                    : popup.flipX ? menu.x + menu.width - menu.seed : menu.x,
                y: root.opensToward === "up" ? menu.y + menu.height - menu.seed
                    : root.opensToward === "down" ? menu.y
                    : root.opensToward.length > 0 ? Math.max(menu.y, Math.min(menu.y + menu.height - menu.seed, popup.target.y + popup.target.height / 2 - menu.seed / 2))
                    : popup.flipY ? menu.y + menu.height - menu.seed : menu.y,
                width: menu.seed, height: menu.seed, radius: menu.seed / 2 })
            contentReady: column.implicitHeight > 0
            radius: IrisStyle.surfaceRadius("menus", root.compact ? IrisStyle.radiusTile : IrisStyle.radiusCard)
            light: IrisStyle.surfaceLight("menus", IrisStyle.wallpaperLight)
            lightFrom: root.opensToward === "up" ? "bottom" : root.opensToward === "left" ? "right" : root.opensToward === "right" ? "left" : "top"
            x: root.opensToward === "over" ? popup.clampX(popup.target.x + root.overTextX - root.pad - popup.textInset)
                : root.opensToward === "left" ? popup.clampX(popup.target.x - menu.width - popup.gap)
                : root.opensToward === "right" ? popup.clampX(popup.target.x + popup.target.width + popup.gap)
                : root.opensToward.length > 0 ? popup.clampX(popup.target.x + popup.target.width / 2 - menu.width / 2)
                : popup.clampX(popup.flipX ? popup.target.x - menu.width : popup.target.x)
            y: root.opensToward === "over" ? popup.clampY(popup.target.y + popup.target.height / 2 - popup.overTop - root.rowHeight / 2)
                : root.opensToward === "up" ? popup.clampY(popup.target.y - menu.height - popup.gap)
                : root.opensToward === "down" ? popup.clampY(popup.target.y + popup.target.height + popup.gap)
                : root.opensToward.length > 0 ? popup.clampY(popup.target.y + popup.target.height / 2 - menu.height / 2)
                : popup.clampY(popup.flipY ? popup.target.y - menu.height : popup.target.y)
            // Long labels (a file name, a tray item) elide inside the cap instead of stretching the menu.
            // Over a pop-up button it is at least as wide as the button, so the button never shows past it.
            width: Math.round(Math.min((root.compact ? 300 : 360) * root.d,
                Math.max((root.compact ? 176 : 236) * root.d, column.implicitWidth + 2 * root.pad,
                    root.opensToward === "over" ? popup.target.width - root.overTextX + root.pad + popup.textInset : 0)))
            height: Math.round(column.implicitHeight + 2 * root.pad)
            onClosed: if (!menu.open) root.active = false

            ColumnLayout {
                id: column
                x: root.pad
                y: root.pad
                width: menu.width - 2 * root.pad
                spacing: Math.round((root.compact ? 1 : 2) * root.d)

                Repeater {
                    model: root.shown
                    delegate: Loader {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        sourceComponent: row.modelData?.type === "separator" ? separatorComponent
                            : row.modelData?.type === "header" ? headerComponent
                            : row.modelData?.type === "hero" ? heroComponent
                            : row.modelData?.type === "place" ? placeComponent : itemComponent

                        Component {
                            id: placeComponent
                            Item {
                                implicitHeight: picker.height + Math.round(10 * root.d)
                                IrisPlacePicker {
                                    id: picker
                                    anchors.centerIn: parent
                                    place: String(row.modelData?.place ?? "")
                                    fx: Number(row.modelData?.fx ?? 0.5)
                                    fy: Number(row.modelData?.fy ?? 0.5)
                                    hasIsland: row.modelData?.hasIsland === true
                                    label: String(row.modelData?.label ?? "")
                                    onPlaced: zone => popup.run(() => row.modelData.action(zone))
                                    onPlacedFree: (x, y) => popup.run(() => row.modelData.freeAction(x, y))
                                }
                            }
                        }

                        Component {
                            id: headerComponent
                            RowLayout {
                                implicitHeight: Math.round((root.compact ? 34 : 42) * root.d)
                                spacing: Math.round(9 * root.d)
                                Item { implicitWidth: Math.round(4 * root.d) }
                                IconImage {
                                    visible: String(row.modelData?.image ?? "").length > 0
                                    implicitSize: Math.round((root.compact ? 20 : 24) * root.d)
                                    source: String(row.modelData?.image ?? "")
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    IrisText {
                                        Layout.fillWidth: true
                                        text: String(row.modelData?.text ?? "")
                                        font.pixelSize: root.textSize
                                        font.weight: IrisStyle.weight(Font.DemiBold)
                                        elide: Text.ElideRight
                                    }
                                    IrisText {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: String(row.modelData?.detail ?? "")
                                        color: IrisStyle.muted
                                        font.pixelSize: root.compact ? IrisStyle.typeFootnote : IrisStyle.typeMeta
                                        elide: Text.ElideRight
                                    }
                                }
                                Item { implicitWidth: Math.round(4 * root.d) }
                            }
                        }

                        Component {
                            id: separatorComponent
                            Item {
                                implicitHeight: Math.round((root.compact ? 9 : 13) * root.d)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.round(12 * root.d)
                                    width: parent.width - Math.round(24 * root.d)
                                    height: 1
                                    color: IrisStyle.hairlineStrong
                                }
                            }
                        }

                        Component {
                            id: heroComponent
                            MouseArea {
                                id: hero
                                readonly property bool lit: popup.isStop(row.index, -1)
                                readonly property string image: String(row.modelData?.image ?? "")
                                readonly property var secondary: row.modelData?.secondary ?? null
                                // Shaped like the screen it shows, so the wallpaper reads as the desktop in miniature.
                                readonly property real aspect: popup.screen ? popup.screen.height / Math.max(1, popup.screen.width) : 9 / 16
                                implicitWidth: Math.round((root.compact ? 212 : 248) * root.d)
                                implicitHeight: Math.round(width * Math.max(0.42, Math.min(0.75, hero.aspect)))
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: row.modelData?.text ?? ""
                                onContainsMouseChanged: if (containsMouse) popup.focusStop(row.index, -1)
                                onClicked: popup.choose(row.modelData)
                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: IrisStyle.fieldChamfer ? 0 : Math.max(IrisStyle.radiusMicro, menu.radius - root.pad)
                                    color: IrisStyle.fillQuiet
                                    scale: hero.pressed ? IrisStyle.pressScale(0.98) : 1
                                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                    IrisWallpaperView {
                                        id: heroWallpaper
                                        // As the screen shows it, its band from the upper third (the Island's hero does the same).
                                        readonly property real screenAspect: (popup.screen?.height ?? 1080) / Math.max(1, popup.screen?.width ?? 1920)
                                        width: parent.width
                                        height: Math.max(parent.height, Math.round(parent.width * heroWallpaper.screenAspect))
                                        y: -Math.round((heroWallpaper.height - parent.height) * 0.3)
                                        screen: popup.screen
                                        path: hero.image
                                        // A still: the menu is a glance, and a live wallpaper would decode video for it.
                                        live: false
                                        decodeSize: Qt.size(Math.round(heroWallpaper.width * (hero.QsWindow.window?.devicePixelRatio ?? 1)),
                                            Math.round(heroWallpaper.height * (hero.QsWindow.window?.devicePixelRatio ?? 1)))
                                    }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: Math.round(parent.height * 0.55)
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.mediaScrim, 0) }
                                            GradientStop { position: 1; color: hero.lit ? IrisStyle.veil : IrisStyle.veilStrong }
                                        }
                                    }
                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: Math.round(10 * root.d)
                                        spacing: Math.round(6 * root.d)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            IrisText {
                                                Layout.fillWidth: true
                                                text: row.modelData?.text ?? ""
                                                color: IrisStyle.onMedia
                                                font.pixelSize: root.textSize
                                                font.weight: IrisStyle.weight(Font.DemiBold)
                                                elide: Text.ElideRight
                                            }
                                            IrisText {
                                                Layout.fillWidth: true
                                                visible: text.length > 0
                                                text: String(row.modelData?.detail ?? "")
                                                color: IrisStyle.onMediaSecondary
                                                font.pixelSize: IrisStyle.typeFootnote
                                                elide: Text.ElideRight
                                            }
                                        }
                                        MaterialSymbol {
                                            visible: !hero.secondary
                                            text: row.modelData?.iconName ?? "chevron_right"
                                            iconSize: root.glyphSize
                                            color: IrisStyle.onMedia
                                        }
                                        // A second action on the image itself, a round glass button (next wallpaper).
                                        Rectangle {
                                            id: heroButton
                                            visible: hero.secondary !== null
                                            readonly property bool lit: popup.isStop(row.index, 0) || heroButtonHover.hovered
                                            Layout.preferredWidth: Math.round(28 * root.d)
                                            Layout.preferredHeight: Layout.preferredWidth
                                            radius: IrisStyle.fieldChamfer ? 0 : width / 2
                                            color: heroButton.lit ? IrisStyle.onMediaFill : IrisStyle.veil
                                            scale: heroButtonTap.pressed ? IrisStyle.pressScale(0.9) : 1
                                            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: hero.secondary?.iconName ?? ""
                                                iconSize: Math.round(root.glyphSize * 0.95)
                                                color: IrisStyle.onMedia
                                            }
                                            HoverHandler { id: heroButtonHover; cursorShape: Qt.PointingHandCursor }
                                            // Its own MouseArea takes the press first, so the hero behind never sees it.
                                            MouseArea {
                                                id: heroButtonTap
                                                anchors.fill: parent
                                                onClicked: popup.run(hero.secondary?.action)
                                            }
                                            Accessible.role: Accessible.Button
                                            Accessible.name: hero.secondary?.text ?? ""
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: itemComponent
                            MouseArea {
                                id: menuItem
                                readonly property bool usable: row.modelData?.enabled !== false
                                readonly property bool lit: menuItem.usable && popup.isStop(row.index, -1)
                                readonly property bool danger: row.modelData?.danger === true
                                readonly property bool tinted: String(row.modelData?.tint ?? "").length > 0
                                readonly property color tint: menuItem.tinted ? IrisStyle.identityColor(row.modelData.tint) : IrisStyle.accent
                                implicitWidth: itemRow.implicitWidth + Math.round(24 * root.d)
                                implicitHeight: root.rowHeight
                                enabled: menuItem.usable
                                opacity: menuItem.usable || menuItem.skinned ? 1 : 0.4
                                // What a Design's row reads (IrisDesign part `menuRow`); it draws the row, this keeps the input.
                                readonly property bool skinned: rowSkin.active
                                readonly property var option: row.modelData
                                readonly property bool marked: root.marked
                                readonly property bool compact: root.compact
                                readonly property int code: popup.codeOf(row.index)
                                IrisSkin { id: rowSkin; part: "menuRow"; host: menuItem }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.MenuItem
                                Accessible.name: row.modelData?.text ?? ""
                                onContainsMouseChanged: if (containsMouse) popup.focusStop(row.index, -1)
                                onClicked: popup.choose(row.modelData)
                                // A plate-selection Design (AIRISU) lights the row as the solid plate of the accent; its
                                // ink turns over with it.
                                readonly property bool plate: IrisStyle.plateSelection && menuItem.lit && !menuItem.danger
                                Rectangle {
                                    visible: !menuItem.skinned
                                    anchors.fill: parent
                                    radius: IrisStyle.plateSelection ? 0 : IrisStyle.radiusRow
                                    color: menuItem.plate ? IrisStyle.selectionFill : menuItem.danger
                                        ? (menuItem.lit ? IrisStyle.tintFill(IrisStyle.danger) : ColorUtils.applyAlpha(IrisStyle.danger, 0))
                                        : (menuItem.lit ? IrisStyle.tintFill(IrisStyle.accent) : ColorUtils.applyAlpha(IrisStyle.accent, 0))
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
                                }
                                RowLayout {
                                    id: itemRow
                                    opacity: menuItem.skinned ? 0 : 1
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round((root.compact ? 8 : 10) * root.d)
                                    anchors.rightMargin: Math.round((root.compact ? 10 : 12) * root.d)
                                    spacing: Math.round((root.compact ? 8 : 10) * root.d)
                                    Item {
                                        visible: root.marked
                                        Layout.preferredWidth: Math.round((root.compact ? 18 : 20) * root.d)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: menuItem.tinted && !IrisStyle.plainMarks
                                            width: parent.width
                                            height: width
                                            radius: IrisStyle.iconRadius(width)
                                            gradient: Gradient {
                                                GradientStop { position: 0; color: IrisStyle.tileTop(menuItem.tint) }
                                                GradientStop { position: 1; color: menuItem.tint }
                                            }
                                        }
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: String(row.modelData?.image ?? "").length === 0
                                            text: row.modelData?.iconName ?? ""
                                            readonly property bool squircled: menuItem.tinted && !IrisStyle.plainMarks
                                            fill: squircled ? 1 : 0
                                            iconSize: squircled ? Math.round(root.glyphSize * 0.82) : root.glyphSize
                                            color: menuItem.plate ? IrisStyle.selectionInk : squircled ? IrisStyle.onTint
                                                : menuItem.danger ? IrisStyle.danger : menuItem.lit ? IrisStyle.text : IrisStyle.subtext
                                        }
                                        IconImage {
                                            anchors.centerIn: parent
                                            visible: String(row.modelData?.image ?? "").length > 0
                                            implicitSize: Math.round((root.compact ? 14 : 16) * root.d)
                                            source: String(row.modelData?.image ?? "")
                                        }
                                    }
                                    IrisText {
                                        Layout.fillWidth: true
                                        text: row.modelData?.text ?? ""
                                        color: menuItem.danger ? IrisStyle.danger : menuItem.plate ? IrisStyle.selectionLabel : IrisStyle.text
                                        // A choice of typeface reads in its own face.
                                        font.family: String(row.modelData?.family ?? "").length > 0 ? row.modelData.family : IrisStyle.fontMain
                                        font.pixelSize: root.textSize
                                        font.weight: IrisStyle.weight(Font.Medium)
                                        elide: Text.ElideRight
                                    }
                                    IrisText {
                                        visible: text.length > 0
                                        text: String(row.modelData?.detail ?? "")
                                        color: menuItem.plate ? IrisStyle.selectionDetail : IrisStyle.muted
                                        font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeFootnote : IrisStyle.typeMeta
                                        font.weight: IrisStyle.weight(Font.DemiBold)
                                        font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
                                        font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontNumbers
                                        font.features: ({ "tnum": 1 })
                                    }
                                    MaterialSymbol {
                                        visible: row.modelData?.checked === true || row.modelData?.submenu === true
                                        text: row.modelData?.submenu === true ? "chevron_right" : "check"
                                        iconSize: root.glyphSize
                                        color: row.modelData?.submenu === true ? IrisStyle.subtext : IrisStyle.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
