.pragma library

// Strategy registry for resolving idle timeouts based on power state and config.
// Open for extension: new power strategies (e.g. low battery, presentation mode) can be
// added to STRATEGIES without modifying Idle.qml.

const DEFAULT_TIMEOUTS = {
    screenOffTimeout: 300,
    lockTimeout: 600,
    suspendTimeout: 0,
};

const BATTERY_DEFAULT_TIMEOUTS = {
    screenOffTimeout: 120,
    lockTimeout: 300,
    suspendTimeout: 600,
};

const STRATEGIES = [
    {
        name: "battery",
        applies: function(power) {
            return !!(power && power.profileEnabled && power.available && power.onBattery);
        },
        resolve: function(idleConfig) {
            const onBattery = idleConfig?.onBattery ?? {};
            return {
                screenOffTimeout: onBattery.screenOffTimeout ?? BATTERY_DEFAULT_TIMEOUTS.screenOffTimeout,
                lockTimeout: onBattery.lockTimeout ?? BATTERY_DEFAULT_TIMEOUTS.lockTimeout,
                suspendTimeout: onBattery.suspendTimeout ?? BATTERY_DEFAULT_TIMEOUTS.suspendTimeout,
            };
        }
    },
    {
        name: "ac",
        applies: function(_power) {
            return true;
        },
        resolve: function(idleConfig) {
            return {
                screenOffTimeout: idleConfig?.screenOffTimeout ?? DEFAULT_TIMEOUTS.screenOffTimeout,
                lockTimeout: idleConfig?.lockTimeout ?? DEFAULT_TIMEOUTS.lockTimeout,
                suspendTimeout: idleConfig?.suspendTimeout ?? DEFAULT_TIMEOUTS.suspendTimeout,
            };
        }
    }
];

function resolveTimeouts(idleConfig, powerState) {
    const power = {
        profileEnabled: idleConfig?.onBattery?.enable ?? false,
        available: powerState?.available ?? false,
        onBattery: powerState?.onBattery ?? false,
        percentage: powerState?.percentage ?? 100,
    };

    for (let i = 0; i < STRATEGIES.length; i++) {
        const strategy = STRATEGIES[i];
        if (strategy.applies(power)) {
            const timeouts = strategy.resolve(idleConfig);
            return {
                profile: strategy.name,
                isBatteryProfile: strategy.name === "battery",
                screenOffTimeout: timeouts.screenOffTimeout,
                lockTimeout: timeouts.lockTimeout,
                suspendTimeout: timeouts.suspendTimeout,
            };
        }
    }

    return {
        profile: "ac",
        isBatteryProfile: false,
        screenOffTimeout: DEFAULT_TIMEOUTS.screenOffTimeout,
        lockTimeout: DEFAULT_TIMEOUTS.lockTimeout,
        suspendTimeout: DEFAULT_TIMEOUTS.suspendTimeout,
    };
}

// Selects AC vs battery idle timeouts. FullyCharged on AC is not onBattery.
function useBatteryProfile(power) {
    return !!(power && power.profileEnabled && power.available && power.onBattery);
}

function pick(acValue, batteryValue, power) {
    return useBatteryProfile(power) ? batteryValue : acValue;
}
