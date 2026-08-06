/**
 * Safe arithmetic evaluator for the launcher's calc mode. A hand written
 * recursive descent parser walks a small grammar (+ - * / ^, parentheses,
 * decimals, and postfix % as divide by 100), so a typed query never reaches a
 * JS eval and can never run code. evaluate() returns { ok, value, display, ops }
 * where `ops` counts real operations, letting the launcher show a result only
 * when the query is an actual calculation and not a lone number or an app name.
 */

function tokenize(src) {
    var tokens = [];
    var i = 0;
    while (i < src.length) {
        var c = src[i];
        if (c === ' ' || c === '\t') { i++; continue; }
        if ((c >= '0' && c <= '9') || c === '.') {
            var j = i, dots = 0;
            while (j < src.length && ((src[j] >= '0' && src[j] <= '9') || src[j] === '.')) {
                if (src[j] === '.') dots++;
                j++;
            }
            if (dots > 1) return null;
            tokens.push({ t: 'num', v: parseFloat(src.slice(i, j)) });
            i = j;
            continue;
        }
        if ('+-*/^%()'.indexOf(c) >= 0) {
            tokens.push({ t: c });
            i++;
            continue;
        }
        return null;
    }
    return tokens;
}

function evaluate(src) {
    var fail = { ok: false, value: NaN, display: "", ops: 0 };
    if (!src || !src.trim()) return fail;
    var tokens = tokenize(src);
    if (!tokens || tokens.length === 0) return fail;

    var pos = 0;
    var ops = 0;

    function peek() { return tokens[pos]; }

    function parseExpr() {
        var v = parseTerm();
        for (;;) {
            var tok = peek();
            if (tok && tok.t === '+') { pos++; v = v + parseTerm(); ops++; }
            else if (tok && tok.t === '-') { pos++; v = v - parseTerm(); ops++; }
            else break;
        }
        return v;
    }
    function parseTerm() {
        var v = parsePower();
        for (;;) {
            var tok = peek();
            if (tok && tok.t === '*') { pos++; v = v * parsePower(); ops++; }
            else if (tok && tok.t === '/') { pos++; v = v / parsePower(); ops++; }
            else break;
        }
        return v;
    }
    function parsePower() {
        var base = parseUnary();
        var tok = peek();
        if (tok && tok.t === '^') { pos++; ops++; return Math.pow(base, parsePower()); }
        return base;
    }
    function parseUnary() {
        var tok = peek();
        if (tok && tok.t === '-') { pos++; return -parseUnary(); }
        if (tok && tok.t === '+') { pos++; return parseUnary(); }
        return parsePostfix();
    }
    function parsePostfix() {
        var v = parsePrimary();
        var tok = peek();
        if (tok && tok.t === '%') { pos++; ops++; v = v / 100; }
        return v;
    }
    function parsePrimary() {
        var tok = peek();
        if (!tok) throw "eof";
        if (tok.t === 'num') { pos++; return tok.v; }
        if (tok.t === '(') {
            pos++;
            var v = parseExpr();
            if (!(peek() && peek().t === ')')) throw "paren";
            pos++;
            return v;
        }
        throw "unexpected";
    }

    var value;
    try {
        value = parseExpr();
    } catch (e) {
        return fail;
    }
    if (pos !== tokens.length) return fail;
    if (typeof value !== 'number' || !isFinite(value)) return fail;
    if (ops < 1) return fail;

    var rounded = parseFloat(value.toPrecision(12));
    if (rounded === 0) rounded = 0;
    return { ok: true, value: rounded, display: String(rounded), ops: ops };
}
