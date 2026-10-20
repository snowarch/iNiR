import QtQuick

// Typing on a page with a search field starts a search, wherever the focus is (GNOME Settings, Files): a letter no
// control takes reaches the page, and `take` sends it to the field. Shortcuts (Ctrl, Alt, Super), keys with no text
// and a leading space stay with the page.
//   Keys.onPressed: event => typeAhead.take(event)
QtObject {
    id: root

    required property TextInput field

    function take(event: var): bool {
        const text = String(event.text ?? "")
        if (text.length === 0 || root.field.activeFocus) return false
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false
        if (text.charCodeAt(0) < 32 || text.charCodeAt(0) === 127) return false
        if (text.trim().length === 0 && root.field.text.length === 0) return false
        root.field.forceActiveFocus()
        root.field.insert(root.field.cursorPosition, text)
        event.accepted = true
        return true
    }
}
