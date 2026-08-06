pragma Singleton
import QtQuick
import qs.modules.common

// Exact InnerTune design constants — literal translation of
// app/src/main/java/com/zionhuang/music/constants/Dimensions.kt.
// Font sizes scale with the user's fontSizeScale; geometry is fixed per InnerTune spec.
QtObject {
    readonly property int navigationBarHeight: 80
    readonly property int miniPlayerHeight: 64
    readonly property int queuePeekHeight: 64
    readonly property int appBarHeight: 64

    readonly property int listItemHeight: 64
    readonly property int suggestionItemHeight: 56
    readonly property int searchFilterHeight: 48
    readonly property int listThumbnailSize: 48
    readonly property int gridThumbnailHeight: 128
    readonly property int smallGridThumbnailHeight: 92

    readonly property int albumThumbnailSize: 144

    readonly property int thumbnailCornerRadius: 6

    readonly property int playerHorizontalPadding: 32

    // Scrim alpha over an active (playing) thumbnail — InnerTune ActiveBoxAlpha (0.4f).
    readonly property real activeBoxAlpha: 0.4

    // Home rhythm + quick-picks (named so the Home layout traces every value here).
    readonly property int shelfSpacing: 4              // vertical gap between shelves
    readonly property int shelfEdgePadding: 6          // horizontal inset of a card row
    readonly property int homePlaceholderHeight: 220   // loading / empty state height
    readonly property int quickPicksColumnMax: 320     // upper bound for a Quick-picks column
    readonly property int gridCardCornerRadius: 12     // card hover/press surface rounding

    // Material3 type sizes used by Items.kt (sp → scaled px).
    readonly property int titleTextSize: Math.round(14 * Appearance.fontSizeScale)
    readonly property int subtitleTextSize: Math.round(12 * Appearance.fontSizeScale)

    // Upscale a thumbnail URL for large surfaces (player art / blurred backdrop). ytimg tiers
    // step down (0 sd → 1 hq → 2 original) since sd/maxres can 404; lh3/ggpht square covers get
    // a large square size param. Used by ITThumbnail(highRes) and the player background.
    function highResThumb(url, tier) {
        if (!url) return "";
        if (url.indexOf("googleusercontent.com") !== -1 || url.indexOf("ggpht.com") !== -1)
            return url.replace(/=w\d+-h\d+/, "=w544-h544");
        // ytimg: swap only the quality segment so the https:// prefix is preserved.
        if (/i\.ytimg\.com\/vi\/[^/]+\/[a-z]+default\.jpg/.test(url)) {
            const t = (tier || 0);
            const variant = t === 0 ? "sddefault" : (t === 1 ? "hqdefault" : "mqdefault");
            return url.replace(/\/[a-z]+default\.jpg/, "/" + variant + ".jpg");
        }
        return url;
    }
}
