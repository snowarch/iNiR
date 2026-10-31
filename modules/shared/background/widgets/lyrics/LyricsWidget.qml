pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.shared.background.widgets

// SekaiPop's lyrics, our way: the song that plays sung along on the desktop. The words come from LyricsService
// only (the face holds it while it shows); the face draws the stack and times the words.
AbstractBackgroundWidget {
    id: root

    configEntryName: "lyrics"
    defaultConfig: ({
        placementStrategy: "free", widgetScale: 100, cornerRadius: -1, x: 520, y: 600
    })
    semanticPaletteControls: false
    widgetSurfaceEnabled: false
    needsColText: false
}
