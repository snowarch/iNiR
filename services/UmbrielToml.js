.pragma library

// TOML as Umbriel's config uses it: tables, arrays of tables, dotted and quoted keys, strings, numbers, booleans,
// arrays and inline tables. CompositorConfig reads every included file with parse() and merges them the way Umbriel
// does; the one file Settings owns is written back with stringify(). Dates stay text (Umbriel has none).

function parse(text) {
    const src = String(text ?? "")
    const root = {}
    let at = 0
    let table = root
    const fail = what => { throw new Error(`TOML: ${what} at ${at}`) }
    const blank = (lines) => {
        for (;;) {
            const c = src[at]
            if (c === " " || c === "\t" || c === "\r" || (lines && c === "\n")) at++
            else if (c === "#") { while (at < src.length && src[at] !== "\n") at++ }
            else return
        }
    }
    const quoted = () => {
        const q = src[at]
        const triple = src.substr(at, 3) === q + q + q
        at += triple ? 3 : 1
        if (triple && src[at] === "\n") at++
        let out = ""
        for (;;) {
            if (at >= src.length) fail("open string")
            if (triple ? src.substr(at, 3) === q + q + q : src[at] === q) { at += triple ? 3 : 1; return out }
            let c = src[at++]
            if (c === "\\" && q === '"') {
                const e = src[at++]
                if (e === "n") c = "\n"
                else if (e === "t") c = "\t"
                else if (e === "r") c = "\r"
                else if (e === "u" || e === "U") {
                    const len = e === "u" ? 4 : 8
                    c = String.fromCodePoint(parseInt(src.substr(at, len), 16))
                    at += len
                } else if (e === "\n") { while (/\s/.test(src[at] ?? "")) at++; continue }
                else c = e
            }
            out += c
        }
    }
    const key = () => {
        const parts = []
        for (;;) {
            blank(false)
            if (src[at] === '"' || src[at] === "'") parts.push(quoted())
            else {
                const from = at
                while (at < src.length && /[A-Za-z0-9_-]/.test(src[at])) at++
                if (at === from) fail("key")
                parts.push(src.slice(from, at))
            }
            blank(false)
            if (src[at] !== ".") return parts
            at++
        }
    }
    // A table reached through an array of tables is that array's last one.
    const step = (holder, name) => {
        let next = holder[name]
        if (next === undefined) next = holder[name] = {}
        if (Array.isArray(next)) next = next[next.length - 1]
        if (typeof next !== "object" || next === null) fail(`"${name}" is a value`)
        return next
    }
    const put = (holder, path, what) => {
        for (let i = 0; i < path.length - 1; i++) holder = step(holder, path[i])
        holder[path[path.length - 1]] = what
    }
    const value = () => {
        blank(false)
        const c = src[at]
        if (c === '"' || c === "'") return quoted()
        if (c === "[") {
            at++
            const list = []
            for (;;) {
                blank(true)
                if (src[at] === "]") { at++; return list }
                list.push(value())
                blank(true)
                if (src[at] === ",") at++
                else if (src[at] !== "]") fail("array")
            }
        }
        if (c === "{") {
            at++
            const made = {}
            for (;;) {
                blank(true)
                if (src[at] === "}") { at++; return made }
                const path = key()
                if (src[at] !== "=") fail("inline table")
                at++
                put(made, path, value())
                blank(true)
                if (src[at] === ",") at++
                else if (src[at] !== "}") fail("inline table")
            }
        }
        const from = at
        while (at < src.length && !/[,\]\}\n#]/.test(src[at])) at++
        const word = src.slice(from, at).trim()
        if (word === "true") return true
        if (word === "false") return false
        const plain = word.replace(/_/g, "")
        if (/^[+-]?(\d+)$/.test(plain) || /^0[xob][0-9a-fA-F]+$/.test(plain)) return Number(plain)
        if (/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(plain)) return Number(plain)
        if (/^[+-]?(inf|nan)$/.test(plain)) return plain.endsWith("nan") ? NaN : plain[0] === "-" ? -Infinity : Infinity
        if (word.length === 0) fail("value")
        return word
    }
    for (;;) {
        blank(true)
        if (at >= src.length) return root
        if (src[at] === "[") {
            const list = src[at + 1] === "["
            at += list ? 2 : 1
            const path = key()
            if (src.substr(at, list ? 2 : 1) !== (list ? "]]" : "]")) fail("table head")
            at += list ? 2 : 1
            let holder = root
            for (let i = 0; i < path.length - 1; i++) holder = step(holder, path[i])
            const last = path[path.length - 1]
            if (list) {
                if (!Array.isArray(holder[last])) holder[last] = []
                table = {}
                holder[last].push(table)
            } else table = step(holder, last)
            continue
        }
        const path = key()
        if (src[at] !== "=") fail("=")
        at++
        put(table, path, value())
        blank(false)
        if (at < src.length && src[at] !== "\n") fail("line end")
    }
}

