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
    property int _nextId: 0

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

        entries = entries.concat([entry]);
        return id;
    }

    function unregisterControl(control) {
        if (!control)
            return;
        var newEntries = [];
        for (var i = 0; i < entries.length; ++i) {
            if (entries[i].control !== control)
                newEntries.push(entries[i]);
        }
        entries = newEntries;
    }

    function clear() {
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
                result = before + '<b>' + match + '</b>' + after;
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

        for (var i = 0; i < entries.length; ++i) {
            var e = entries[i];
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
        for (var i = 0; i < entries.length; ++i) {
            var e = entries[i];
            if (e.id === optionId) {
                var c = e.control;
                if (!c)
                    return;

                if (typeof c.focusFromSettingsSearch === "function") {
                    c.focusFromSettingsSearch();
                } else if (typeof c.forceActiveFocus === "function") {
                    c.forceActiveFocus();
                }
                return;
            }
        }
    }
    
    function getControlById(optionId) {
        for (var i = 0; i < entries.length; ++i) {
            var e = entries[i];
            if (e.id === optionId) {
                return e.control;
            }
        }
        return null;
    }
}
