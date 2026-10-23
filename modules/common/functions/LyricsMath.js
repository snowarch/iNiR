.pragma library

// SekaiPop's lyrics maths, our way. A lyrics file only says when a LINE starts, so its time is shared out over
// its words by syllable, at the pace this song is sung; "<mm:ss.xx>" word stamps (enhanced LRC) are used as they are.

// A blank stamp that follows a line by less than this is a breath, not an instrumental part.
var GAP_MIN = 3.5
var DEFAULT_RATE = 4.2
var ADLIB_SHARE = 0.6

var NOTICE = /\b(instrumental|pure music|no lyrics|without lyrics|no words|lyrics? (is |are )?(not|un)available)\b|纯音乐|純音樂/i

// A provider's made-up "lyric" for a song without words ("instrumental, please enjoy"): a few short lines at most.
function isNotice(lines) {
    var n = 0, total = 0, joined = ""
    for (var i = 0; i < (lines ? lines.length : 0); i++) {
        var s = String(lines[i].text || "")
        if (s === "" || s === "♪") continue
        n++; total += s.length; joined += s + " "
    }
    return n === 0 || (n <= 4 && total <= 60 && NOTICE.test(joined))
}

// "<00:12.40>want <00:12.90>you" -> the words and where each stamp falls in them (char offsets in the clean text).
function readWords(body) {
    var re = /<(\d+):(\d{1,2})(?:[.:](\d{1,3}))?>/g
    var src = String(body || "")
    if (src.indexOf("<") < 0) return { text: src.trim(), marks: [] }
    var text = "", marks = [], last = 0, m, at = null
    function add(chunk) {
        var s = chunk.replace(/\s+/g, " ")
        if (text === "" || text.charAt(text.length - 1) === " ") s = s.replace(/^ /, "")
        if (s === "") return
        if (at !== null) marks.push({ c: text.length, t: at })
        at = null
        text += s
    }
    while ((m = re.exec(src)) !== null) {
        add(src.slice(last, m.index))
        at = Number(m[1]) * 60 + Number(m[2]) + (m[3] ? Number(m[3]) / Math.pow(10, m[3].length) : 0)
        last = m.index + m[0].length
    }
    add(src.slice(last))
    return { text: text.replace(/ $/, ""), marks: marks }
}

function isCjk(c) {
    return (c >= 0x3040 && c <= 0x30ff) || (c >= 0x3400 && c <= 0x4dbf) || (c >= 0x4e00 && c <= 0x9fff)
        || (c >= 0xf900 && c <= 0xfaff) || (c >= 0xff66 && c <= 0xff9f) || (c >= 0xac00 && c <= 0xd7af)
}
function isKana(c) { return (c >= 0x3041 && c <= 0x30ff && c !== 0x30fb) || (c >= 0xff66 && c <= 0xff9f) }
function isSmallKana(c) { return "ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ".indexOf(String.fromCharCode(c)) >= 0 }

// Words with their place in the text: { s, from, to, adlib }. Text without spaces (Japanese, Chinese) goes in
// threes, so the fill moves once a beat or so instead of once a character. Brackets mark ad libs and stay drawn.
function tokens(text) {
    var s = String(text || "")
    var out = [], start = -1, cjk = false, paren = false
    function flush(end) {
        if (start >= 0) out.push({ s: s.slice(start, end), from: start, to: end, adlib: paren })
        start = -1; cjk = false
    }
    for (var i = 0; i < s.length; i++) {
        var ch = s.charAt(i), c = s.charCodeAt(i)
        if (/\s/.test(ch)) { flush(i); continue }
        if (ch === "(" || c === 0xff08) { flush(i); paren = true; start = i; continue }
        if (isCjk(c)) {
            if (start >= 0 && !cjk) flush(i)
            if (start < 0) start = i
            cjk = true
            var left = 0
            for (var j = i + 1; j < s.length && isCjk(s.charCodeAt(j)); j++) left++
            if (i + 1 - start >= 3 && left > 1) flush(i + 1)
        } else {
            if (cjk) flush(i)
            if (start < 0) start = i
        }
        if (ch === ")" || c === 0xff09) { flush(i + 1); paren = false }
    }
    flush(s.length)
    return out
}

// Syllables of a Latin word, near enough: vowel groups, less a silent final e and an "ed" that is not one.
function latinSyllables(w) {
    var s = String(w).toLowerCase().replace(/[^a-z0-9à-ÿ]/g, "")
    if (s === "") return 0
    if (/^[0-9]+$/.test(s)) return s.length
    var groups = s.match(/[aeiouyà-æè-ïò-öù-ü]+/g)
    var n = groups ? groups.length : 0
    if (n > 1 && /[^aeiouy]e$/.test(s) && !/[^aeiouy]le$/.test(s)) n--
    else if (n > 1 && /[^aeiouydt]ed$/.test(s)) n--
    return Math.max(1, n)
}

// Syllables or morae: a kana one, a kanji two beside kana (one in Chinese), a small kana none, Hangul one a block.
function units(word, kanji) {
    var total = 0, run = ""
    for (var i = 0; i < word.length; i++) {
        var c = word.charCodeAt(i)
        if (!isCjk(c)) { run += word.charAt(i); continue }
        if (run !== "") { total += latinSyllables(run); run = "" }
        if (isSmallKana(c)) continue
        total += isKana(c) || (c >= 0xac00 && c <= 0xd7af) ? 1 : kanji
    }
    return total + (run !== "" ? latinSyllables(run) : 0)
}
function kanjiWeight(text) {
    for (var i = 0; i < text.length; i++) if (isKana(text.charCodeAt(i))) return 2
    return 1
}
function lineUnits(text) {
    var toks = tokens(text), kw = kanjiWeight(text), total = 0
    for (var i = 0; i < toks.length; i++) total += units(toks[i].s, kw) * (toks[i].adlib ? ADLIB_SHARE : 1)
    return total
}

