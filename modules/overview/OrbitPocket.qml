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

    signal dismissed()

    readonly property var orbitOptions: Config.options?.orbit ?? {}
    readonly property var pocketOptions: orbitOptions.pocket ?? {}
    readonly property var stashedIds: MinimizedWindows.getMinimizedForOutput(outputName)
    readonly property bool listMode: pocketOptions.layout === "list"
    readonly property bool showPreviews: pocketOptions.showPreviews ?? true
    readonly property int columns: listMode ? 1 : Math.max(1, Math.min(3, stashedIds.length))
    readonly property real previewDpr: Math.max(1, root.QsWindow?.window?.devicePixelRatio ?? 1)
    property int keyboardIndex: stashedIds.length > 0 ? 0 : -1

    function requestPreviews(): void {
        if (root.showPreviews && root.stashedIds.length > 0)
            WindowPreviewService.captureForTaskView(root.stashedIds, 30000)
    }

    function focusFirstKeyboard(): void {
        keyboardIndex = root.stashedIds.length > 0 ? 0 : -1
    }

    function focusNextKeyboard(): void {
        if (root.stashedIds.length === 0) return
        keyboardIndex = keyboardIndex < 0 ? 0 : (keyboardIndex + 1) % root.stashedIds.length
    }

    function focusPreviousKeyboard(): void {
        if (root.stashedIds.length === 0) return
        keyboardIndex = keyboardIndex < 0 ? root.stashedIds.length - 1
            : (keyboardIndex - 1 + root.stashedIds.length) % root.stashedIds.length
    }

    function activateKeyboard(): void {
        if (!MinimizedWindows.actionReady) return
        if (keyboardIndex < 0 || keyboardIndex >= root.stashedIds.length) return
        root.restoreWindow(root.stashedIds[keyboardIndex])
    }

    function restoreWindow(windowId: int): void {
        if (!MinimizedWindows.actionReady) return
        if ((root.orbitOptions.stashRestoreMode ?? "original") === "current")
            MinimizedWindows.restore(windowId)
        else
            MinimizedWindows.restoreOriginal(windowId)
    }

    function normalizeKeyboardIndex(): void {
        if (root.stashedIds.length === 0) {
            root.keyboardIndex = -1
            root.dismissed()
            return
        }
        root.keyboardIndex = Math.max(0, Math.min(root.keyboardIndex, root.stashedIds.length - 1))
    }

    width: Math.min(availableWidth, Math.max(360,
        Math.min(root.listMode ? 680 : 920, pocketGrid.implicitWidth + 28)))
    implicitWidth: width
    implicitHeight: pocketColumn.implicitHeight + 24
    elevation: 2
    cardStyle: true
    outlined: false
    clipContent: true

    ColumnLayout {
        id: pocketColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialShapeWrappedMaterialSymbol {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                text: "inventory_2"
                iconSize: 18
                padding: 7
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                StyledText {
                    text: Translation.tr("Pocket")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }
                StyledText {
                    text: root.stashedIds.length === 1
                        ? Translation.tr("1 window held outside the workspace flow")
                        : Translation.tr("%1 windows held outside the workspace flow").arg(root.stashedIds.length)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            IconToolbarButton {
                text: "close"
                onClicked: root.dismissed()
                StyledToolTip { text: Translation.tr("Close Pocket") }
            }
        }

        GridLayout {
            id: pocketGrid
            Layout.fillWidth: true
            columns: root.columns
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root.stashedIds

                delegate: RippleButton {
                    id: pocketCard
                    required property int modelData
                    required property int index
                    readonly property var info: MinimizedWindows.minimizedWindows[modelData] ?? null
                    readonly property var windowData: (NiriService.windows ?? [])
                        .find(window => window.id === modelData) ?? null
                    property string previewUrl: ""

                    Layout.preferredWidth: root.columns === 1
                        ? Math.min(root.listMode ? 640 : 520, root.availableWidth - 28) : 250
                    Layout.preferredHeight: root.listMode ? 68 : 112
                    enabled: MinimizedWindows.actionReady
                    buttonRadius: Appearance.rounding.normal
                    toggled: root.keyboardIndex === index
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: root.restoreWindow(modelData)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 9

                        PanelSurface {
                            id: previewFrame
                            visible: root.showPreviews
                            Layout.preferredWidth: root.listMode ? 88 : 132
                            Layout.fillHeight: true
                            radiusOverride: Appearance.rounding.small
                            elevation: 1
                            cardStyle: false
                            outlined: false
                            clipContent: true

                            Image {
                                id: previewImage
                                anchors.fill: parent
                                property bool hadReadyFrame: false
                                source: pocketCard.previewUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                mipmap: false
                                retainWhileLoading: true
                                sourceSize.width: Math.round((root.listMode ? 384 : 512) * root.previewDpr)
                                sourceSize.height: Math.round((root.listMode ? 216 : 288) * root.previewDpr)
                                visible: opacity > 0.001
                                opacity: status === Image.Ready
                                    || (status === Image.Loading && hadReadyFrame) ? 1 : 0
                                onStatusChanged: {
                                    if (status === Image.Ready)
                                        hadReadyFrame = true
                                    else if (status === Image.Error || status === Image.Null)
                                        hadReadyFrame = false
                                }
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                source: AppSearch.getIconSource(pocketCard.windowData?.app_id
                                    || pocketCard.info?.appId || "")
                                fillMode: Image.PreserveAspectFit
                                visible: previewImage.opacity <= 0.001
                            }
                        }

                        Image {
                            visible: !root.showPreviews
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: AppSearch.getIconSource(pocketCard.windowData?.app_id
                                || pocketCard.info?.appId || "")
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: pocketCard.info?.title || pocketCard.windowData?.title
                                    || pocketCard.info?.appId || Translation.tr("Window")
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: pocketCard.toggled
                                    ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Workspace %1").arg(pocketCard.info?.originalWorkspace ?? "–")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: pocketCard.toggled
                                    ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            }
                            Item { Layout.fillHeight: true }
                            RowLayout {
                                spacing: 4
                                MaterialSymbol {
                                text: "keyboard_return"
                                    iconSize: 15
                                    color: pocketCard.toggled
                                        ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: MinimizedWindows.actionReady
                                        ? Translation.tr("Restore") : Translation.tr("Connecting…")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: pocketCard.toggled
                                        ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                                }
                            }
                        }
                    }

                    Component.onCompleted: previewUrl = WindowPreviewService.getPreviewUrl(modelData)

                    Connections {
                        target: WindowPreviewService
                        function onPreviewUpdated(windowId: int): void {
                            if (windowId === pocketCard.modelData)
                                pocketCard.previewUrl = WindowPreviewService.getPreviewUrl(windowId)
                        }
                        function onCaptureComplete(): void {
                            const url = WindowPreviewService.getPreviewUrl(pocketCard.modelData)
                            if (url) pocketCard.previewUrl = url
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: MinimizedWindows
        function onMinimizedIdsChanged() {
            root.normalizeKeyboardIndex()
            root.requestPreviews()
        }
    }

    Component.onCompleted: root.requestPreviews()
    onShowPreviewsChanged: if (showPreviews) root.requestPreviews()
}