function isTable(what) {
    return typeof what === "object" && what !== null && !Array.isArray(what)
}

// Umbriel's include rule: tables merge key by key, lists of rules pile up, anything else is the last file's.
function merge(base, over) {
    const out = Object.assign({}, base)
    for (const name of Object.keys(over ?? {})) {
        const a = out[name], b = over[name]
        if (isTable(a) && isTable(b)) out[name] = merge(a, b)
        else if (Array.isArray(a) && Array.isArray(b) && b.length > 0 && b.every(isTable)) out[name] = a.concat(b)
        else out[name] = b
    }
    return out
}

function get(holder, path) {
    for (const part of path) {
        if (!isTable(holder)) return undefined
        holder = holder[part]
    }
    return holder
}

// A copy of holder with path set; undefined removes the key and every table it leaves empty.
function set(holder, path, what) {
    const out = Object.assign({}, isTable(holder) ? holder : {})
    const name = path[0]
    if (path.length === 1) {
        if (what === undefined) delete out[name]
        else out[name] = what
        return out
    }
    const inner = set(out[name], path.slice(1), what)
    if (Object.keys(inner).length === 0) delete out[name]
    else out[name] = inner
    return out
}

function keyText(name) {
    return /^[A-Za-z0-9_-]+$/.test(name) ? name : JSON.stringify(String(name))
}

function valueText(what) {
    if (typeof what === "string") return JSON.stringify(what)
    if (typeof what === "boolean") return what ? "true" : "false"
    if (typeof what === "number") return Number.isFinite(what) ? String(what) : what !== what ? "nan" : what > 0 ? "inf" : "-inf"
    if (Array.isArray(what)) return "[" + what.map(valueText).join(", ") + "]"
    if (isTable(what)) return "{ " + Object.keys(what).map(name => `${keyText(name)} = ${valueText(what[name])}`).join(", ") + " }"
    return '""'
}

function stringify(root, head) {
    const lines = []
    if (head) lines.push(String(head).split("\n").map(line => ("# " + line).replace(/\s+$/, "")).join("\n"), "")
    const walk = (holder, path) => {
        const names = Object.keys(holder)
        const plain = names.filter(name => !isTable(holder[name]) && !(Array.isArray(holder[name]) && holder[name].length > 0 && holder[name].every(isTable)))
        if (path.length > 0 && plain.length > 0) lines.push(`[${path.map(keyText).join(".")}]`)
        for (const name of plain) lines.push(`${keyText(name)} = ${valueText(holder[name])}`)
        if (plain.length > 0) lines.push("")
        for (const name of names) {
            const inner = holder[name]
            if (isTable(inner)) walk(inner, path.concat([name]))
            else if (!plain.includes(name)) for (const entry of inner) {
                lines.push(`[[${path.concat([name]).map(keyText).join(".")}]]`)
                for (const field of Object.keys(entry)) lines.push(`${keyText(field)} = ${valueText(entry[field])}`)
                lines.push("")
            }
        }
    }
    walk(root ?? {}, [])
    return lines.join("\n").replace(/\n+$/, "") + "\n"
}
