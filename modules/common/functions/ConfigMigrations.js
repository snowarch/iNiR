.pragma library

// Where keys of config.json live, by owner (his 10-31): the shell's sections hold behaviour every family shares, each
// family's subtree holds only what that family draws. People's files move here at load, before Config reads them,
// whatever path they arrived by (update, fresh install, git pull). A move whose source is gone is skipped; a target
// that already exists keeps its values and takes only what it lacks, so this runs safely on every start.

// [from, to]: one owner.
const moves = [
    ["bar.weather", "weather"],
    ["sidebar.translator", "translator"],
    ["sidebar.booru", "booru"],
    ["sidebar.wallhaven", "wallhaven"],
    ["sidebar.news", "news"],
    ["sidebar.animeSchedule", "animeSchedule"],
    ["sidebar.ytmusic", "ytmusic"],
    ["sidebar.screenTime", "screenTime"],
    ["dock.pinnedApps", "apps.pinned"],
    ["dock.ignoredAppRegexes", "apps.ignoredRegexes"],
    ["appearance.globalStyle", "material.style.globalStyle"],
    ["appearance.island", "material.style.island"],
    ["appearance.regalia", "material.style.regalia"],
    ["appearance.aurora", "material.style.aurora"],
    ["appearance.angelSubStyle", "material.style.angelSubStyle"],
    ["appearance.editorial", "material.style.editorial"],
    ["appearance.zzz", "material.style.zzz"],
    ["appearance.angel", "material.style.angel"],
    ["appearance.globalStyleCornerStyles", "material.style.globalStyleCornerStyles"],
    ["appearance.transparency", "material.style.transparency"],
    ["appearance.iiMotionProfile", "material.style.iiMotionProfile"],
    ["appearance.desaturation", "material.style.desaturation"],
    ["appearance.extraBackgroundTint", "material.style.extraBackgroundTint"],
    ["appearance.animationSpeed", "material.style.animationSpeed"],
    ["appearance.animationCurve", "material.style.animationCurve"],
    ["bar", "material.bar"],
    ["sidebar", "material.sidebar"],
    ["dock", "material.dock"],
    ["controlPanel", "material.controlPanel"],
    ["dashboard", "material.dashboard"],
    ["settingsUi", "material.settingsUi"],
    // behaviour that stayed inside Material's sections after the first split (10-31)
    ["material.bar.resources.tempCautionThreshold", "resources.tempCautionThreshold"],
    ["material.bar.resources.tempWarningThreshold", "resources.tempWarningThreshold"],
    ["material.bar.resources.memoryWarningThreshold", "resources.memoryWarningThreshold"],
    ["material.bar.resources.swapWarningThreshold", "resources.swapWarningThreshold"],
    ["material.bar.resources.cpuWarningThreshold", "resources.cpuWarningThreshold"],
    ["material.bar.resources.gpuWarningThreshold", "resources.gpuWarningThreshold"],
    ["material.bar.workspaces.invertScroll", "interactions.scrolling.invertWorkspaces"],
    ["material.sidebar.cornerOpen", "cornerOpen"]
];

// [from, [to...]]: a look two families shared becomes one value each, both starting from the shared one.
const copies = [
    ["lock.blur", ["material.lock.blur", "waffles.lock.blur"]],
    ["lock.centerClock", ["material.lock.centerClock", "waffles.lock.centerClock"]],
    ["lock.showLockedText", ["material.lock.showLockedText", "waffles.lock.showLockedText"]],
    ["lock.materialShapeChars", ["material.lock.materialShapeChars"]],
    ["lock.dim", ["material.lock.dim", "waffles.lock.dim"]],
    ["lock.clock", ["material.lock.clock", "waffles.lock.clock"]],
    ["lock.notifications", ["material.lock.notifications", "waffles.lock.notifications"]],
    ["lock.status", ["material.lock.status", "waffles.lock.status"]],
    ["lock.widgets", ["material.lock.widgets", "waffles.lock.widgets"]],
    ["notifications.position", ["material.notifications.position", "waffles.notifications.position"]],
    ["notifications.edgeMargin", ["material.notifications.edgeMargin", "waffles.notifications.edgeMargin"]],
    ["notifications.scaleOnHover", ["material.notifications.scaleOnHover", "waffles.notifications.scaleOnHover"]]
];

function _isObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

function _get(obj, path) {
    let node = obj;
    for (const key of path.split(".")) {
        if (!_isObject(node) || !(key in node)) return undefined;
        node = node[key];
    }
    return node;
}

function _set(obj, path, value) {
    const keys = path.split(".");
    let node = obj;
    for (const key of keys.slice(0, -1)) {
        if (!_isObject(node[key])) node[key] = {};
        node = node[key];
    }
    node[keys[keys.length - 1]] = value;
}

// Fills into from source where into has no value; into wins.
function _merge(into, from) {
    for (const key of Object.keys(from)) {
        if (!(key in into)) into[key] = from[key];
        else if (_isObject(into[key]) && _isObject(from[key])) _merge(into[key], from[key]);
    }
}

function _place(obj, path, value) {
    const existing = _get(obj, path);
    if (existing === undefined) _set(obj, path, value);
    else if (_isObject(existing) && _isObject(value)) _merge(existing, value);
}

function _remove(obj, path) {
    const keys = path.split(".");
    const parent = keys.length === 1 ? obj : _get(obj, keys.slice(0, -1).join("."));
    if (_isObject(parent)) delete parent[keys[keys.length - 1]];
}

