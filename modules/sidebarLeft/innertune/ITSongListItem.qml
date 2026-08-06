import QtQuick
import qs.modules.sidebarLeft.innertune

// Literal translation of Items.kt SongListItem — subtitle is "artists • duration"
// (joinByBullet), thumbnail rounded at ThumbnailCornerRadius.
ITListItem {
    id: root
    property var song: ({})

    title: song?.title ?? ""
    subtitle: {
        const artist = song?.artist ?? "";
        const dur = root._timeString(song?.duration ?? 0);
        if (artist && dur) return artist + " • " + dur;
        return artist || dur;
    }
    thumbnailUrl: song?.thumbnail ?? ""

    function _timeString(seconds) {
        if (!seconds || seconds <= 0) return "";
        const s = Math.floor(seconds);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = n => (n < 10 ? "0" + n : "" + n);
        return h > 0 ? (h + ":" + pad(m) + ":" + pad(sec)) : (m + ":" + pad(sec));
    }
}
