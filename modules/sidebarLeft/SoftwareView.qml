pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
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
    readonly property color colBgHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall

    property string searchQuery: ""
    property string selectedCategory: "all"

    readonly property var categories: ["internet", "development", "gaming", "graphics", "office", "media", "system"]

    readonly property var filteredApps: {
        const q = root.searchQuery.toLowerCase().trim()
        const cat = root.selectedCategory
        const all = DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
        
        let filtered = all
        if (cat !== "all") {
            filtered = filtered.filter(app => {
                const appCats = Array.from(app.categories ?? []).map(c => c.toLowerCase())
                switch (cat) {
                    case "internet":
                        return appCats.some(c => c === "network" || c === "webbrowser" || c === "email" || c === "chat")
                    case "development":
                        return appCats.some(c => c === "development" || c === "ide" || c === "debugger" || c === "building")
                    case "gaming":
                        return appCats.some(c => c === "game" || c === "gaming" || c === "emulator")
                    case "graphics":
                        return appCats.some(c => c === "graphics" || c === "viewer" || c === "photography" || c === "design")
                    case "office":
                        return appCats.some(c => c === "office" || c === "dictionary" || c === "wordprocessor" || c === "spreadsheet")
                    case "media":
                        return appCats.some(c => c === "audiovideo" || c === "audio" || c === "video" || c === "player")
                    case "system":
                        return appCats.some(c => c === "system" || c === "settings" || c === "utility" || c === "terminal" || c === "filemanager")
                    default:
                        return false
                }
            })
        }
        if (q.length > 0) {
            filtered = filtered.filter(app => {
                const name = (app.name ?? "").toLowerCase()
                const desc = (app.comment ?? "").toLowerCase()
                const gName = (app.genericName ?? "").toLowerCase()
                return name.includes(q) || desc.includes(q) || gName.includes(q)
            })
        }
        return filtered.sort((a, b) => (a.name || "").localeCompare(b.name || ""))
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
                text: root.searchQuery
                onTextChanged: root.searchQuery = text
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
                            toggled: root.selectedCategory === "all"
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
                                root.selectedCategory = "all"
                            }
                        }

                        Repeater {
                            model: root.categories
                            delegate: GroupButton {
                                required property string modelData
                                required property int index
                                toggled: root.selectedCategory === modelData
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
                                    root.selectedCategory = modelData
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

            // ─── Empty search state ──────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: root.filteredApps.length === 0
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.searchQuery.length > 0 ? "search_off" : "inventory_2"
                    iconSize: 48
                    color: root.colTextSecondary
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.searchQuery.length > 0
                        ? Translation.tr("No apps match your search")
                        : Translation.tr("No apps in this category")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colText
                }
            }

            // ─── App list ────────────────────────────────────────
            Repeater {
                model: root.filteredApps

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
            case "internet": return "language"
            case "development": return "code"
            case "gaming": return "sports_esports"
            case "graphics": return "palette"
            case "office": return "edit_note"
            case "media": return "movie"
            case "system": return "settings"
            default: return "category"
        }
    }

    function _categoryLabel(id: string): string {
        switch (id) {
            case "internet": return Translation.tr("Internet")
            case "development": return Translation.tr("Development")
            case "gaming": return Translation.tr("Gaming")
            case "graphics": return Translation.tr("Graphics")
            case "office": return Translation.tr("Office")
            case "media": return Translation.tr("Media")
            case "system": return Translation.tr("System")
            default: return id
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // INLINE COMPONENT: AppCard
    // ═════════════════════════════════════════════════════════════════

    component AppCard: RippleButton {
        id: card

        required property var app

        implicitHeight: 56
        buttonRadius: root.radius

        colBackground: "transparent"
        colBackgroundHover: root.colBgHover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
            : Appearance.colors.colLayer1Active

        onClicked: {
            GlobalStates.sidebarLeftOpen = false
            card.app.execute()
        }

        contentItem: RowLayout {
            spacing: 10

            // App icon — resolve using AppSearch helper
            Item {
                id: iconContainer
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                SmartAppIcon {
                    id: appIcon
                    anchors.fill: parent
                    icon: card.app?.icon || card.app?.name || ""
                    fallback: "application-x-executable"
                    iconSize: 32
                    monochrome: false
                }

                Loader {
                    active: (Config.options?.sidebar?.software?.monochromeIcons ?? true) && appIcon.resolvedSource.includes(Config.options?.iconTheme ?? "yet-another-monochrome-icon-set")
                    anchors.fill: parent
                    sourceComponent: Item {
                        Desaturate {
                            id: desaturatedIcon
                            visible: false
                            anchors.fill: parent
                            source: appIcon
                            desaturation: 1.0
                        }
                        ColorOverlay {
                            anchors.fill: desaturatedIcon
                            source: desaturatedIcon
                            color: root.colText
                        }
                    }
                }
            }

            // Info column
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: card.app?.name ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: root.colText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    Layout.fillWidth: true
                    text: card.app?.comment ?? card.app?.genericName ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Action icon
            MaterialSymbol {
                text: "arrow_forward"
                iconSize: 20
                color: root.colTextSecondary
            }
        }

        StyledToolTip {
            text: Translation.tr("Launch %1").arg(card.app?.name ?? "")
        }
    }
}
