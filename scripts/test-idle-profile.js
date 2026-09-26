#!/usr/bin/env node
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const profileFile = path.resolve(__dirname, "../modules/common/functions/idleProfile.js")
const assert = function(cond, msg) {
    if (!cond) {
        console.error("fail:", msg)
        process.exit(1)
    }
}

assert(fs.existsSync(profileFile), "idleProfile.js must exist")
const src = fs.readFileSync(profileFile, "utf8").replace(/^\.pragma library\s*/, "")
const ctx = {}
vm.runInNewContext(src, ctx)

const fullOnMains = ctx.resolveTimeouts({ onBattery: { enable: true } }, { available: true, onBattery: false, percentage: 100 })
assert(fullOnMains.profile === "ac", "full pack on mains resolves the ac profile")
assert(fullOnMains.isBatteryProfile === false, "full pack on mains is not the battery profile")
assert(fullOnMains.suspendTimeout === 0, "full pack on mains must not inherit battery suspendTimeout")
assert(fullOnMains.screenOffTimeout === 300, "full pack on mains keeps the ac screen off default")
assert(fullOnMains.lockTimeout === 600, "full pack on mains keeps the ac lock default")

const disabledProfile = ctx.resolveTimeouts({ onBattery: { enable: false } }, { available: true, onBattery: false, percentage: 100 })
assert(disabledProfile.profile === "ac", "on mains with the profile disabled still resolves ac")

const unplugged = ctx.resolveTimeouts({ onBattery: { enable: true } }, { available: true, onBattery: true, percentage: 40 })
assert(unplugged.profile === "battery", "discharging resolves the battery profile")
assert(unplugged.isBatteryProfile === true, "discharging reports the battery profile")
assert(unplugged.suspendTimeout === 600, "discharging uses the battery suspend default")
assert(unplugged.screenOffTimeout === 120, "discharging uses the battery screen off default")
assert(unplugged.lockTimeout === 300, "discharging uses the battery lock default")

const acConfig = ctx.resolveTimeouts({ screenOffTimeout: 900, lockTimeout: 1200, suspendTimeout: 0, onBattery: { enable: true } }, { available: true, onBattery: false, percentage: 100 })
assert(acConfig.screenOffTimeout === 900, "explicit ac screen off wins on mains")
assert(acConfig.lockTimeout === 1200, "explicit ac lock wins on mains")
assert(acConfig.suspendTimeout === 0, "explicit ac suspend wins on mains")

const batteryConfig = ctx.resolveTimeouts({ onBattery: { enable: true, screenOffTimeout: 60, lockTimeout: 120, suspendTimeout: 300 } }, { available: true, onBattery: true, percentage: 40 })
assert(batteryConfig.screenOffTimeout === 60, "explicit battery screen off wins when unplugged")
assert(batteryConfig.lockTimeout === 120, "explicit battery lock wins when unplugged")
assert(batteryConfig.suspendTimeout === 300, "explicit battery suspend wins when unplugged")

assert(ctx.useBatteryProfile({ profileEnabled: true, available: true, onBattery: true }) === true, "useBatteryProfile is true only when enabled, available and discharging")
assert(ctx.useBatteryProfile({ profileEnabled: true, available: true, onBattery: false }) === false, "useBatteryProfile is false on mains")
assert(ctx.useBatteryProfile({ profileEnabled: false, available: true, onBattery: true }) === false, "useBatteryProfile is false when the profile is disabled")
assert(ctx.useBatteryProfile({ profileEnabled: true, available: false, onBattery: true }) === false, "useBatteryProfile is false without a battery")
assert(ctx.useBatteryProfile(undefined) === false, "useBatteryProfile tolerates undefined")
assert(ctx.useBatteryProfile({}) === false, "useBatteryProfile tolerates an empty state")

const mainsPower = { profileEnabled: true, available: true, onBattery: false }
const batteryPower = { profileEnabled: true, available: true, onBattery: true }
assert(ctx.pick("ac", "batt", mainsPower) === "ac", "pick returns the ac value on mains")
assert(ctx.pick("ac", "batt", batteryPower) === "batt", "pick returns the battery value when discharging")

const idleQml = fs.readFileSync(path.resolve(__dirname, "../services/Idle.qml"), "utf8")
assert(idleQml.includes("idleProfile.js"), "Idle.qml imports idleProfile.js")
assert(idleQml.includes("Battery.onBattery"), "Idle.qml resolves timeouts from Battery.onBattery")
assert(!idleQml.includes("!Battery.isPluggedIn"), "Idle.qml must not classify power with !Battery.isPluggedIn")
assert(!idleQml.includes("Battery.isPluggedIn"), "Idle.qml must not read Battery.isPluggedIn at all")

const batteryQml = fs.readFileSync(path.resolve(__dirname, "../services/Battery.qml"), "utf8")
assert(batteryQml.includes("onBattery"), "Battery.qml defines onBattery")

console.log("ok")
