pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root

    // Style tokens — ToolsView pattern
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBgHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall

    Component.onCompleted: {
        if (AppCatalog.packageManager === "unknown") {
            AppCatalog.refresh()
        }
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: flickable.width
            spacing: 8

            // ─── Search bar ──────────────────────────────────────
            ToolbarTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search apps...")
                text: AppCatalog.searchQuery
                onTextChanged: AppCatalog.searchQuery = text
            }

            // ─── Category selector (ButtonGroup + GroupButton, scrollable with fade) ─
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: catFlickable.implicitHeight

                Flickable {
                    id: catFlickable
                    anchors.fill: parent
                    implicitHeight: catGroup.implicitHeight
                    contentWidth: catGroup.width
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ButtonGroup {
                        id: catGroup
                        x: catGroup.width < catFlickable.width ? (catFlickable.width - catGroup.width) / 2 : 0
                        spacing: 2
                        property int clickIndex: -1

                        GroupButton {
                            toggled: AppCatalog.selectedCategory === "all"
                            bounce: true
                            colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                : Appearance.auroraEverywhere ? "transparent"
                                : Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                : Appearance.colors.colLayer1Hover
                            colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                                : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                : Appearance.colors.colSecondaryContainer
                            colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                : Appearance.colors.colSecondaryContainerHover
                            contentItem: RowLayout {
                                spacing: 4
                                MaterialSymbol {
                                    text: "apps"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: root.colText
                                }
                                StyledText {
                                    text: Translation.tr("All")
                                }
                            }
                            onClicked: {
                                catGroup.clickIndex = 0
                                AppCatalog.selectedCategory = "all"
                            }
                        }

                        Repeater {
                            model: AppCatalog.categories
                            delegate: GroupButton {
                                required property string modelData
                                required property int index
                                toggled: AppCatalog.selectedCategory === modelData
                                bounce: true
                                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                    : Appearance.auroraEverywhere ? "transparent"
                                    : Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                    : Appearance.colors.colLayer1Hover
                                colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                                    : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                    : Appearance.colors.colSecondaryContainer
                                colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                    : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                    : Appearance.colors.colSecondaryContainerHover
                                contentItem: RowLayout {
                                    spacing: 4
                                    MaterialSymbol {
                                        text: root._categoryIcon(modelData)
                                        iconSize: Appearance.font.pixelSize.small
                                        color: root.colText
                                    }
                                    StyledText {
                                        text: root._categoryLabel(modelData)
                                    }
                                }
                                onClicked: {
                                    catGroup.clickIndex = index + 1
                                    AppCatalog.selectedCategory = modelData
                                }
                            }
                        }
                    }
                }

                // Fade edge — right (more to scroll)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 24
                    visible: catFlickable.contentWidth > catFlickable.width
                        && catFlickable.contentX < (catFlickable.contentWidth - catFlickable.width - 2)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Appearance.colors.colLayer0 }
                    }
                }

                // Fade edge — left (scrolled past start)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 24
                    visible: catFlickable.contentX > 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Appearance.colors.colLayer0 }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // ─── PM info + refresh ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialSymbol {
                    text: "terminal"
                    iconSize: 14
                    color: root.colTextSecondary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root._pmLabel()
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                }
                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    enabled: !AppCatalog.checkingInstalled

                    colBackgroundHover: root.colBgHover

                    onClicked: AppCatalog.refresh()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 16
                        color: root.colText

                        RotationAnimation on rotation {
                            running: AppCatalog.checkingInstalled
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    StyledToolTip { text: Translation.tr("Refresh") }
                }
            }

            // ─── Loading state ───────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: AppCatalog.loading
                spacing: 10

                MaterialLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    loading: true
                    implicitSize: 32
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Loading catalog...")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colTextSecondary
                }
            }

            // ─── PM not detected ─────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: !AppCatalog.loading && AppCatalog.packageManager === "unknown"
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "error_outline"
                    iconSize: 48
                    color: root.colTextSecondary
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("No package manager detected")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colText
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Install pacman, apt, or dnf")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                }
            }

            // ─── Empty search state ──────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: !AppCatalog.loading && AppCatalog.packageManager !== "unknown"
                    && AppCatalog.filteredCatalog.length === 0
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: AppCatalog.searchQuery.length > 0 ? "search_off" : "inventory_2"
                    iconSize: 48
                    color: root.colTextSecondary
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: AppCatalog.searchQuery.length > 0
                        ? Translation.tr("No apps match your search")
                        : Translation.tr("No apps in this category")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colText
                }
            }

            // ─── App list ────────────────────────────────────────
            Repeater {
                model: (!AppCatalog.loading && AppCatalog.packageManager !== "unknown")
                    ? AppCatalog.filteredCatalog : []

                delegate: AppCard {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    app: modelData
                }
            }
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────

    function _categoryIcon(id: string): string {
        switch (id) {
            case "browsers": return "language"
            case "terminals": return "terminal"
            case "editors": return "edit"
            case "media": return "movie"
            case "communication": return "chat"
            case "system": return "settings"
            case "development": return "code"
            case "theming": return "palette"
            case "fonts": return "font_download"
            case "gaming": return "sports_esports"
            default: return "category"
        }
    }

    function _categoryLabel(id: string): string {
        switch (id) {
            case "browsers": return Translation.tr("Browsers")
            case "terminals": return Translation.tr("Terminals")
            case "editors": return Translation.tr("Editors")
            case "media": return Translation.tr("Media")
            case "communication": return Translation.tr("Communication")
            case "system": return Translation.tr("System")
            case "development": return Translation.tr("Development")
            case "theming": return Translation.tr("Theming")
            case "fonts": return Translation.tr("Fonts")
            case "gaming": return Translation.tr("Gaming")
            default: return id
        }
    }

    function _pmLabel(): string {
        const pm = AppCatalog.packageManager
        switch (pm) {
            case "pacman": {
                let label = "pacman"
                if (AppCatalog.hasAurHelper) label += " + " + AppCatalog.aurHelper
                if (AppCatalog.hasFlatpak) label += " + flatpak"
                return label
            }
            case "apt": return AppCatalog.hasFlatpak ? "apt + flatpak" : "apt"
            case "dnf": return AppCatalog.hasFlatpak ? "dnf + flatpak" : "dnf"
            case "unknown": return Translation.tr("Detecting...")
            default: return pm
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // INLINE COMPONENT: AppCard
    // ═════════════════════════════════════════════════════════════════

    component AppCard: RippleButton {
        id: card

        required property var app

        readonly property bool isInstalled: AppCatalog.isInstalled(card.app?.id ?? "")
        readonly property string installMethod: AppCatalog.getInstallMethod(card.app ?? {})
        readonly property bool isAvailable: AppCatalog.isAvailable(card.app ?? {})

        implicitHeight: 56
        buttonRadius: root.radius

        colBackground: "transparent"
        colBackgroundHover: root.colBgHover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
            : Appearance.colors.colLayer1Active

        onClicked: {
            if (card.isInstalled) {
                AppCatalog.removeApp(card.app?.id ?? "")
            } else if (card.isAvailable) {
                AppCatalog.installApp(card.app?.id ?? "")
            }
        }

        contentItem: RowLayout {
            spacing: 10

            // App icon — Quickshell.iconPath for theme lookup, MaterialSymbol fallback
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                property string _resolvedIcon: {
                    const di = card.app?.desktopIcon ?? ""
                    if (di.length === 0) return ""
                    const resolved = Quickshell.iconPath(di, "")
                    // Only use if it resolved to a real file path
                    if (resolved.length === 0) return ""
                    const str = resolved.toString()
                    if (str.startsWith("file://") || str.startsWith("/")) return resolved
                    return ""
                }

                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: parent._resolvedIcon
                    sourceSize: Qt.size(64, 64)
                    visible: parent._resolvedIcon.length > 0 && appIcon.status === Image.Ready
                    smooth: true
                    mipmap: true
                }

                // Fallback: Material Symbol from catalog
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: card.app?.icon ?? "apps"
                    iconSize: 24
                    color: root.colText
                }
            }

            // Info column
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: card.app?.name ?? ""
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Method / installed badge
                    Rectangle {
                        visible: card.installMethod.length > 0 || card.isInstalled
                        implicitWidth: badgeText.implicitWidth + 10
                        implicitHeight: badgeText.implicitHeight + 4
                        radius: height / 2
                        color: card.isInstalled
                            ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                                : Appearance.colors.colPrimaryContainer)
                            : (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                : Appearance.colors.colSecondaryContainer)

                        StyledText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: card.isInstalled
                                ? Translation.tr("Installed")
                                : card.installMethod
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: card.isInstalled
                                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimaryContainer
                                    : Appearance.colors.colOnPrimaryContainer)
                                : (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                                    : Appearance.colors.colOnSecondaryContainer)
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.app?.description ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Action icon
            MaterialSymbol {
                text: card.isInstalled ? "check_circle"
                    : card.isAvailable ? "download"
                    : "block"
                iconSize: 20
                fill: card.isInstalled ? 1 : 0
                color: card.isInstalled
                    ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                    : card.isAvailable ? root.colText
                    : root.colTextSecondary
            }
        }

        StyledToolTip {
            text: card.isInstalled ? Translation.tr("Click to remove")
                : card.isAvailable ? Translation.tr("Click to install via %1").arg(card.installMethod)
                : Translation.tr("Not available for your system")
        }
    }
}
