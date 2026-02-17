import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarLeft.translator
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Translator widget with the `trans` commandline tool.
 */
Item {
    id: root

    // Sizes
    property real padding: 4

    // Widgets
    property var inputField: inputCanvas.inputTextArea

    // Widget variables
    property bool translationFor: false // Indicates if the translation is for an autocorrected text
    property string translatedText: ""
    property var languages: ["auto"]

    // Options
    property string targetLanguage: Config.options?.language?.translator?.targetLanguage ?? "en"
    property string sourceLanguage: Config.options?.language?.translator?.sourceLanguage ?? "auto"
    property string hostLanguage: targetLanguage

    // States
    property bool showLanguageSelector: false
    property bool languageSelectorTarget: false // true for target language, false for source language

    function showLanguageSelectorDialog(isTargetLang: bool) {
        root.languageSelectorTarget = isTargetLang;
        root.showLanguageSelector = true
    }

    onFocusChanged: (focus) => {
        if (focus && root.inputField) {
            // Defer focus to next event loop tick to ensure the item is in a window
            Qt.callLater(() => root.inputField.forceActiveFocus());
        }
    }

    Timer {
        id: translateTimer
        interval: Config.options?.sidebar?.translator?.delay ?? 500
        repeat: false
        onTriggered: () => {
            if (root.inputField.text.trim().length > 0) {
                translateProc.running = false;
                translateProc.running = true; // Restart the process
            } else {
                root.translatedText = "";
            }
        }
    }

    Process {
        id: translateProc
        command: [
            "/usr/bin/trans",
            "-no-theme",
            "-no-bidi",
            "-source",
            root.sourceLanguage,
            "-target",
            root.targetLanguage,
            "-no-ansi",
            root.inputField.text.trim()
        ]
        stdout: StdioCollector {
            id: translateCollector
            onStreamFinished: {
                // Split into sections by double newlines
                const buffer = translateCollector.text || "";
                const sections = buffer.trim().split(/\n\s*\n/);
                // Extract translated text from second section
                root.translatedText = sections.length > 1 ? sections[1].trim() : "";
            }
        }
    }

    Process {
        id: getLanguagesProc
        command: ["/usr/bin/trans", "-list-languages", "-no-bidi"]
        stdout: StdioCollector {
            id: langsCollector
            onStreamFinished: {
                // Parse collected text into language list, ensure "auto" is first
                const text = String(langsCollector.text || "");
                if (!text || !text.trim()) {
                    root.languages = ["auto"];
                    return;
                }
                // Simple split + trim; JS array, no fancy constructs to keep QML happy.
                var parsed = text.split("\n");
                var result = ["auto"];
                for (var i = 0; i < parsed.length; ++i) {
                    var lang = String(parsed[i]).trim();
                    if (!lang || lang === "auto")
                        continue;
                    if (result.indexOf(lang) === -1)
                        result.push(lang);
                }
                try {
                    root.languages = result;
                } catch (e) {
                    // Keep the initial ["auto"] default and avoid spamming the full error
                    console.warn("[Translator] Failed to set languages list, keeping ['auto'] as fallback");
                }
            }
        }
        Component.onCompleted: running = true
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: contentColumn.implicitHeight

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent

                LanguageSelectorButton { // Target language button
                    id: targetLanguageButton
                    displayText: root.targetLanguage
                    onClicked: {
                        root.showLanguageSelectorDialog(true);
                    }
                }

                TextCanvas { // Content translation
                    id: outputCanvas
                    isInput: false
                    placeholderText: Translation.tr("Translation goes here...")
                    property bool hasTranslation: (root.translatedText.trim().length > 0)
                    text: hasTranslation ? root.translatedText : ""
                    GroupButton {
                        id: copyButton
                        baseWidth: height
                        buttonRadius: Appearance.rounding.small
                        enabled: outputCanvas.displayedText.trim().length > 0
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            iconSize: Appearance.font.pixelSize.larger
                            text: "content_copy"
                            color: copyButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                        }
                        onClicked: {
                            Quickshell.clipboardText = outputCanvas.displayedText
                        }
                    }
                    GroupButton {
                        id: searchButton
                        baseWidth: height
                        buttonRadius: Appearance.rounding.small
                        enabled: outputCanvas.displayedText.trim().length > 0
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            iconSize: Appearance.font.pixelSize.larger
                            text: "travel_explore"
                            color: searchButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                        }
                        onClicked: {
                            let url = (Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q=") + outputCanvas.displayedText;
                            for (let site of (Config.options?.search?.excludedSites ?? [])) {
                                url += ` -site:${site}`;
                            }
                            Qt.openUrlExternally(url);
                        }
                    }
                }

            }    
        }

        LanguageSelectorButton { // Source language button
            id: sourceLanguageButton
            displayText: root.sourceLanguage
            onClicked: {
                root.showLanguageSelectorDialog(false);
            }
        }

        TextCanvas { // Content input
            id: inputCanvas
            isInput: true
            placeholderText: Translation.tr("Enter text to translate...")
            onInputTextChanged: {
                translateTimer.restart();
            }
            GroupButton {
                id: pasteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "content_paste"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = Quickshell.clipboardText
                }
            }
            GroupButton {
                id: deleteButton
                baseWidth: height
                buttonRadius: Appearance.rounding.small
                enabled: inputCanvas.inputTextArea.text.length > 0
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.larger
                    text: "close"
                    color: deleteButton.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }
                onClicked: {
                    root.inputField.text = ""
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.showLanguageSelector
        visible: root.showLanguageSelector
        z: 9999
        sourceComponent: SelectionDialog {
            id: languageSelectorDialog
            titleText: Translation.tr("Select Language")
            items: root.languages
            defaultChoice: root.languageSelectorTarget ? root.targetLanguage : root.sourceLanguage
            onCanceled: () => {
                root.showLanguageSelector = false;
            }
            onSelected: (result) => {
                root.showLanguageSelector = false;
                if (!result || result.length === 0) return; // No selection made

                if (root.languageSelectorTarget) {
                    root.targetLanguage = result;
                    Config.options.language.translator.targetLanguage = result; // Save to config
                } else {
                    root.sourceLanguage = result;
                    Config.options.language.translator.sourceLanguage = result; // Save to config
                }

                translateTimer.restart(); // Restart translation after language change
            }
        }
    }
}
