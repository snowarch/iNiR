#!/usr/bin/env node
const fs = require("fs")
const path = require("path")

function assert(cond, msg) {
    if (!cond) {
        console.error("fail:", msg)
        process.exit(1)
    }
}

function positionHead(src) {
    const i = src.indexOf("onPositionChanged")
    assert(i >= 0, "onPositionChanged missing")
    return src.slice(i, i + 280)
}

const ii = fs.readFileSync(path.resolve(__dirname, "../modules/lock/LockSurface.qml"), "utf8")
const waffle = fs.readFileSync(path.resolve(__dirname, "../modules/waffle/lock/WaffleLockSurface.qml"), "utf8")
for (const [name, src] of [["ii", ii], ["waffle", waffle]]) {
    const head = positionHead(src)
    assert(head.includes("restoreAfterWake"), `${name} pointer while asleep must restoreAfterWake`)
    assert(!/if \(Brightness\.asleep\)\s*\n\s*return/.test(head), `${name} must not ignore asleep pointer`)
}

const lockQml = fs.readFileSync(path.resolve(__dirname, "../modules/lock/Lock.qml"), "utf8")
const surface = lockQml.slice(lockQml.indexOf("WlSessionLockSurface"))
const beforeLoader = surface.slice(0, surface.indexOf("Loader {"))
assert(beforeLoader.includes("Rectangle"), "lock surface must paint opaque fill before Loader")
assert(beforeLoader.includes("colLayer0"), "fill uses colLayer0 not niri red")
assert(!beforeLoader.includes("Timer {"), "no delay timer before first lock paint")

const activate = lockQml.slice(lockQml.indexOf("function activate()"), lockQml.indexOf("function prepareSleep()"))
assert(!activate.includes("sleepBegin"), "lock activate is not screen-off")

const fallback = lockQml.slice(lockQml.indexOf("id: fallbackTimer"), lockQml.indexOf("id: fallbackTimer") + 500)
assert(fallback.includes("Loader.Loading"), "fallback must not fire while lock qml is still loading")

const inirSh = fs.readFileSync(path.resolve(__dirname, "../scripts/inir"), "utf8")
const chunk = inirSh.slice(inirSh.indexOf("cleanup_orphans()"), inirSh.indexOf("cleanup_orphans()") + 5000)
assert(chunk.includes("swayidle"), "cleanup_orphans must reap leftover swayidle")

console.log("ok")
