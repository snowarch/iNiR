pragma Singleton

import QtQuick
import Quickshell
import qs.services

// How iNiR answers a miss: a search that found nothing, a wrong password. Each place keeps its own plain line and two
// of ours take turns with it, a touch of personality, never a joke at every step. The pick follows the session and the
// query's first letter, so it holds while someone types and changes between searches.
Singleton {
    id: root

    readonly property int salt: Math.floor(Math.random() * 3)

    function _turn(query: string): int {
        return (root.salt + (query.length > 0 ? query.charCodeAt(0) : 0)) % 3
    }

    // A search that found nothing: `plain` is the place's own line, already translated.
    function miss(plain: string, query: string): string {
        const q = String(query ?? "").trim()
        switch (root._turn(q)) {
        case 1: return q.length > 0 ? Translation.tr("“%1”? Never heard of it").arg(q) : Translation.tr("Nothing by that name")
        case 2: return q.length > 0 ? Translation.tr("Are you… sure about “%1”?").arg(q) : Translation.tr("Hmm. Nothing here")
        default: return plain
        }
    }

    function wrongPassword(plain: string): string {
        switch (root._turn("")) {
        case 1: return Translation.tr("Not quite. Try again")
        case 2: return Translation.tr("Nope. Caps Lock, maybe?")
        default: return plain
        }
    }
}