// One size per widget instance (10-31): each family kept its own and a sync held them together; `sizeClass` takes the
// one on screen. Free sizes get a name that belongs to no family. Base entries nest `iris.size`, per-screen ones keep
// it as a flat key.
function _oneSize(entry, irisActive) {
    if (!_isObject(entry)) return false;
    let changed = false;
    const iris = entry["iris.size"] ?? (_isObject(entry.iris) ? entry.iris.size : undefined);
    const material = entry.materialSize;
    if (iris !== undefined || material !== undefined) {
        if (entry.sizeClass === undefined) entry.sizeClass = irisActive ? (iris ?? material) : (material ?? iris);
        delete entry["iris.size"];
        if (_isObject(entry.iris)) delete entry.iris.size;
        delete entry.materialSize;
        changed = true;
    }
    for (const [from, to] of [["materialWidth", "freeWidth"], ["materialHeight", "freeHeight"]]) {
        if (entry[from] === undefined) continue;
        if (entry[to] === undefined) entry[to] = entry[from];
        delete entry[from];
        changed = true;
    }
    return changed;
}

// v2.33's resize handles wrote `contentWidth/Height` over these factory sizes; a size that moved stays a free size.
const _factorySizes = {
    calendarUpcoming: [280, 240],
    dateBadge: [220, 140],
    dayProgress: [240, 240],
    editorial: [360, 240],
    japaneseTypography: [330, 600],
    mascot: [200, 0],
    newsTicker: [320, 92],
    notes: [240, 160],
    shape: [160, 160],
    systemMonitor: [320, 120],
    uptime: [250, 96],
    visualizer: [304, 104]
};
function _contentSize(key, entry) {
    if (!_isObject(entry)) return false;
    let changed = false;
    [["contentWidth", "freeWidth"], ["contentHeight", "freeHeight"]].forEach(([from, to], axis) => {
        if (entry[from] === undefined) return;
        if (entry[to] === undefined && entry[from] > 0 && entry[from] !== _factorySizes[key]?.[axis]) entry[to] = entry[from];
        delete entry[from];
        changed = true;
    });
    // The image's width and height fell back to `size`, 220 unless the person set it.
    if (key === "customImage" && entry.size !== undefined) {
        if (entry.size !== 220)
            for (const side of ["freeWidth", "freeHeight"])
                if (entry[side] === undefined) entry[side] = entry.size;
        delete entry.size;
        changed = true;
    }
    return changed;
}

// A widget's plate has one switch. iRiS's per-widget "Transparent" was a second one; the shared material keeps its
// own Transparent, which only says what widgets that never chose do.
function _onePlate(entry) {
    if (!_isObject(entry)) return false;
    const nested = _isObject(entry.iris) ? entry.iris.material : undefined;
    if ((entry["iris.material"] ?? nested) !== "clear") return false;
    entry.showBackground = false;
    delete entry["iris.material"];
    if (_isObject(entry.iris)) delete entry.iris.material;
    return true;
}

function _widgetSizes(obj) {
    const widgets = _get(obj, "background.widgets");
    if (!_isObject(widgets)) return false;
    const irisActive = obj.panelFamily === "iris";
    const pairs = Object.entries(widgets);
    if (_isObject(widgets.custom)) pairs.push(...Object.entries(widgets.custom));
    if (_isObject(widgets.mascotInstances)) pairs.push(...Object.values(widgets.mascotInstances).map(entry => ["mascot", entry]));
    for (const record of Array.isArray(widgets.outputOverrides) ? widgets.outputOverrides : [])
        if (_isObject(record?.widgets)) pairs.push(...Object.entries(record.widgets));
    return pairs.map(([key, entry]) => [_oneSize(entry, irisActive), _contentSize(key, entry), _onePlate(entry)]
        .some(moved => moved)).some(moved => moved);
}

// Moves the keys of a parsed config.json to their owners in place; true when anything moved.
// iRiS's factory look moved (one form, a lit card, glass on). A file carries the old factory values as written defaults,
// so those alone change, once (glass turned off later must stay off), and a value someone chose stays.
const factoryLook = 2;
// [since, path, old factory value, new one]: each step runs once, so a value picked after it stays.
const factoryValues = [
    [1, "iris.appearance.expandedRadius", 28, 22],
    [1, "iris.appearance.glass.mode", "off", "compositor"],
    [1, "iris.appearance.glass.edgeLight", 34, 14],
    [1, "iris.appearance.glass.edgeLine", 10, 0],
    // Marks speak as the widgets head themselves: the glyph alone in its colour.
    [2, "iris.appearance.icons.style", "iris", "glyph"],
];
function _factoryLook(obj) {
    if (!_isObject(_get(obj, "iris.appearance"))) return false;
    const at = Number(_get(obj, "iris.appearance.factoryLook") ?? 0);
    if (at >= factoryLook) return false;
    for (const [since, path, before, after] of factoryValues)
        if (since > at && _get(obj, path) === before) _set(obj, path, after);
    if (at < 1) {
        // The glass edge's own width became every body's rim; 1.5 was its factory value.
        const width = _get(obj, "iris.appearance.glass.edgeWidth");
        if (typeof width === "number" && width !== 1.5) _set(obj, "iris.appearance.theme.rimWidth", Math.max(1, Math.round(width)));
        _remove(obj, "iris.appearance.glass.edgeWidth");
    }
    _set(obj, "iris.appearance.factoryLook", factoryLook);
    return true;
}

function migrate(obj) {
    if (!_isObject(obj)) return false;
    let changed = _factoryLook(obj);
    changed = _widgetSizes(obj) || changed;
    for (const [from, to] of moves) {
        const value = _get(obj, from);
        if (value === undefined) continue;
        _place(obj, to, value);
        _remove(obj, from);
        changed = true;
    }
    for (const [from, targets] of copies) {
        const value = _get(obj, from);
        if (value === undefined) continue;
        for (const to of targets)
            _place(obj, to, JSON.parse(JSON.stringify(value)));
        _remove(obj, from);
        changed = true;
    }
    return changed;
}
