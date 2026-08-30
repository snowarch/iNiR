import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import qs.services

AndroidQuickToggleButton {
    id: root

    toggled: VoiceSearch.running
    // Must stay clickable in edit mode even without an API key, otherwise
    // the toggle can never be unpinned.
    enabled: root.editMode || VoiceSearch.hasApiKey

    name: Translation.tr("Voice Search")
    statusText: {
        if (!VoiceSearch.hasApiKey) return Translation.tr("No API key")
        if (VoiceSearch.transcribing) return Translation.tr("Transcribing...")
        if (VoiceSearch.recording) return Translation.tr("Listening...")
        return Translation.tr("Google")
    }
    buttonIcon: VoiceSearch.running ? "hearing" : "keyboard_voice"

    StyledToolTip {
        text: Translation.tr("Voice search with Gemini | Requires API key")
    }

    mainAction: () => {
        VoiceSearch.toggle()
    }
}
