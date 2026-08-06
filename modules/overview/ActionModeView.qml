import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/**
 * ActionModeView — Full keyboard-navigable action panel for the overview.
 *
 * Replaces normal search results when the user types the action prefix ("/").
 * Shows categorized actions from GlobalActions + live package search results.
 *
 * Keyboard navigation:
 *   - Up/Down: navigate items
 *   - Enter: execute selected action
 *   - Tab/Shift+Tab: cycle category tabs
 *   - Typing: fuzzy filter all actions
 */
Item {
    id: root
    property string query: ""
    property int selectedCategoryIndex: 0
    // Entering action mode ("/") always starts on "All" (index 0) so the query
    // is never silently filtered by a category left selected from a previous
    // session — the user no longer has to Tab back to "All" to capture input.
    onVisibleChanged: if (visible) selectedCategoryIndex = 0
    property real availableHeight: Number.POSITIVE_INFINITY
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere

    readonly property var categoryList: [
        { id: "all",        label: Translation.tr("All"),        icon: "apps" },
        { id: "system",     label: Translation.tr("System"),     icon: "settings_suggest" },
        { id: "appearance", label: Translation.tr("Appearance"), icon: "palette" },
        { id: "tools",      label: Translation.tr("Tools"),      icon: "build" },
        { id: "media",      label: Translation.tr("Media"),      icon: "headphones" },
        { id: "settings",   label: Translation.tr("Settings"),   icon: "tune" },
    ]
    readonly property string selectedCategory: categoryList[selectedCategoryIndex]?.id ?? "all"

    // Package search trigger detection
    readonly property bool isPackageInstall: query.toLowerCase().startsWith("install ")
    readonly property bool isPackageRemove: query.toLowerCase().startsWith("remove ")
    readonly property bool isPackageSearch: query.toLowerCase().startsWith("search ")
    readonly property bool isPackageQuery: isPackageInstall || isPackageRemove || isPackageSearch
    readonly property string packageQuery: {
        if (isPackageInstall) return query.substring(8).trim()
        if (isPackageRemove) return query.substring(7).trim()
        if (isPackageSearch) return query.substring(7).trim()
        return ""
    }

    // Flat list of actionable items only (no headers — tabs handle categorization)
    readonly property var displayItems: {
        let items = []

        // Actions
        let actions = []
        if (root.query === "") {
            actions = selectedCategory === "all"
                ? GlobalActions.allActions
                : GlobalActions.listByCategory(selectedCategory)
        } else {
            actions = GlobalActions.fuzzyQuery(root.query)
            if (selectedCategory !== "all")
                actions = actions.filter(a => a.category === selectedCategory)
        }
        for (const a of actions) {
            items.push({
                type: "action",
                key: `action_${a.id}`,
                name: a.name,
                description: a.description ?? "",
                icon: a.icon ?? "settings",
                category: a.category ?? "",
                action: a
            })
        }

        // Package results
        if (root.isPackageQuery && PackageSearch.results.length > 0) {
            for (let i = 0; i < Math.min(PackageSearch.results.length, 30); i++) {
                const pkg = PackageSearch.results[i]
                items.push({
                    type: "package",
                    key: `pkg_${pkg.repo}_${pkg.name}`,
                    name: pkg.name,
                    description: pkg.description ?? "",
                    icon: pkg.installed ? "check_circle" : (root.isPackageRemove ? "delete" : "download"),
                    category: pkg.repo ?? "",
                    pkg: pkg
                })
            }
        }

        return items
    }

    readonly property bool showLoading: root.isPackageQuery && PackageSearch.searching
    readonly property bool showEmpty: displayItems.length === 0 && root.query !== "" && !showLoading

    onPackageQueryChanged: {
        if (root.packageQuery.length >= 2) {
            if (root.isPackageRemove) {
                PackageSearch.searchInstalled(root.packageQuery)
            } else {
                PackageSearch.search(root.packageQuery)
            }
        } else {
            PackageSearch.clear()
        }
    }

    Component.onDestruction: PackageSearch.clear()

    signal actionExecuted()
    signal returnToSearch()

    implicitWidth: mainColumn.implicitWidth
    readonly property real reservedHeight: categoryTabBar.implicitHeight
        + (packageHints.visible ? packageHints.implicitHeight : 0)
        + categoryTabBar.Layout.topMargin
        + categoryTabBar.Layout.bottomMargin
        + packageHints.Layout.topMargin
        + packageHints.Layout.bottomMargin
        + actionList.topMargin
        + actionList.bottomMargin
        + mainColumn.spacing * 3
        + 12
    readonly property real maxListHeight: Math.max(160, availableHeight - reservedHeight)
    implicitHeight: Math.min(mainColumn.implicitHeight, availableHeight)

    function focusFirstItem(): void {
        if (actionList.count > 0) {
            actionList.currentIndex = 0
            actionList.forceActiveFocus()
        }
    }

    function stepSelection(step): bool {
        if (actionList.count <= 0)
            return false

        const baseIndex = actionList.currentIndex >= 0 ? actionList.currentIndex : (step > 0 ? -1 : 0)
        const targetIndex = Math.max(0, Math.min(baseIndex + step, actionList.count - 1))
        actionList.currentIndex = targetIndex
        return true
    }

    function syncCurrentActionItem(shouldFocus): void {
        if (actionList.count <= 0)
            return

        const targetIndex = actionList.currentIndex >= 0 ? Math.min(actionList.currentIndex, actionList.count - 1) : 0
        actionList.currentIndex = targetIndex

        if (!shouldFocus)
            return

        actionList.forceActiveFocus()
    }

    function executeCurrentOrFirst(): void {
        if (actionList.count <= 0)
            return

        const targetIndex = actionList.currentIndex >= 0 ? actionList.currentIndex : 0
        actionList.currentIndex = targetIndex
        if (!actionList.activeFocus)
            actionList.forceActiveFocus()

        const item = actionList.itemAtIndex(targetIndex)
        if (item && item.clicked) {
            item.clicked()
            return
        }

        Qt.callLater(() => {
            const delayedItem = actionList.itemAtIndex(targetIndex)
            if (delayedItem && delayedItem.clicked)
                delayedItem.clicked()
        })
    }

    function _executePackageActionStatic(pkg, isRemove): void {
        const name = pkg?.name ?? ""
        if (isRemove)
            PackageSearch.removePackage(name)
        else
            PackageSearch.installPackage(name, pkg?.isAur ?? false)
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Appearance.sizes.spacingSmall

        // ── Category Tab Bar (uses existing SecondaryTabBar widget) ──
        SecondaryTabBar {
            id: categoryTabBar
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            width: Math.min(implicitWidth, Math.max(0, root.width - 24))
            indicatorPadding: 12
            bottomBorderVisible: false
            wheelNavigationEnabled: false
            currentIndex: root.selectedCategoryIndex
            onCurrentIndexChanged: root.selectedCategoryIndex = currentIndex

            Repeater {
                model: root.categoryList
                SecondaryTabButton {
                    buttonText: modelData.label
                    buttonIcon: modelData.icon
                    selected: categoryTabBar.currentIndex === index
                    width: implicitWidth
                }
            }
        }

        // ── Package command hints ──
        RowLayout {
            id: packageHints
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            width: Math.min(implicitWidth, Math.max(0, root.width - 40))
            spacing: 16
            visible: root.query === "" || root.query.length <= 3

            Repeater {
                model: [
                    { cmd: "install <pkg>", desc: Translation.tr("Install package") },
                    { cmd: "remove <pkg>", desc: Translation.tr("Remove package") },
                    { cmd: "search <pkg>", desc: Translation.tr("Search packages") },
                ]
                delegate: RowLayout {
                    spacing: 4
                    StyledText {
                        text: modelData.cmd
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        color: root.zzzEverywhere ? Appearance.zzz.accent
                            : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                        opacity: root.zzzEverywhere ? 1 : 0.7
                    }
                    StyledText {
                        text: modelData.desc
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                        opacity: root.zzzEverywhere ? 1 : 0.5
                    }
                }
            }
        }

        // ── Action/Package List ──
        ListView {
            id: actionList
            Layout.fillWidth: true
            implicitHeight: Math.min(root.maxListHeight, contentHeight + topMargin + bottomMargin)
            clip: true
            topMargin: 10
            bottomMargin: 8
            spacing: root.zzzEverywhere ? 6 : 2
            highlightMoveDuration: Appearance.animation.elementMoveFast.duration / 2
            focus: true

            model: root.displayItems

            function stepCurrentSelection(step) {
                return root.stepSelection(step)
            }

            function focusCurrentOrFirst() {
                root.syncCurrentActionItem(true)
            }

            function activateCurrentOrFirst() {
                root.executeCurrentOrFirst()
            }

            Connections {
                target: root
                function onQueryChanged() {
                    if (actionList.count > 0)
                        actionList.currentIndex = 0
                }
                function onSelectedCategoryIndexChanged() {
                    if (actionList.count > 0)
                        actionList.currentIndex = 0
                }
            }

            onActiveFocusChanged: {
                if (activeFocus && count > 0 && currentIndex < 0)
                    currentIndex = 0
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    activateCurrentOrFirst()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    stepCurrentSelection(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    if (currentIndex > 0) {
                        stepCurrentSelection(-1)
                    } else {
                        root.returnToSearch()
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) {
                    root.selectedCategoryIndex = (root.selectedCategoryIndex + 1) % root.categoryList.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) {
                    root.selectedCategoryIndex = (root.selectedCategoryIndex - 1 + root.categoryList.length) % root.categoryList.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false
                    event.accepted = true
                }
            }

            // ── Delegate: RippleButton matching SearchItem style ──
            delegate: RippleButton {
                id: delegateBtn
                property var entry: modelData
                property bool isAction: entry?.type === "action"
                property bool isPackage: entry?.type === "package"
                property bool keyboardDown: false
                readonly property bool isCurrentItem: ListView.isCurrentItem
                readonly property bool isHighlighted: delegateBtn.isCurrentItem
                readonly property color normalTextColor: root.zzzEverywhere ? Appearance.zzz.ink
                    : Appearance.angelEverywhere ? Appearance.angel.colText
                    : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                readonly property color selectedTextColor: root.zzzEverywhere ? Appearance.zzz.onSignal
                    : Appearance.angelEverywhere ? Appearance.angel.colText
                    : Appearance.inirEverywhere ? Appearance.inir.colText
                    : Appearance.colors.colOnLayer1
                readonly property color descriptionTextColor: delegateBtn.isHighlighted
                    ? (root.zzzEverywhere ? Appearance.zzz.onSignal
                        : Appearance.angelEverywhere ? Appearance.angel.colText
                        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                        : Appearance.colors.colOnLayer1)
                    : (root.zzzEverywhere ? Appearance.zzz.inkMuted
                        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext)
                readonly property color selectedBackgroundColor: root.zzzEverywhere ? Appearance.zzz.signal
                    : Appearance.angelEverywhere
                    ? Appearance.angel.colGlassCardHover
                    : Appearance.colors.colLayer1
                readonly property color hoverBackgroundColor: root.zzzEverywhere ? Appearance.zzz.paperAlt
                    : Appearance.angelEverywhere
                    ? Appearance.angel.colGlassCardHover
                    : Appearance.colors.colLayer1
                readonly property color pressedBackgroundColor: root.zzzEverywhere ? ColorUtils.mix(Appearance.zzz.signal, Appearance.zzz.ink, 0.78)
                    : Appearance.angelEverywhere
                    ? Appearance.angel.colGlassCardActive
                    : Appearance.colors.colLayer1Hover

                anchors.left: parent?.left
                anchors.right: parent?.right

                property int horizontalMargin: root.zzzEverywhere ? 14 : 10
                property int buttonHorizontalPadding: root.zzzEverywhere ? 12 : 10
                property int buttonVerticalPadding: root.zzzEverywhere ? 8 : 6

                implicitHeight: delegateRow.implicitHeight + buttonVerticalPadding * 2

                // Style tokens — exactly match SearchItem.qml
                buttonRadius: root.zzzEverywhere ? Appearance.zzz.pillRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.normal
                colBackground: (delegateBtn.down || delegateBtn.keyboardDown)
                    ? delegateBtn.pressedBackgroundColor
                    : (delegateBtn.isHighlighted
                        ? delegateBtn.selectedBackgroundColor
                        : (delegateBtn.hovered ? delegateBtn.hoverBackgroundColor : "transparent"))
                colBackgroundHover: delegateBtn.hoverBackgroundColor
                colRipple: root.zzzEverywhere ? ColorUtils.transparentize(Appearance.zzz.ink, 0.72)
                    : Appearance.angelEverywhere
                    ? Appearance.angel.colGlassCardActive
                    : Appearance.colors.colLayer1Hover

                background {
                    anchors.fill: delegateBtn
                    anchors.leftMargin: delegateBtn.horizontalMargin
                    anchors.rightMargin: delegateBtn.horizontalMargin
                }

                PointingHandInteraction {}

                Rectangle {
                    anchors.fill: delegateBtn
                    anchors.leftMargin: delegateBtn.horizontalMargin
                    anchors.rightMargin: delegateBtn.horizontalMargin
                    visible: root.zzzEverywhere
                    radius: delegateBtn.buttonRadius
                    color: "transparent"
                    border.width: delegateBtn.isHighlighted || delegateBtn.hovered ? Appearance.zzz.borderThick : 1
                    border.color: delegateBtn.isHighlighted ? Appearance.zzz.accent : Appearance.zzz.hairline

                    Behavior on border.color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                onClicked: {
                    // Capture values before closing overview (which destroys this component)
                    const capturedAction = isAction ? entry.action : null
                    const capturedPkg = isPackage ? entry.pkg : null
                    const capturedArgs = root.isPackageQuery ? root.packageQuery : root.query
                    const capturedIsRemove = root.isPackageRemove
                    root.actionExecuted()
                    GlobalStates.overviewOpen = false
                    if (capturedAction?.execute) {
                        capturedAction.execute(capturedArgs)
                    } else if (capturedPkg) {
                        root._executePackageActionStatic(capturedPkg, capturedIsRemove)
                    }
                }

                RowLayout {
                    id: delegateRow
                    spacing: 10
                    anchors.fill: parent
                    anchors.leftMargin: delegateBtn.horizontalMargin + delegateBtn.buttonHorizontalPadding
                    anchors.rightMargin: delegateBtn.horizontalMargin + delegateBtn.buttonHorizontalPadding

                    // Icon circle
                    Rectangle {
                        implicitWidth: 35
                        implicitHeight: 35
                        scale: delegateBtn.isHighlighted ? 1 : 0.96
                        radius: root.zzzEverywhere ? Appearance.zzz.pillRadius
                            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                            : Appearance.rounding.full
                        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                        color: {
                            if (root.zzzEverywhere)
                                return delegateBtn.isHighlighted ? Appearance.zzz.accent : Appearance.zzz.paperAlt
                            if (isPackage && entry.pkg?.installed)
                                return ColorUtils.transparentize(
                                    Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary, 0.3)
                            return delegateBtn.isHighlighted
                                ? (Appearance.angelEverywhere ? Appearance.angel.colGlassElevatedHover : Appearance.colors.colLayer2Hover)
                                : (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                    : Appearance.zzzEverywhere ? Appearance.colors.colLayer2
                                    : Appearance.colors.colSecondaryContainer)
                        }

                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }

                        Behavior on scale {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementResize.duration
                                easing.type: Appearance.animation.elementResize.type
                                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: entry?.icon ?? "settings"
                            iconSize: Appearance.font.pixelSize.huge
                            fill: (isPackage && entry.pkg?.installed) ? 1 : 0
                            animateFill: true
                            color: {
                                if (root.zzzEverywhere)
                                    return delegateBtn.isHighlighted ? Appearance.zzz.onAccent : delegateBtn.normalTextColor
                                if (isPackage && entry.pkg?.installed)
                                    return Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                                return delegateBtn.isHighlighted
                                    ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                        : Appearance.colors.colPrimary)
                                    : delegateBtn.normalTextColor
                            }
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }
                    }

                    // Name + description
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        // Category label (small, above name) for filtered "all" results
                        StyledText {
                            visible: root.selectedCategory === "all" && root.query !== "" && isAction
                            text: entry?.category ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: delegateBtn.descriptionTextColor
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: entry?.name ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: delegateBtn.isHighlighted ? Font.DemiBold : Font.Medium
                            color: delegateBtn.isHighlighted ? delegateBtn.selectedTextColor : delegateBtn.normalTextColor
                            elide: Text.ElideRight
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: entry?.description ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: delegateBtn.descriptionTextColor
                            elide: Text.ElideRight
                            opacity: delegateBtn.isHighlighted ? 0.98 : 0.82
                        }
                    }

                    // Package badges
                    RowLayout {
                        visible: isPackage
                        spacing: 4

                        StyledText {
                            visible: entry?.pkg?.version ? true : false
                            text: entry?.pkg?.version ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                        }

                        Rectangle {
                            visible: entry?.pkg?.repo ? true : false
                            implicitWidth: repoText.implicitWidth + 10
                            implicitHeight: repoText.implicitHeight + 4
                            radius: height / 2
                            color: root.zzzEverywhere
                                ? ColorUtils.transparentize(Appearance.zzz.accent, 0.76)
                                : entry?.pkg?.isAur
                                ? ColorUtils.transparentize(Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary, 0.3)
                                : (Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.colors.colSecondaryContainer)

                            StyledText {
                                id: repoText
                                anchors.centerIn: parent
                                text: entry?.pkg?.repo ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.zzzEverywhere ? Appearance.zzz.ink
                                    : entry?.pkg?.isAur
                                    ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                    : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSecondaryContainer)
                            }
                        }

                        Rectangle {
                            visible: entry?.pkg?.installed ?? false
                            implicitWidth: installedText.implicitWidth + 10
                            implicitHeight: installedText.implicitHeight + 4
                            radius: height / 2
                            color: root.zzzEverywhere ? Appearance.zzz.signal : ColorUtils.transparentize(
                                Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary, 0.2)
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                            StyledText {
                                id: installedText
                                anchors.centerIn: parent
                                text: Translation.tr("Installed")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: root.zzzEverywhere ? Appearance.zzz.onSignal
                                    : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                            }
                        }
                    }

                    // Action hint on hover/focus
                    StyledText {
                        Layout.fillWidth: false
                        opacity: (delegateBtn.hovered || delegateBtn.isHighlighted) ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                        }
                        text: isAction
                            ? (entry?.action?.verb ?? Translation.tr("Run"))
                            : (root.isPackageRemove ? Translation.tr("Remove") : Translation.tr("Install"))
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: delegateBtn.isHighlighted ? delegateBtn.selectedTextColor : delegateBtn.normalTextColor
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                    }
                }
            }
        }

        // ── Loading indicator ──
        RowLayout {
            opacity: root.showLoading ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
            }
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            BusyIndicator {
                running: root.showLoading
                implicitWidth: 20
                implicitHeight: 20
            }
            StyledText {
                text: Translation.tr("Searching packages...")
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            }
        }

        // ── Empty state ──
        ColumnLayout {
            opacity: root.showEmpty ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
            }
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.bottomMargin: 20
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "search_off"
                iconSize: 28
                color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No results for \"%1\"").arg(root.query)
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }

        // ── Keyboard hints footer ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            spacing: Appearance.sizes.spacingLarge
            opacity: root.zzzEverywhere ? 0.8 : 0.5

            Repeater {
                model: [
                    { key: "↑↓", hint: Translation.tr("Navigate") },
                    { key: "↵",  hint: Translation.tr("Run") },
                    { key: "Tab", hint: Translation.tr("Category") },
                    { key: "←→", hint: Translation.tr("Category") },
                    { key: "Esc", hint: Translation.tr("Close") },
                ]
                delegate: RowLayout {
                    spacing: 3
                    Rectangle {
                        implicitWidth: keyLabel.implicitWidth + 8
                        implicitHeight: keyLabel.implicitHeight + 4
                        radius: Appearance.rounding.unsharpen
                        color: root.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : Appearance.colors.colSecondaryContainer
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                        StyledText {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: modelData.key
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: root.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                        }
                    }
                    StyledText {
                        text: modelData.hint
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    }
                }
            }
        }
    }
}
