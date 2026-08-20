pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

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
        if (!section) return;
        var newList = collapsibleSections.slice();
        newList.push(section);
        collapsibleSections = newList;
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
        
        // Primero encontrar qué sección contiene el control
        for (var i = 0; i < collapsibleSections.length; i++) {
            var section = collapsibleSections[i];
            if (section && _isDescendantOf(control, section)) {
                targetSection = section;
                break;
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
        if (!meta || !meta.control)
            return -1;

        var pageIndex = meta.pageIndex !== undefined ? meta.pageIndex : -1;
        var pageName = meta.pageName || "";
        var section = meta.section || "";
        var label = meta.label || "";
        var description = meta.description || "";
        var providedKeywords = meta.keywords || [];
        
        var autoKeywords = _generateKeywords(label, section, description);
        var allKeywords = providedKeywords.concat(autoKeywords);

        var id = _nextId++;
        var entry = {
            id: id,
            control: meta.control,
            pageIndex: pageIndex,
            pageName: pageName,
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
        var q = String(query || "").toLowerCase().trim();
        if (!q.length)
            return [];

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var out = [];

        for (var i = 0; i < _entryStore.length; ++i) {
            var e = _entryStore[i];
            if (!e || _removedEntryIds[e.id] || !e.control)
                continue;
            var label = (e.label || "").toLowerCase();
            var desc = (e.description || "").toLowerCase();
            var page = (e.pageName || "").toLowerCase();
            var sect = (e.section || "").toLowerCase();
            var kw = (e.keywords || []).join(" ").toLowerCase();

            var score = 0;
            var matchCount = 0;
            var matchedTerms = [];

            for (var j = 0; j < terms.length; ++j) {
                var term = terms[j];
                var labelIdx = label.indexOf(term);
                var descIdx = desc.indexOf(term);
                var pageIdx = page.indexOf(term);
                var sectIdx = sect.indexOf(term);
                var kwIdx = kw.indexOf(term);

                if (labelIdx === -1 && descIdx === -1 && pageIdx === -1 && sectIdx === -1 && kwIdx === -1)
                    continue;

                matchCount++;
                matchedTerms.push(term);

                if (labelIdx === 0) score += 1000;
                else if (labelIdx > 0) score += 500 - Math.min(labelIdx, 100);

                if (descIdx === 0) score += 300;
                else if (descIdx > 0) score += 150 - Math.min(descIdx, 50);

                if (sectIdx === 0) score += 200;
                else if (sectIdx > 0) score += 100 - Math.min(sectIdx, 50);

                if (pageIdx === 0) score += 100;
                else if (pageIdx > 0) score += 50 - Math.min(pageIdx, 25);

                if (kwIdx >= 0) score += 400;
            }

            if (matchCount < terms.length)
                continue;

            var sectionGroup = "";
            if (e.pageName && e.section) {
                sectionGroup = e.pageName + " · " + e.section;
            } else if (e.section) {
                sectionGroup = e.section;
            } else if (e.pageName) {
                sectionGroup = e.pageName;
            }

            out.push({
                optionId: e.id,
                pageIndex: e.pageIndex,
                pageName: e.pageName,
                section: sectionGroup,
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
