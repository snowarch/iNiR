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

// Moves the keys of a parsed config.json to their owners in place; true when anything moved.
function migrate(obj) {
    if (!_isObject(obj)) return false;
    let changed = false;
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
