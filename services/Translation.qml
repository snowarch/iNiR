pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property var translations: ({})
    property var generatedTranslations: ({})
    property var activeTranslations: ({})
    property var availableLanguages: ["en_US"]
    property var availableGeneratedLanguages: []
    property var allAvailableLanguages: {
        const combined = new Set([...root.availableLanguages, ...root.availableGeneratedLanguages]);
        return Array.from(combined).sort();
    }
    property bool isScanning: scanLanguagesProcess.running
    property bool isLoading: false
    property string loadedLanguageCode: ""
    property int _loadGeneration: 0
    property string _activeLoadLocale: ""
    property bool _reloadQueued: false
    property var _pendingTranslations: ({})
    property var _pendingGeneratedTranslations: ({})
    property bool _pendingTranslationsReady: false
    property bool _pendingGeneratedReady: false
    property string translationKeepSuffix: "/*keep*/"
    property string translationsDir: Quickshell.shellPath("translations")
    property string generatedTranslationsDir: Directories.shellConfig + "/translations"

    property string languageCode: {
        var configLang = Config.options?.language?.ui ?? "auto";

        if (configLang !== "auto")
            return configLang;

        return Qt.locale().name;
    }
    // Names of days and months follow the language the shell speaks; formats tied to the region (12 or 24 hours, the
    // first day of the week, a numeric date) stay with the system's `Qt.locale()`, as on macOS.
    readonly property var locale: Qt.locale(root.languageCode)
    // The catalogue that serves languageCode: the exact one, else one for the same language
    // (es_MX reads the Spanish catalogue), else none and the English source.
    readonly property string catalogLocale: {
        const code = root.languageCode;
        const all = root.allAvailableLanguages;
        if (all.includes(code))
            return code;
        const language = code.split(/[_.@-]/)[0].toLowerCase();
        return all.find(locale => locale.split("_")[0].toLowerCase() === language) ?? code;
    }

    TranslationScanner {
        id: scanLanguagesProcess
        translationsDir: root.translationsDir
        onLanguagesScanned: (languages) => {
            root.availableLanguages = [...languages];
        }
    }

    TranslationScanner {
        id: scanGeneratedLanguagesProcess
        translationsDir: root.generatedTranslationsDir
        onLanguagesScanned: (languages) => {
            root.availableGeneratedLanguages = [...languages];
        }
    }

    onCatalogLocaleChanged: {
        print("[Translation] Language changed to", root.languageCode, "using", root.catalogLocale);
        root.reloadLanguage();
    }

    onAvailableLanguagesChanged: {
        root.reloadLanguage();
    }

    onAvailableGeneratedLanguagesChanged: {
        root.reloadLanguage();
    }

    function reloadLanguage() {
        if (root.isLoading) {
            root._reloadQueued = true;
            return;
        }

        const locale = root.catalogLocale;
        const generation = ++root._loadGeneration;
        root.isLoading = true;
        root._activeLoadLocale = locale;
        root._pendingTranslations = {};
        root._pendingGeneratedTranslations = {};
        root._pendingTranslationsReady = false;
        root._pendingGeneratedReady = false;
        translationFileView.beginLoad(locale, generation);
        generatedTranslationFileView.beginLoad(locale, generation);
    }

    function acceptTranslations(locale, generation, data, generated) {
        if (generation !== root._loadGeneration || locale !== root._activeLoadLocale)
            return;

        if (generated) {
            root._pendingGeneratedTranslations = data;
            root._pendingGeneratedReady = true;
        } else {
            root._pendingTranslations = data;
            root._pendingTranslationsReady = true;
        }

        if (!root._pendingTranslationsReady || !root._pendingGeneratedReady)
            return;

        if (locale === root.catalogLocale) {
            const combined = Object.assign({}, root._pendingGeneratedTranslations);
            const primary = root._pendingTranslations;
            for (const key in primary) {
                if (primary[key])
                    combined[key] = primary[key];
            }

            root.translations = root._pendingTranslations;
            root.generatedTranslations = root._pendingGeneratedTranslations;
            root.activeTranslations = combined;
            root.loadedLanguageCode = locale;
        } else {
            root._reloadQueued = true;
        }

        root.isLoading = false;
        root._activeLoadLocale = "";

        if (root._reloadQueued || root.loadedLanguageCode !== root.catalogLocale) {
            root._reloadQueued = false;
            Qt.callLater(root.reloadLanguage);
        }
    }

    TranslationReader {
        id: translationFileView
        translationsDir: root.translationsDir
        onContentLoaded: (locale, generation, data) => {
            root.acceptTranslations(locale, generation, data, false);
        }
    }

    TranslationReader {
        id: generatedTranslationFileView
        translationsDir: root.generatedTranslationsDir
        isGenerated: true
        onContentLoaded: (locale, generation, data) => {
            root.acceptTranslations(locale, generation, data, true);
        }
    }

    function tr(text) {
        // Special cases
        if (!text) return "";
        var key = text.toString();
        if (!root?.activeTranslations?.hasOwnProperty(key))
            return key;
        
        // Normal cases
        var translation = root.activeTranslations[key] || key;
        if (translation.endsWith(root.translationKeepSuffix)) {
            translation = translation.substring(0, translation.length - root.translationKeepSuffix.length).trim();
        }
        return translation;
    }

    function languageDisplayName(locale) {
        const names = {
            "ar_SA": "العربية",
            "de_DE": "Deutsch",
            "en_US": "English",
            "es_419": "Español (Latinoamérica)",
            "fr_FR": "Français",
            "he_HE": "עברית",
            "hi_IN": "हिन्दी",
            "id_ID": "Bahasa Indonesia",
            "it_IT": "Italiano",
            "ja_JP": "日本語",
            "kl_GL": "Kalaallisut",
            "ko_KR": "한국어",
            "pt_BR": "Português (Brasil)",
            "ru_RU": "Русский",
            "tr_TR": "Türkçe",
            "uk_UA": "Українська",
            "vi_VN": "Tiếng Việt",
            "zh_CN": "简体中文"
        };
        if (names[locale] !== undefined)
            return names[locale];
        // A language made with Gemini, or added by hand: the name Qt has for it in its own language.
        const own = String(Qt.locale(locale).nativeLanguageName ?? "");
        return own.length > 0 ? own.charAt(0).toUpperCase() + own.slice(1) : locale;
    }

    component TranslationScanner: Process {
        id: translationScanner
        required property string translationsDir
        signal languagesScanned(var languages)

        command: ["/usr/bin/find", translationScanner.translationsDir, "-maxdepth", "1", "-type", "f", "-name", "*.json", "-exec", "/usr/bin/basename", "{}", ".json", ";"]
        running: false

        stdout: StdioCollector {
            id: languagesCollector
            onStreamFinished: {
                const output = languagesCollector.text ?? "";
                const files = output.trim().length > 0
                    ? output.trim().split('\n').map(f => f.trim()).filter(f => f.length > 0)
                    : [];
                translationScanner.languagesScanned(files);
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                translationScanner.languagesScanned(["en_US"]);
            }
        }
    }

    Timer {
        id: scanDefer
        interval: 600
        repeat: false
        onTriggered: {
            scanLanguagesProcess.running = true
            scanGeneratedLanguagesProcess.running = true
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                scanDefer.start()
            }
        }
    }

    component TranslationReader: FileView {
        id: translationReader
        required property string translationsDir
        property string requestedLocale: ""
        property int requestedGeneration: 0
        property bool isGenerated: false
        signal contentLoaded(string locale, int generation, var data)
        printErrors: false

        function beginLoad(locale, generation) {
            translationReader.requestedLocale = locale;
            translationReader.requestedGeneration = generation;
            translationReader.reread();
        }

        function reread() { // Proper reload in case the file was incorrect before
            const langs = translationReader.isGenerated ? root.availableGeneratedLanguages : root.availableLanguages;
            if (!(langs ?? []).includes(translationReader.requestedLocale)) {
                translationReader.path = "";
                translationReader.contentLoaded(translationReader.requestedLocale, translationReader.requestedGeneration, {});
                return;
            }
            translationReader.path = "";
            translationReader.path = `${translationReader.translationsDir}/${translationReader.requestedLocale}.json`;
            translationReader.reload();
        }
        path: ""

        onLoaded: {
            var textContent = "";
            try {
                textContent = text();
                var jsonData = JSON.parse(textContent);
                translationReader.contentLoaded(translationReader.requestedLocale, translationReader.requestedGeneration, jsonData);
            } catch (e) {
                console.log("[Translation] Failed to load translations:", e);
                translationReader.contentLoaded(translationReader.requestedLocale, translationReader.requestedGeneration, {});
            }
        }
        onLoadFailed: error => {
            translationReader.contentLoaded(translationReader.requestedLocale, translationReader.requestedGeneration, {});
        }
    }
}
