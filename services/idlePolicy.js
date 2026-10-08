.pragma library

function niriOffCommand(quotedInir) {
    return "'" + quotedInir + "' brightness sleepBegin"
}

function niriResumeCommand(quotedInir) {
    return "'" + quotedInir + "' brightness restoreAfterWake"
}

function commandUsesDrmPowerOff(command) {
    return /power-off-monitors|power-on-monitors|PowerOffMonitors|PowerOnMonitors/.test(command)
}
