pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string currentMood: _initialMood()
    readonly property var moods: ["neutral", "sleepy", "hyper", "snarky", "contemplative"]
    readonly property var moodLines: ({})  // loaded by consumer from manifest
    readonly property bool enabled: Config.options?.mascot?.personality?.enabled ?? true
    readonly property int intervalMinutes: Math.max(5, Config.options?.mascot?.personality?.idleMoodIntervalMinutes ?? 30)

    // Initial mood from time of day
    function _initialMood(): string {
        const h = (new Date()).getHours()
        if (h >= 1 && h < 6) return "sleepy"
        if (h >= 6 && h < 11) return "hyper"
        if (h >= 11 && h < 17) return "snarky"
        if (h >= 17 && h < 22) return "contemplative"
        return "sleepy"  // 22-1
    }

    function setMood(mood: string): void {
        if (moods.includes(mood)) {
            currentMood = mood
            console.log(`[MascotMood] mood set to ${mood}`)
        } else {
            console.warn(`[MascotMood] unknown mood: ${mood}`)
        }
    }

    Timer {
        id: moodTimer
        running: root.enabled
        repeat: true
        interval: root.intervalMinutes * 60000 * (0.75 + Math.random() * 0.5)
        onTriggered: {
            interval = root.intervalMinutes * 60000 * (0.75 + Math.random() * 0.5)
            const pick = root.moods[Math.floor(Math.random() * root.moods.length)]
            root.currentMood = pick
            console.log(`[MascotMood] mood rolled to ${pick}`)
        }
    }

    IpcHandler {
        target: "mascotMood"
        function set(mood: string): void { root.setMood(mood) }
        function current(): string { return root.currentMood }
    }
}