// How fast this song is sung, syllables a second: the middle of the lines another follows closely.
function songRate(lines) {
    var rates = []
    for (var i = 0; i + 1 < lines.length; i++) {
        var l = lines[i], nx = lines[i + 1]
        if (!l.text) continue
        var u = lineUnits(l.text), room = nx.time - l.time
        if (u >= 3 && room >= 0.8 && room <= 6.5) rates.push(u / (room * 0.92))
    }
    if (rates.length < 4) return DEFAULT_RATE
    rates.sort(function (a, b) { return a - b })
    return Math.max(2, Math.min(9, rates[rates.length >> 1]))
}

// How long a line is sung: its syllables at the song's pace, never past the next line by more than a held word.
function sungSpan(text, room, rate) {
    var raw = lineUnits(text) / (rate > 0 ? rate : DEFAULT_RATE)
    var want = (raw + 0.25) * 1.2
    if (!isFinite(room) || room <= 0) return want
    return Math.max(Math.min(room * 0.92, want), Math.min(room, 0.4))
}

// When each word is sung, as [{from, to}] in song seconds. Word stamps place the words they reach; the rest share
// out the time between stamps by length. Without stamps, by syllables, the last word held a little longer.
function wordTimes(text, marks, t0, dur) {
    var toks = tokens(text)
    var out = []
    if (toks.length === 0) return out
    var t1 = t0 + dur
    if (marks && marks.length > 0) {
        var total = text.length
        var timeAt = function (c) {
            var j = -1
            for (var m = 0; m < marks.length && marks[m].c <= c; m++) j = m
            if (j < 0) return marks[0].c > 0 ? t0 + (marks[0].t - t0) * c / marks[0].c : t0
            var a = marks[j], b = marks[j + 1]
            var bT = Math.max(a.t, b ? b.t : t1), bC = b ? b.c : total
            return bC <= a.c ? a.t : a.t + (bT - a.t) * (c - a.c) / (bC - a.c)
        }
        var prev = t0
        for (var k = 0; k < toks.length; k++) {
            var from = Math.max(prev, timeAt(toks[k].from))
            out.push({ from: from, to: Math.max(from, k + 1 < toks.length ? timeAt(toks[k + 1].from) : t1), a: toks[k].from, b: toks[k].to })
            prev = from
        }
        return out
    }
    var kw = kanjiWeight(text), w = [], sum = 0, lastMain = -1
    for (var i = 0; i < toks.length; i++) {
        w.push((units(toks[i].s, kw) + 0.35) * (toks[i].adlib ? ADLIB_SHARE : 1))
        if (!toks[i].adlib) lastMain = i
    }
    if (lastMain > 0) w[lastMain] *= 1.3
    for (i = 0; i < w.length; i++) sum += w[i]
    var acc = 0
    for (i = 0; i < toks.length; i++) {
        out.push({ from: t0 + dur * acc / sum, to: t0 + dur * (acc + w[i]) / sum, a: toks[i].from, b: toks[i].to })
        acc += w[i]
    }
    return out
}

// The stage: every line with when its words are sung, an intro and every long instrumental stretch as a gap
// line (no text) that the three dots fill.
function stage(lines) {
    var rate = songRate(lines)
    var out = []
    if (lines.length > 0 && lines[0].time >= GAP_MIN) out.push({ time: 0, text: "", gap: true, until: lines[0].time })
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i], next = lines[i + 1]
        var room = next ? next.time - l.time : Infinity
        if (!l.text || l.text === "♪") {
            // A blank stamp: a gap when it lasts, otherwise only the end of the line before.
            if (room >= GAP_MIN) out.push({ time: l.time, text: "", gap: true, until: next ? next.time : l.time + 8 })
            continue
        }
        var span = sungSpan(l.text, room, rate)
        out.push({ time: l.time, text: l.text, gap: false, words: wordTimes(l.text, l.marks, l.time, span), until: l.time + span })
        // Sung well before the next line starts: the stretch after it is an instrumental part.
        if (next && next.text && room - span - 0.6 >= GAP_MIN)
            out.push({ time: l.time + span + 0.6, text: "", gap: true, until: next.time })
    }
    return out
}

function indexAt(lines, t) {
    var lo = 0, hi = lines.length - 1, ans = -1
    while (lo <= hi) {
        var mid = (lo + hi) >> 1
        if (lines[mid].time <= t) { ans = mid; lo = mid + 1 } else hi = mid - 1
    }
    return ans
}
function smooth(u) {
    u = Math.max(0, Math.min(1, u))
    return u * u * (3 - 2 * u)
}
// The line that is on plus how far the next has climbed into its place: the climb takes the last `lead` seconds
// before it starts, at most 40 % of a short line.
function cursor(lines, t, lead) {
    var i = indexAt(lines, t)
    if (i + 1 < lines.length) {
        var nextT = lines[i + 1].time
        var ld = Math.min(lead, Math.max(0.05, (i >= 0 ? nextT - lines[i].time : Infinity) * 0.4))
        if (t > nextT - ld) return i + smooth((t - (nextT - ld)) / ld)
    }
    return i
}
// How far into the text the singing is, in characters (fractional inside the word being sung).
function sungTo(words, t) {
    if (!words || words.length === 0) return 0
    var at = 0
    for (var i = 0; i < words.length; i++) {
        var w = words[i]
        if (t < w.from) break
        var p = w.to > w.from ? Math.min(1, (t - w.from) / (w.to - w.from)) : 1
        at = w.a + (w.b - w.a) * p
    }
    return at
}
