pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    readonly property bool dynamicRegistrationEnabled:
        (Config.options?.settingsUi?.overlayStyle ?? "rail") !== "unified"

    // Lista de entradas de opciones de Settings
    // Cada entrada: { id, control, pageIndex, pageName, section, label, description, keywords }
    property var entries: []
    property var _entryStore: []
    property var _entryById: ({})
    property var _removedEntryIds: ({})
    property bool _entriesFlushScheduled: false
    property int _nextId: 0
    
    // Lista de CollapsibleSection registradas para manejo de expand/collapse
    property var collapsibleSections: []
    
    function registerCollapsibleSection(section) {
        if (!dynamicRegistrationEnabled) return;
        if (!section) return;
        var newList = collapsibleSections.slice();
        newList.push(section);
        collapsibleSections = newList;
    }

    function activatePageSection(pageItem, section): bool {
        if (!pageItem || !section)
            return false
        if (typeof pageItem.activateSettingsSearchSection === "function"
                && pageItem.activateSettingsSearchSection(section))
            return true
        const navigator = pageItem.settingsTaskNavigator ?? null
        return navigator && typeof navigator.activateSearchSection === "function"
            ? navigator.activateSearchSection(section)
            : false
    }
    
    function unregisterCollapsibleSection(section) {
        if (!section) return;
        var newList = [];
        for (var i = 0; i < collapsibleSections.length; i++) {
            if (collapsibleSections[i] !== section) {
                newList.push(collapsibleSections[i]);
            }
        }
        collapsibleSections = newList;
    }
    
    // Verifica si control es descendiente de section
    function _isDescendantOf(control, section) {
        var p = control;
        while (p) {
            if (p === section) return true;
            p = p.parent;
        }
        return false;
    }
    
    // Colapsa todas las secciones excepto la que contiene el control
    // Retorna la sección que fue expandida (o null)
    function expandSectionForControl(control) {
        if (!control) return null;

        var targetSection = null;

        var owner = control;
        while (owner) {
            if (owner.hasOwnProperty("expanded")
                    && typeof owner.focusFromSettingsSearch === "function") {
                targetSection = owner;
                owner.focusFromSettingsSearch();
                break;
            }
            owner = owner.parent;
        }

        // Primero encontrar qué sección contiene el control
        if (!targetSection) {
            for (var i = 0; i < collapsibleSections.length; i++) {
                var section = collapsibleSections[i];
                if (section && _isDescendantOf(control, section)) {
                    targetSection = section;
                    break;
                }
            }
        }

        // Ahora colapsar todas excepto la target y expandir la target
        for (var j = 0; j < collapsibleSections.length; j++) {
            var s = collapsibleSections[j];
            if (!s) continue;
            
            if (s === targetSection) {
                s.expanded = true;
            } else {
                s.expanded = false;
            }
        }
        
        return targetSection;
    }

    function activateTaskSectionForControl(control) {
        var taskSection = taskSectionForControl(control);
        var owner = null;
        var p = control;
        while (p) {
            if (taskSection && !owner && p.hasOwnProperty("activeSection"))
                owner = p;
            p = p.parent;
        }
        if (taskSection && owner)
            owner.activeSection = taskSection;
    }

    function taskSectionForControl(control): string {
        var p = control;
        while (p) {
            if (p.hasOwnProperty("settingsTaskSection") && p.settingsTaskSection)
                return String(p.settingsTaskSection);
            p = p.parent;
        }
        return "";
    }

    // Genera keywords automáticos a partir del texto
    function _generateKeywords(label: string, section: string, description: string): list<string> {
        var text = (label + " " + section + " " + description).toLowerCase();
        var words = text.split(/[\s\-_:,\.]+/).filter(w => w.length > 2);
        var unique = [];
        for (var i = 0; i < words.length; i++) {
            if (unique.indexOf(words[i]) === -1)
                unique.push(words[i]);
        }
        return unique;
    }

    function normalizeSearchText(value): string {
        return String(value || "")
            .toLowerCase()
            .replace(/[áàäâã]/g, "a")
            .replace(/[éèëê]/g, "e")
            .replace(/[íìïî]/g, "i")
            .replace(/[óòöôõ]/g, "o")
            .replace(/[úùüû]/g, "u")
            .replace(/ñ/g, "n")
            .replace(/[^a-z0-9+#.]+/g, " ")
            .trim()
    }

    function _termAlternatives(term): var {
        const aliases = ({
            "wifi": ["wifi", "wi fi", "wireless", "network", "networking"],
            "wireless": ["wireless", "wifi", "wi fi", "network"],
            "screen": ["screen", "display", "monitor", "output"],
            "display": ["display", "monitor", "output", "screen"],
            "monitor": ["monitor", "display", "output", "screen"],
            "record": ["record", "recording", "capture"],
            "recording": ["recording", "record", "capture"],
            "screenshot": ["screenshot", "snip", "capture"],
            "snip": ["snip", "screenshot", "capture"],
            "background": ["background", "wallpaper"],
            "wallpaper": ["wallpaper", "background"],
            "font": ["font", "typography", "typeface"],
            "typography": ["typography", "font", "typeface"],
            "sleep": ["sleep", "idle", "suspend"],
            "idle": ["idle", "sleep", "suspend"],
            "language": ["language", "locale"],
            "locale": ["locale", "language"],
            "startup": ["startup", "autostart", "launch"],
            "autostart": ["autostart", "startup", "launch"],
            "tray": ["tray", "system tray", "status notifier"],
            "blur": ["blur", "glass"],
            "glass": ["glass", "blur"]
        })
        var values = (aliases[term] ?? [term]).slice()
        if (term.length > 4 && term.endsWith("ies"))
            values.push(term.slice(0, -3) + "y")
        else if (term.length > 4 && term.endsWith("s"))
            values.push(term.slice(0, -1))

        const spelling = ({
            "colour": "color",
            "colours": "color",
            "center": "centre",
            "centre": "center",
            "lockscreen": "lock screen",
            "keybind": "shortcut",
            "keybinds": "shortcut",
            "shortcut": "keybind",
            "shortcuts": "keybind",
            "sound": "audio",
            "volume": "audio",
            "microphone": "mic",
            "mic": "microphone"
        })
        if (spelling[term])
            values.push(spelling[term])

        const unique = []
        for (let i = 0; i < values.length; ++i) {
            const value = String(values[i] || "")
            if (value.length > 0 && unique.indexOf(value) < 0)
                unique.push(value)
        }
        return unique
    }

    function buildStaticResults(query, sourceEntries): var {
        const q = normalizeSearchText(query)
        if (!q.length)
            return []

        const terms = q.split(/\s+/).filter(term => term.length > 0)
        const out = []
        const entriesToSearch = sourceEntries ?? []

        for (let i = 0; i < entriesToSearch.length; ++i) {
            const entry = entriesToSearch[i] ?? ({})
            const label = normalizeSearchText(entry.label)
            const description = normalizeSearchText(entry.description)
            const page = normalizeSearchText(entry.pageName)
            const section = normalizeSearchText(entry.section)
            const task = normalizeSearchText(entry.task)
            const keywords = normalizeSearchText((entry.keywords || []).join(" "))
            const fields = [label, description, page, section, task, keywords]
            let score = 0
            let matched = true

            for (let j = 0; j < terms.length; ++j) {
                const term = terms[j]
                const alternatives = _termAlternatives(term)
                let best = 0
                for (let a = 0; a < alternatives.length; ++a) {
                    const alt = normalizeSearchText(alternatives[a])
                    const labelIndex = label.indexOf(alt)
                    const sectionIndex = section.indexOf(alt)
                    const keywordIndex = keywords.indexOf(alt)
                    const descriptionIndex = description.indexOf(alt)
                    const pageIndex = page.indexOf(alt)
                    const taskIndex = task.indexOf(alt)
                    let local = 0
                    if (label === alt) local += 1800
                    else if (labelIndex === 0) local += 1200
                    else if (labelIndex > 0) local += 750 - Math.min(labelIndex, 120)
                    if (section === alt) local += 700
                    else if (sectionIndex >= 0) local += 450
                    if (keywordIndex >= 0) local += 350
                    if (descriptionIndex >= 0) local += 220
                    if (pageIndex >= 0) local += 160
                    if (taskIndex >= 0) local += 120
                    best = Math.max(best, local)
                }
                if (best <= 0) {
                    matched = false
                    break
                }
                score += best
            }

            if (!matched)
                continue

            if (label === q)
                score += 2600
            else if (label.indexOf(q) === 0)
                score += 1100

            const isSection = normalizeSearchText(entry.label) === normalizeSearchText(entry.section)
            out.push({
                pageIndex: entry.pageIndex,
                pageName: entry.pageName,
                panelFamily: entry.panelFamily || "",
                task: entry.task || "",
                section: entry.section || "",
                label: entry.label || "",
                labelHighlighted: highlightTerms(entry.label || "", terms),
                description: entry.description || "",
                descriptionHighlighted: highlightTerms(entry.description || "", terms),
                score: score + (entry.generated ? 0 : 120),
                isSection: isSection,
                generated: entry.generated === true
            })
        }

        out.sort((a, b) => b.score - a.score)
        return out
    }

    function findLoadedTarget(pageItem, label, section, isSection): var {
        if (!pageItem)
            return null
        const wanted = normalizeSearchText(label)
        const wantedSection = normalizeSearchText(section)
        if (!wanted.length && !wantedSection.length)
            return null

        let bestItem = null
        let bestScore = -1
        const sectionScore = function(item) {
            if (!wantedSection.length)
                return 0
            let p = item
            while (p && p !== pageItem) {
                if (p.hasOwnProperty("title")
                        && normalizeSearchText(p.title) === wantedSection)
                    return 80
                p = p.parent
            }
            return 0
        }
        const visit = function(item, depth) {
            if (!item || depth > 32)
                return

            let score = -1
            const title = item.hasOwnProperty("title") ? normalizeSearchText(item.title) : ""
            const text = item.hasOwnProperty("text") ? normalizeSearchText(item.text) : ""
            const mainText = item.hasOwnProperty("mainText") ? normalizeSearchText(item.mainText) : ""
            const placeholder = item.hasOwnProperty("placeholderText") ? normalizeSearchText(item.placeholderText) : ""

            if (isSection && wantedSection.length && title === wantedSection)
                score = 150
            if (wanted.length && title === wanted)
                score = Math.max(score, 140)
            if (wanted.length && text === wanted)
                score = Math.max(score, 130)
            if (wanted.length && mainText === wanted)
                score = Math.max(score, 130)
            if (wanted.length && placeholder === wanted)
                score = Math.max(score, 110)
            if (score >= 0)
                score += sectionScore(item)
            if (score >= 0 && typeof item.focusFromSettingsSearch === "function")
                score += 25
            if (score >= 0 && item.hasOwnProperty("settingsTaskSection"))
                score += 10

            if (score > bestScore) {
                bestScore = score
                bestItem = item
            }

            const children = item.children ?? []
            for (let i = 0; i < children.length; ++i)
                visit(children[i], depth + 1)
            if (item.hasOwnProperty("item") && item.item)
                visit(item.item, depth + 1)
        }
        visit(pageItem, 0)
        return bestItem
    }

    function revealLoadedSection(pageItem, section): bool {
        if (!pageItem || !section)
            return false
        const control = findLoadedTarget(pageItem, section, section, true)
        if (!control)
            return false
        if (control.hasOwnProperty("expanded") && !control.expanded)
            control.expanded = true
        if (typeof control.focusFromSettingsSearch === "function")
            control.focusFromSettingsSearch()
        return true
    }

    function _scheduleEntriesFlush(): void {
        if (_entriesFlushScheduled)
            return;
        _entriesFlushScheduled = true;
        Qt.callLater(() => root._flushEntries());
    }

    function _flushEntries(): void {
        _entriesFlushScheduled = false;

        var activeEntries = [];
        var activeById = {};
        for (var i = 0; i < _entryStore.length; i++) {
            var entry = _entryStore[i];
            if (!entry || _removedEntryIds[entry.id] || !entry.control)
                continue;
            activeEntries.push(entry);
            activeById[entry.id] = entry;
        }

        _entryStore = activeEntries;
        _entryById = activeById;
        _removedEntryIds = {};
        entries = activeEntries.slice();
    }

    function registerOption(meta) {
        if (!dynamicRegistrationEnabled)
            return -1;
        if (!meta || !meta.control)
            return -1;

        var pageIndex = meta.pageIndex !== undefined ? meta.pageIndex : -1;
        var pageName = meta.pageName || "";
        var section = meta.section || "";
        var label = meta.label || "";
        var description = meta.description || "";
        var task = meta.task || taskSectionForControl(meta.control);
        var providedKeywords = meta.keywords || [];
        
        var autoKeywords = _generateKeywords(label, section, description);
        var allKeywords = providedKeywords.concat(autoKeywords);

        var id = _nextId++;
        var entry = {
            id: id,
            control: meta.control,
            pageIndex: pageIndex,
            pageName: pageName,
            task: task,
            section: section,
            label: label,
            description: description,
            keywords: allKeywords
        };

        _entryStore.push(entry);
        _entryById[id] = entry;
        _scheduleEntriesFlush();
        return id;
    }

    function unregisterControl(control) {
        if (!control)
            return;

        var optionId = control.hasOwnProperty("settingsSearchOptionId")
            ? control.settingsSearchOptionId : -1;
        var indexedEntry = optionId >= 0 ? _entryById[optionId] : null;
        if (indexedEntry && indexedEntry.control === control) {
            _removedEntryIds[indexedEntry.id] = true;
            delete _entryById[optionId];
            _scheduleEntriesFlush();
            return;
        }

        for (var i = 0; i < _entryStore.length; ++i) {
            var entry = _entryStore[i];
            if (entry && !_removedEntryIds[entry.id] && entry.control === control) {
                _removedEntryIds[entry.id] = true;
                delete _entryById[entry.id];
            }
        }
        _scheduleEntriesFlush();
    }

    function clear() {
        _entryStore = [];
        _entryById = {};
        _removedEntryIds = {};
        entries = [];
        _nextId = 0;
    }

    // Simple highlight using indexOf (no regex backreferences)
    function highlightTerms(text: string, terms: list<string>): string {
        if (!text || !terms || terms.length === 0)
            return text;
        
        var result = text;
        for (var i = 0; i < terms.length; i++) {
            var term = terms[i];
            if (term.length < 2) continue;
            
            var lowerResult = result.toLowerCase();
            var lowerTerm = term.toLowerCase();
            var idx = lowerResult.indexOf(lowerTerm);
            if (idx >= 0) {
                var before = result.substring(0, idx);
                var match = result.substring(idx, idx + term.length);
                var after = result.substring(idx + term.length);
                result = before + '<b><u>' + match + '</u></b>' + after;
            }
        }
        return result;
    }

    function buildResults(query) {
        var q = normalizeSearchText(query);
        if (!q.length)
            return [];

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var out = [];

        for (var i = 0; i < _entryStore.length; ++i) {
            var e = _entryStore[i];
            if (!e || _removedEntryIds[e.id] || !e.control)
                continue;
            var label = normalizeSearchText(e.label);
            var desc = normalizeSearchText(e.description);
            var page = normalizeSearchText(e.pageName);
            var sect = normalizeSearchText(e.section);
            var kw = normalizeSearchText((e.keywords || []).join(" "));

            var score = 0;
            var matchCount = 0;
            var matchedTerms = [];

            for (var j = 0; j < terms.length; ++j) {
                var term = terms[j];
                var alternatives = _termAlternatives(term);
                var best = 0;
                for (var a = 0; a < alternatives.length; ++a) {
                    var alt = normalizeSearchText(alternatives[a]);
                    var labelIdx = label.indexOf(alt);
                    var descIdx = desc.indexOf(alt);
                    var pageIdx = page.indexOf(alt);
                    var sectIdx = sect.indexOf(alt);
                    var kwIdx = kw.indexOf(alt);
                    var local = 0;

                    if (label === alt) local += 1800;
                    else if (labelIdx === 0) local += 1000;
                    else if (labelIdx > 0) local += 500 - Math.min(labelIdx, 100);

                    if (descIdx === 0) local += 300;
                    else if (descIdx > 0) local += 150 - Math.min(descIdx, 50);

                    if (sectIdx === 0) local += 200;
                    else if (sectIdx > 0) local += 100 - Math.min(sectIdx, 50);

                    if (pageIdx === 0) local += 100;
                    else if (pageIdx > 0) local += 50 - Math.min(pageIdx, 25);

                    if (kwIdx >= 0) local += 400;
                    best = Math.max(best, local);
                }

                if (best <= 0)
                    continue;

                matchCount++;
                matchedTerms.push(term);
                score += best;
            }

            if (matchCount < terms.length)
                continue;

            if (label === q)
                score += 2600;
            else if (label.indexOf(q) === 0)
                score += 1100;

            out.push({
                optionId: e.id,
                pageIndex: e.pageIndex,
                pageName: e.pageName,
                task: e.task || "",
                section: e.section || "",
                label: e.label,
                labelHighlighted: highlightTerms(e.label, matchedTerms),
                description: e.description,
                descriptionHighlighted: highlightTerms(e.description, matchedTerms),
                score: score,
                matchCount: matchCount,
                matchedTerms: matchedTerms
            });
        }

        out.sort(function(a, b) {
            if (a.score !== b.score)
                return b.score - a.score;
            var pa = (a.pageIndex !== undefined && a.pageIndex >= 0) ? a.pageIndex : 9999;
            var pb = (b.pageIndex !== undefined && b.pageIndex >= 0) ? b.pageIndex : 9999;
            return pa - pb;
        });
        
        return out.slice(0, 50);
    }

    function focusOption(optionId) {
        var e = _entryById[optionId];
        var c = e ? e.control : null;
        if (!c)
            return;

        if (typeof c.focusFromSettingsSearch === "function") {
            c.focusFromSettingsSearch();
        } else if (typeof c.forceActiveFocus === "function") {
            c.forceActiveFocus();
        }
    }
    
    function findSectionControl(pageIndex, title) {
        var wanted = String(title || "").toLowerCase().trim();
        if (!wanted.length)
            return null;

        var loose = null;
        for (var i = 0; i < _entryStore.length; ++i) {
            var e = _entryStore[i];
            if (!e || _removedEntryIds[e.id] || !e.control)
                continue;
            if (e.pageIndex !== pageIndex)
                continue;
            var label = String(e.label || "").toLowerCase().trim();
            if (!label.length)
                continue;
            if (label === wanted)
                return e.control;
            if (!loose && (label.indexOf(wanted) >= 0 || wanted.indexOf(label) >= 0))
                loose = e.control;
        }
        return loose;
    }

    function getControlById(optionId) {
        var e = _entryById[optionId];
        return e ? e.control : null;
    }
}
