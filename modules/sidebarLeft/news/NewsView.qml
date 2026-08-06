pragma ComponentBehavior: Bound
import qs
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "root:services"
import qs.services.deferred
import qs.services

Item {
    id: root

    // Boards: "local" (geo, via Weather location) / "top" / one topic per entry.
    readonly property var boards: {
        const result = [
            { key: "local", topic: "", label: Translation.tr("Local"), icon: "place" },
            { key: "top", topic: "", label: Translation.tr("Top"), icon: "trending_up" }
        ]
        const topicLabels = {
            "WORLD": Translation.tr("World"),
            "NATION": Translation.tr("Nation"),
            "BUSINESS": Translation.tr("Business"),
            "TECHNOLOGY": Translation.tr("Technology"),
            "ENTERTAINMENT": Translation.tr("Entertainment"),
            "SCIENCE": Translation.tr("Science"),
            "SPORTS": Translation.tr("Sports"),
            "HEALTH": Translation.tr("Health")
        }
        NewsService.topics.forEach(t => result.push({ key: "topic", topic: t, label: topicLabels[t] ?? t, icon: "" }))
        return result
    }

    readonly property string configMode: Config.options?.sidebar?.news?.mode ?? "local"
    readonly property string configTopic: Config.options?.sidebar?.news?.topic ?? "WORLD"
    readonly property int currentBoardIndex: {
        for (let i = 0; i < boards.length; i++) {
            if (boards[i].key === configMode && (configMode !== "topic" || boards[i].topic === configTopic))
                return i
        }
        return 0
    }

    function fetchCurrent() {
        NewsService.fetch(root.configMode, root.configTopic)
    }

    function refreshCurrent() {
        NewsService.refresh(root.configMode, root.configTopic)
    }

    Component.onCompleted: fetchCurrent()
    // When Weather resolves the location after startup, the "local" board
    // upgrades from the top-stories fallback to the real geo feed.
    Connections {
        target: NewsService
        function onLocalCityChanged() {
            if (root.configMode === "local")
                root.fetchCurrent()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Board selector
        StyledFlickable {
            Layout.fillWidth: true
            implicitHeight: boardRow.implicitHeight
            contentWidth: boardRow.implicitWidth
            clip: true

            RowLayout {
                id: boardRow
                spacing: 4

                Repeater {
                    model: root.boards
                    delegate: GroupButton {
                        required property var modelData
                        required property int index

                        buttonText: modelData.label
                        toggled: root.currentBoardIndex === index
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

                        onClicked: {
                            Config.setNestedValues({
                                "sidebar.news.mode": modelData.key,
                                "sidebar.news.topic": modelData.key === "topic" ? modelData.topic : root.configTopic
                            })
                            NewsService.fetch(modelData.key, modelData.topic)
                        }
                    }
                }
            }
        }

        // Content area
        Rectangle {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.auroraEverywhere ? "transparent"
                : Appearance.colors.colLayer1
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                : Appearance.auroraEverywhere ? 0 : 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                : Appearance.colors.colLayer0Border
            clip: true

            // Loading
            ColumnLayout {
                anchors.centerIn: parent
                visible: NewsService.loading && NewsService.articles.length === 0
                spacing: 10

                MaterialLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    loading: true
                    implicitSize: 48
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Loading...")
                    color: Appearance.colors.colSubtext
                }
            }

            // Error
            MaterialPlaceholderMessage {
                anchors.centerIn: parent
                maximumWidth: 340
                shown: NewsService.lastError.length > 0 && NewsService.articles.length === 0
                icon: "error"
                actionIcon: "refresh"
                text: Translation.tr("Error")
                explanation: NewsService.lastError
                helpfulAction: Kirigami.Action {
                    icon.name: "refresh"
                    text: Translation.tr("Retry")
                    onTriggered: root.refreshCurrent()
                }
            }

            // Empty
            MaterialPlaceholderMessage {
                anchors.centerIn: parent
                maximumWidth: 340
                shown: !NewsService.loading && NewsService.lastError.length === 0 && NewsService.articles.length === 0
                icon: "newspaper"
                text: Translation.tr("No news")
                explanation: Translation.tr("Try a different board")
            }

            ScrollEdgeFade {
                z: 1
                target: listView
                vertical: true
                fadeSize: 25
                color: ColorUtils.transparentize(Appearance.colors.colShadow, 0.5)
            }

            StyledListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 6
                visible: NewsService.articles.length > 0
                spacing: 4
                clip: true

                model: NewsService.articles

                delegate: RippleButton {
                    id: articleButton
                    required property var modelData
                    width: listView.width
                    implicitHeight: articleColumn.implicitHeight + 16
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colLayer1Hover

                    onClicked: NewsService.openArticle(modelData)

                    contentItem: ColumnLayout {
                        id: articleColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 3

                        StyledText {
                            Layout.fillWidth: true
                            text: articleButton.modelData.title
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: [articleButton.modelData.source, NewsService.formatTime(articleButton.modelData.timestamp)]
                                .filter(s => s && s.length > 0).join(" • ")
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                onDragEnded: {
                    if (verticalOvershoot > 60)
                        root.refreshCurrent()
                }
            }

            // Refresh indicator
            MaterialLoadingIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                visible: NewsService.loading && NewsService.articles.length > 0
                loading: true
                implicitSize: 32
            }
        }

        // Footer
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                text: root.configMode === "local" && NewsService.localCity.length > 0
                    ? NewsService.localCity
                    : root.boards[root.currentBoardIndex].label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                enabled: !NewsService.loading

                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer2Hover

                onClicked: root.refreshCurrent()

                contentItem: MaterialSymbol {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1

                    RotationAnimation on rotation {
                        running: NewsService.loading && GlobalStates.sidebarLeftOpen
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) refreshIcon.rotation = 0
                    }
                }

                StyledToolTip { text: Translation.tr("Refresh") }
            }
        }
    }
}
