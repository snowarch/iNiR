pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: GlobalStates.japaneseLookupOpen
                && (GlobalStates.japaneseLookupScreen === "" || GlobalStates.japaneseLookupScreen === modelData.name)
            color: "transparent"
            WlrLayershell.namespace: "quickshell:japaneseLookup"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: 0
            anchors { left: true; top: true }

            readonly property var result: GlobalStates.japaneseLookupResult ?? ({})
            readonly property var firstTerm: result.terms?.[0] ?? null
            readonly property real edge: 12
            readonly property real gap: 14
            readonly property bool expanded: GlobalStates.japaneseLookupExpanded
            readonly property real cardWidth: expanded
                ? Math.min(620, Math.max(500, modelData.width * 0.42))
                : Math.min(420, Math.max(360, modelData.width * 0.27))
            readonly property real cardMaxHeight: expanded
                ? Math.min(700, modelData.height * 0.82)
                : Math.min(480, modelData.height * 0.62)
            readonly property real selectionLeft: Math.max(0, GlobalStates.japaneseLookupX)
            readonly property real selectionTop: Math.max(0, GlobalStates.japaneseLookupY)
            readonly property real selectionRight: selectionLeft + Math.max(0, GlobalStates.japaneseLookupWidth)
            readonly property real selectionBottom: selectionTop + Math.max(0, GlobalStates.japaneseLookupHeight)
            readonly property bool fitsRight: selectionRight + gap + cardWidth <= modelData.width - edge
            readonly property bool fitsLeft: selectionLeft - gap - cardWidth >= edge
            readonly property real desiredX: fitsRight
                ? selectionRight + gap
                : (fitsLeft ? selectionLeft - gap - cardWidth
                    : Math.max(edge, Math.min(selectionLeft + GlobalStates.japaneseLookupWidth / 2 - cardWidth / 2,
                        modelData.width - cardWidth - edge)))
            readonly property real desiredY: {
                if (fitsRight || fitsLeft)
                    return Math.max(edge, Math.min(selectionTop - 10, modelData.height - cardMaxHeight - edge))
                const below = selectionBottom + gap
                if (below + cardMaxHeight <= modelData.height - edge)
                    return below
                return Math.max(edge, selectionTop - cardMaxHeight - gap)
            }

            margins { left: Math.round(win.desiredX); top: Math.round(win.desiredY) }
            implicitWidth: cardWidth
            implicitHeight: Math.min(cardContent.implicitHeight + 28, cardMaxHeight)
            mask: Region { item: card }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: Math.max(14, Appearance.rounding.normal)
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    id: cardContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                Layout.fillWidth: true
                                text: win.result.surface || win.result.matched || Translation.tr("Japanese lookup")
                                font.pixelSize: Appearance.font.pixelSize.title
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: (win.result.reading ?? "").length > 0
                                text: {
                                    const headword = win.firstTerm?.expression ?? win.result.matched ?? ""
                                    const reading = win.result.reading ?? ""
                                    const romaji = win.result.romaji ?? ""
                                    const parts = []
                                    if (headword.length && headword !== win.result.surface) parts.push(headword)
                                    if (reading.length && reading !== headword) parts.push(reading)
                                    if (romaji.length) parts.push(romaji)
                                    return parts.join("  ·  ")
                                }
                                color: Appearance.colors.colPrimary
                                font.pixelSize: Appearance.font.pixelSize.normal
                                elide: Text.ElideRight
                            }
                        }

                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            onClicked: JapaneseDictionary.translateCurrent(win.expanded)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "translate"
                                iconSize: 17
                                color: JapaneseDictionary.translationText.length > 0
                                    ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                            StyledToolTip { text: Translation.tr("Translate selection") }
                        }

                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            onClicked: GlobalStates.japaneseLookupExpanded = !GlobalStates.japaneseLookupExpanded
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: win.expanded ? "close_fullscreen" : "open_in_full"
                                iconSize: 17
                                color: Appearance.colors.colSubtext
                            }
                            StyledToolTip { text: win.expanded ? Translation.tr("Compact view") : Translation.tr("Expand lookup") }
                        }

                        RippleButton {
                            implicitWidth: 30
                            implicitHeight: 30
                            onClicked: GlobalStates.japaneseLookupOpen = false
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 17
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: (win.result.deinflection ?? "").length > 0
                        spacing: 6
                        Rectangle {
                            radius: height / 2
                            color: Appearance.colors.colLayer2
                            implicitWidth: baseText.implicitWidth + 14
                            implicitHeight: 24
                            StyledText {
                                id: baseText
                                anchors.centerIn: parent
                                text: Translation.tr("Base form") + ` · ${win.result.deinflection}`
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: JapaneseDictionary.translationBusy
                            || JapaneseDictionary.translationText.length > 0
                            || JapaneseDictionary.translationError.length > 0
                        implicitHeight: translationColumn.implicitHeight + 16
                        radius: Math.max(9, Appearance.rounding.small)
                        color: Appearance.colors.colLayer2
                        ColumnLayout {
                            id: translationColumn
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 3
                            StyledText {
                                text: Translation.tr("Translation") + " · " + JapaneseDictionary.resolvedTranslationTarget().toUpperCase()
                                color: Appearance.colors.colPrimary
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: JapaneseDictionary.translationBusy
                                    ? Translation.tr("Translating…")
                                    : (JapaneseDictionary.translationText.length > 0
                                        ? JapaneseDictionary.translationText
                                        : JapaneseDictionary.translationError)
                                wrapMode: Text.WordWrap
                                color: JapaneseDictionary.translationError.length > 0
                                    ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: win.expanded && String(win.result.query ?? "").trim().length > 0
                        implicitHeight: originalColumn.implicitHeight + 16
                        radius: Math.max(9, Appearance.rounding.small)
                        color: Appearance.colors.colLayer2
                        ColumnLayout {
                            id: originalColumn
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 3
                            StyledText {
                                text: Translation.tr("Recognized text")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: win.result.query ?? ""
                                wrapMode: Text.WordWrap
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(definitionsColumn.implicitHeight, win.expanded ? 330 : 245)
                        contentWidth: width
                        contentHeight: definitionsColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        ColumnLayout {
                            id: definitionsColumn
                            width: parent.width
                            spacing: 7

                            Repeater {
                                model: (win.result.terms ?? []).slice(0, win.expanded ? 6 : 3)
                                ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 5

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: modelData.reading !== win.result.reading
                                        text: modelData.reading
                                        color: Appearance.colors.colPrimary
                                        font.pixelSize: Appearance.font.pixelSize.small
                                    }

                                    Repeater {
                                        model: (modelData.displayDefinitions ?? []).slice(0, win.expanded ? 8 : 4)
                                        Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: senseText.implicitHeight + 14
                                            radius: Math.max(8, Appearance.rounding.small)
                                            color: Appearance.colors.colLayer2

                                            StyledText {
                                                id: senseText
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.margins: 9
                                                text: modelData
                                                wrapMode: Text.WordWrap
                                                color: Appearance.colors.colOnLayer1
                                                font.pixelSize: Appearance.font.pixelSize.small
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: !win.firstTerm
                                spacing: 8
                                StyledText {
                                    Layout.fillWidth: true
                                    text: JapaneseDictionary.dictionaryCount === 0
                                        ? Translation.tr("Japanese dictionary is not installed yet.")
                                        : Translation.tr("No dictionary entry matched this OCR text.")
                                    wrapMode: Text.WordWrap
                                    color: Appearance.colors.colSubtext
                                }
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    visible: JapaneseDictionary.dictionaryCount === 0
                                    enabled: !JapaneseDictionary.busy
                                    materialIcon: "download"
                                    mainText: JapaneseDictionary.busy
                                        ? Translation.tr("Installing Jitendex…")
                                        : Translation.tr("Install Japanese dictionary (~37 MB)")
                                    onClicked: JapaneseDictionary.installRecommended()
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: (win.result.kanji?.length ?? 0) > 0
                        spacing: 6
                        Repeater {
                            model: (win.result.kanji ?? []).slice(0, 3)
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: Math.max(8, Appearance.rounding.small)
                                color: Appearance.colors.colLayer2
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 7
                                    StyledText {
                                        text: modelData.character
                                        font.pixelSize: Appearance.font.pixelSize.large
                                        color: Appearance.colors.colPrimary
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: (modelData.meanings ?? []).slice(0, 2).join(", ")
                                            elide: Text.ElideRight
                                            color: Appearance.colors.colOnLayer1
                                            font.pixelSize: Appearance.font.pixelSize.small
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: (modelData.onyomi ?? []).concat(modelData.kunyomi ?? []).slice(0, 3).join(" · ")
                                            elide: Text.ElideRight
                                            color: Appearance.colors.colSubtext
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: win.expanded
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Study decks")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                visible: JapaneseDictionary.studyDeckStatus.length > 0
                                text: JapaneseDictionary.studyDeckStatus
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { id: "kaishi", title: "Kaishi 1.5k", lang: "EN" },
                                    { id: "manabi", title: "Manabi 2.7k", lang: "EN" },
                                    { id: "niponismo", title: "Niponismo", lang: "ES" }
                                ]
                                RippleButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    enabled: !JapaneseDictionary.deckBusy
                                    onClicked: JapaneseDictionary.downloadStudyDeck(modelData.id)
                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        MaterialSymbol { text: "download"; iconSize: 15; color: Appearance.colors.colPrimary }
                                        StyledText { Layout.fillWidth: true; text: modelData.title; elide: Text.ElideRight; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.small }
                                        StyledText { text: modelData.lang; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smallest }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: win.firstTerm !== null
                        spacing: 7
                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const pitch = win.result.metadata?.pitch?.[0]?.data?.pitches?.[0]?.position
                                return pitch === undefined ? (win.firstTerm?.dictionary ?? "")
                                    : `${win.firstTerm?.dictionary ?? ""}  ·  Pitch ${pitch}`
                            }
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            elide: Text.ElideRight
                        }
                        RippleButton {
                            implicitWidth: 32
                            implicitHeight: 32
                            onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/clipboard-copy.sh"), win.result.surface || win.result.matched || ""])
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "content_copy"
                                iconSize: 16
                                color: Appearance.colors.colPrimary
                            }
                        }
                        RippleButton {
                            visible: Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false
                            enabled: !JapaneseDictionary.busy
                                && (JapaneseDictionary.ankiAvailable || JapaneseDictionary.ankiState === "app_closed")
                            implicitWidth: JapaneseDictionary.ankiAvailable ? 86 : 112
                            implicitHeight: 32
                            onClicked: {
                                if (JapaneseDictionary.ankiAvailable) JapaneseDictionary.addCurrentToAnki()
                                else if (JapaneseDictionary.ankiState === "app_closed") JapaneseDictionary.launchAnki()
                            }
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: JapaneseDictionary.ankiAvailable
                                    ? Translation.tr("Add to Anki")
                                    : (JapaneseDictionary.ankiState === "app_closed"
                                        ? Translation.tr("Open Anki")
                                        : (JapaneseDictionary.ankiState === "not_installed"
                                            ? Translation.tr("Anki not installed")
                                            : Translation.tr("Check AnkiConnect")))
                                color: JapaneseDictionary.ankiAvailable || JapaneseDictionary.ankiState === "app_closed"
                                    ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            StyledToolTip { text: JapaneseDictionary.ankiConnectionStatus }
                        }
                    }
                }
            }
        }
    }
}

