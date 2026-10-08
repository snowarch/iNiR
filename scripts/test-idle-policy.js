#!/usr/bin/env node
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const file = path.resolve(__dirname, "../services/idlePolicy.js")
const src = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*/, "")
const ctx = {}
vm.runInNewContext(src, ctx)

function assert(cond, msg) {
    if (!cond) {
        console.error("fail:", msg)
        process.exit(1)
    }
}

const off = ctx.niriOffCommand("/home/dabi/.local/bin/inir")
const resume = ctx.niriResumeCommand("/home/dabi/.local/bin/inir")

assert(typeof off === "string" && off.length > 0, "niriOffCommand returns a command")
assert(typeof resume === "string" && resume.length > 0, "niriResumeCommand returns a command")
assert(!ctx.commandUsesDrmPowerOff(off), "off must not call niri power-off-monitors")
assert(!ctx.commandUsesDrmPowerOff(resume), "resume must not call niri power-on-monitors")
assert(off.includes("brightness sleepBegin"), "off still marks brightness asleep")
assert(resume.includes("brightness restoreAfterWake"), "resume restores brightness")

const idleQml = fs.readFileSync(path.resolve(__dirname, "../services/Idle.qml"), "utf8")
assert(!idleQml.includes("power-off-monitors"), "Idle.qml must not invoke niri power-off-monitors")
assert(!idleQml.includes("power-on-monitors"), "Idle.qml must not invoke niri power-on-monitors")
assert(idleQml.includes("IdlePolicy.niriOffCommand"), "Idle.qml uses idlePolicy for niri off")

const lockQml = fs.readFileSync(path.resolve(__dirname, "../modules/lock/Lock.qml"), "utf8")
assert(!lockQml.includes("Brightness.sleepBegin"), "lock activate must not power displays down")
assert(!/power-off-monitors/.test(lockQml), "Lock.qml must not invoke niri power-off-monitors")

for (const rel of ["../modules/lock/LockSurface.qml", "../modules/waffle/lock/WaffleLockSurface.qml"]) {
    const src = fs.readFileSync(path.resolve(__dirname, rel), "utf8")
    assert(!src.includes("z: 9999"), `${rel} must not paint a fake lock overlay`)
    assert(src.includes("Brightness.restoreAfterWake"), `${rel} restores power on input`)
}

console.log("ok")
