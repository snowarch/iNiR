pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    // Compact sidebars use screen-relative bands instead of raw content height.
    // The right control surface is deliberately taller than the left glance
    // surface, while a collapsed bottom group contracts it one step further.
    readonly property real leftFitMinRatio: 0.46
    readonly property real leftFitMaxRatio: 0.70
    readonly property real leftFitPreferredRatio: 0.58

    readonly property real rightFitCollapsedMinRatio: 0.44
    readonly property real rightFitCollapsedMaxRatio: 0.64
    readonly property real rightFitCollapsedPreferredRatio: 0.54

    readonly property real rightFitExpandedMinRatio: 0.58
    readonly property real rightFitExpandedMaxRatio: 0.80
    readonly property real rightFitExpandedPreferredRatio: 0.69

    function fitHeight(screenHeight: real, contentHeight: real,
            minRatio: real, maxRatio: real): real {
        const rawScreen = Number(screenHeight) || 0
        if (rawScreen <= 0) return 0
        const screen = rawScreen
        const content = Math.max(0, Number(contentHeight) || 0)
        const minHeight = screen * minRatio
        const maxHeight = screen * maxRatio
        return Math.round(Math.min(screen,
            Math.max(minHeight, Math.min(maxHeight, content))))
    }

    function leftFitHeight(screenHeight: real, contentHeight: real): real {
        // Fit means content-sized, not "stop at an arbitrary visual band".
        // The content owns scrolling when it genuinely exceeds the output.
        return fitHeight(screenHeight, contentHeight,
            leftFitMinRatio, 1)
    }

    function rightFitHeight(screenHeight: real, contentHeight: real,
            bottomCollapsed: bool): real {
        return bottomCollapsed
            ? fitHeight(screenHeight, contentHeight,
                rightFitCollapsedMinRatio, 1)
            : fitHeight(screenHeight, contentHeight,
                rightFitExpandedMinRatio, 1)
    }
}
