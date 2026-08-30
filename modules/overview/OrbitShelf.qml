pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelSurface {
    id: root

    required property string outputName
    required property real availableWidth

    readonly property var orbitOptions: Config.options?.orbit ?? {}
    readonly property var shelfOptions: orbitOptions.shelf ?? {}
    readonly property int itemLimit: Math.max(2, Math.min(8, orbitOptions.trailItems ?? 5))
    readonly property bool compact: availableWidth < 760
    readonly property var stashedIds: MinimizedWindows.getMinimizedForOutput(outputName)
    readonly property var outputWorkspaces: (NiriService.allWorkspaces ?? [])
        .filter(workspace => workspace.output === outputName && !root.isStashWorkspace(workspace.id))
        .sort((a, b) => a.idx - b.idx)
    readonly property var activeWorkspace: outputWorkspaces.find(workspace => workspace.is_active) ?? null
    readonly property int activeWindowCount: activeWorkspace
        ? (NiriService.windows ?? []).filter(window => window.workspace_id === activeWorkspace.id
            && !MinimizedWindows.isMinimized(window.id)).length : 0
    readonly property var trailWindows: {
        const workspaceIds = new Set(root.outputWorkspaces.map(workspace => workspace.id))
        const byId = {}
        for (const window of NiriService.windows ?? []) byId[window.id] = window
        const result = []
        for (const id of NiriService.mruWindowIds ?? []) {
            const window = byId[id]
            if (!window || !workspaceIds.has(window.workspace_id) || MinimizedWindows.isMinimized(id)) continue
            result.push(window)
            if (result.length >= root.itemLimit) break
        }
        return result
    }
    readonly property var pinnedActions: {
        const ids = Array.isArray(root.shelfOptions.pinnedActions)
            ? root.shelfOptions.pinnedActions : ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
        const byId = {}
        for (const action of GlobalActions.allActions ?? []) byId[action.id] = action
        return ids.map(id => byId[id]).filter(action => action !== undefined).slice(0, 3)
    }
    readonly property var moduleIds: {
        const defaults = ["locator", "trail", "niri", "actions", "stash"]
        const source = Array.isArray(root.shelfOptions.modules) ? root.shelfOptions.modules : defaults
        const result = []
        for (const id of source) {
            if (!defaults.includes(id) || result.includes(id)) continue
            if (id === "trail" && (!(root.orbitOptions.showTrail ?? true) || root.trailWindows.length === 0)) continue
            if (id === "stash" && (!(root.orbitOptions.showStash ?? true) || root.stashedIds.length === 0)) continue
            result.push(id)
        }
        return result
    }

    function isStashWorkspace(workspaceId): bool {
        const windows = (NiriService.windows ?? []).filter(window => window.workspace_id === workspaceId)
        return windows.length > 0 && windows.every(window => MinimizedWindows.isMinimized(window.id))
    }

    function runNiriAction(actionId: string): void {
        if (actionId === "maximize") NiriService.maximizeColumn()
        else if (actionId === "consume") NiriService.consumeWindowIntoColumn()
        else if (actionId === "expel") NiriService.expelWindowFromColumn()
    }

    function runPinnedAction(actionId: string): void {
        if (root.shelfOptions.closeOnAction ?? true) GlobalStates.closeOverview()
        GlobalActions.runById(actionId, "")
    }

    function openActionPalette(): void {
        GlobalStates.closeOverview()
        GlobalActions.runLauncher(["overview", "actionOpen"])
    }

    width: Math.min(availableWidth, Math.max(320, shelfRow.implicitWidth + 20))
    implicitWidth: width
    implicitHeight: 56
    elevation: 2
    cardStyle: true
    outlined: false

    RowLayout {
        id: shelfRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Repeater {
            model: root.moduleIds

            delegate: RowLayout {
                id: moduleDelegate
                required property string modelData
                required property int index
                Layout.fillWidth: modelData === "trail"
                Layout.minimumWidth: modelData === "trail" ? 40 : implicitWidth
                Layout.fillHeight: true
                spacing: 8

                Rectangle {
                    visible: moduleDelegate.index > 0
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 26
                    color: Appearance.colors.colOutlineVariant
                    opacity: 0.55
                }

                Loader {
                    Layout.fillWidth: moduleDelegate.modelData === "trail"
                    Layout.fillHeight: true
                    sourceComponent: moduleDelegate.modelData === "locator" ? locatorComponent
                        : moduleDelegate.modelData === "trail" ? trailComponent
                        : moduleDelegate.modelData === "niri" ? niriComponent
                        : moduleDelegate.modelData === "actions" ? actionsComponent
                        : moduleDelegate.modelData === "stash" ? stashComponent : null
                }
            }
        }
    }

    Component {
        id: locatorComponent

        RowLayout {
            spacing: 7

            MaterialShapeWrappedMaterialSymbol {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                text: "hub"
                iconSize: 19
                padding: 7
            }

            ColumnLayout {
                visible: !root.compact
                spacing: -1

                StyledText {
                    text: Translation.tr("Workspace %1").arg(root.activeWorkspace?.idx ?? "–")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }
                StyledText {
                    text: root.activeWindowCount === 1
                        ? Translation.tr("1 window")
                        : Translation.tr("%1 windows").arg(root.activeWindowCount)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }

    Component {
        id: trailComponent

        Item {
            implicitWidth: trailRow.implicitWidth
            implicitHeight: 40
            clip: true

            RowLayout {
                id: trailRow
                anchors.fill: parent
                spacing: 4

                MaterialSymbol {
                    Layout.leftMargin: 1
                    text: "history"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: root.trailWindows

                    RippleButton {
                        id: trailButton
                        required property var modelData
                        Layout.minimumWidth: 36
                        Layout.preferredWidth: root.compact
                            ? 36 : Math.min(154, Math.max(82, trailContent.implicitWidth + 16))
                        Layout.fillHeight: true
                        buttonRadius: Appearance.rounding.small
                        colBackground: modelData.is_focused
                            ? Appearance.colors.colSecondaryContainer : "transparent"
                        colBackgroundHover: modelData.is_focused
                            ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                        onClicked: {
                            NiriService.focusWindow(modelData.id)
                            if (root.orbitOptions.closeOnSelect ?? true) GlobalStates.closeOverview()
                        }

                        contentItem: RowLayout {
                            id: trailContent
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            spacing: 6

                            Image {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                source: AppSearch.getIconSource(trailButton.modelData.app_id || "")
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            StyledText {
                                visible: !root.compact
                                Layout.fillWidth: true
                                text: trailButton.modelData.title || trailButton.modelData.app_id || Translation.tr("Window")
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: trailButton.modelData.is_focused
                                    ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                            }
                        }
                        StyledToolTip {
                            text: trailButton.modelData.title || trailButton.modelData.app_id || Translation.tr("Window")
                        }
                    }
                }
            }
        }
    }

    Component {
        id: niriComponent

        RowLayout {
            spacing: 2

            IconToolbarButton {
                text: "open_in_full"
                onClicked: root.runNiriAction("maximize")
                StyledToolTip { text: Translation.tr("Maximize column") }
            }
            IconToolbarButton {
                text: "merge_type"
                onClicked: root.runNiriAction("consume")
                StyledToolTip { text: Translation.tr("Consume window into column") }
            }
            IconToolbarButton {
                text: "call_split"
                onClicked: root.runNiriAction("expel")
                StyledToolTip { text: Translation.tr("Expel window from column") }
            }
        }
    }

    Component {
        id: actionsComponent

        RowLayout {
            spacing: 2

            Repeater {
                model: root.pinnedActions

                IconToolbarButton {
                    required property var modelData
                    text: modelData.icon || "bolt"
                    onClicked: root.runPinnedAction(modelData.id)
                    StyledToolTip { text: modelData.name || modelData.id }
                }
            }

            IconToolbarButton {
                text: "more_horiz"
                onClicked: root.openActionPalette()
                StyledToolTip { text: Translation.tr("All actions") }
            }
        }
    }

    Component {
        id: stashComponent

        RippleButton {
            implicitWidth: 44
            implicitHeight: 38
            buttonRadius: Appearance.rounding.small
            colBackground: Appearance.colors.colLayer2
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: MinimizedWindows.restoreLatestForOutput(root.outputName,
                (root.orbitOptions.stashRestoreMode ?? "original") !== "current")

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 3
                MaterialSymbol {
                    text: "inventory_2"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                }
                StyledText {
                    text: root.stashedIds.length.toString()
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
            }
            StyledToolTip { text: Translation.tr("Restore latest stashed window") }
        }
    }
}
