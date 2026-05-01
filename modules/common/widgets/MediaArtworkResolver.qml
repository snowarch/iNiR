pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

QtObject {
    id: root

    property string sourceUrl: ""
    property string title: ""
    property string artist: ""
    property string album: ""
    property string cacheDirectory: Directories.coverArt
    property int localReloadPasses: 8
    property bool ready: false
    property string displaySource: ""

    readonly property string normalizedSourceUrl: root._normalizeUrl(root.sourceUrl)
    readonly property bool isLocalFile: root.normalizedSourceUrl.startsWith("file://")
    readonly property bool isDataUri: root.normalizedSourceUrl.startsWith("data:")
    readonly property bool isRemote: root.normalizedSourceUrl.startsWith("http://") || root.normalizedSourceUrl.startsWith("https://")
    readonly property string metadataKey: [root.normalizedSourceUrl, root.title, root.artist, root.album].join("\u001f")
    readonly property string localFilePath: root.isLocalFile ? root._pathFromFileUrl(root.normalizedSourceUrl) : ""
    readonly property string localCachedArtFileName: root.isLocalFile && root.localFilePath.length > 0 ? root._cacheFileName(root.metadataKey, root.localFilePath) : ""
    readonly property string localCachedArtFilePath: root.localCachedArtFileName.length > 0 ? `${root.cacheDirectory}/${root.localCachedArtFileName}` : ""
    readonly property bool localFileInCache: root.localFilePath.length > 0 && root.localFilePath.startsWith(`${root.cacheDirectory}/`)
    readonly property string artFileName: root.isRemote && root.normalizedSourceUrl.length > 0 ? root._cacheFileName(root.metadataKey, root.normalizedSourceUrl) : ""
    readonly property string artFilePath: root.artFileName.length > 0 ? `${root.cacheDirectory}/${root.artFileName}` : ""

    property int _generation: 0
    property int _retryCount: 0
    readonly property int _maxRetries: 3
    property int _localReloadsLeft: 0
    property bool _completed: false
    property string _pendingDisplaySource: ""
    property int _pendingDisplayGeneration: 0
    property int _pendingDisplayChecksLeft: 0

    function _normalizeUrl(url): string {
        if (!url)
            return "";

        const value = url.toString();
        if (!value.length)
            return "";

        if (value.startsWith("data:") && value.length > 100000)
            return "";

        if (value.startsWith("/"))
            return "file://" + value;

        return value;
    }

    function _pathFromFileUrl(url: string): string {
        if (!url.startsWith("file://"))
            return "";

        const cleanUrl = url.split("?")[0].split("#")[0];
        const path = cleanUrl.replace(/^file:\/\/localhost/, "").replace(/^file:\/\//, "");
        return decodeURIComponent(path.startsWith("/") ? path : "/" + path);
    }

    function _cacheFileName(key: string, path: string): string {
        return `${Qt.md5(key)}${root._imageExtension(path)}`;
    }

    function _imageExtension(path: string): string {
        const cleanPath = (path ?? "").toLowerCase().split("?")[0].split("#")[0];
        const match = cleanPath.match(/\.(png|jpe?g|webp|gif|bmp|svg)$/);
        return match ? match[0] : ".jpg";
    }

    function _cacheBust(url: string): string {
        if (!url)
            return "";

        const value = url.toString();
        if (value.startsWith("data:"))
            return value;

        const separator = value.indexOf("?") >= 0 ? "&" : "?";
        return `${value}${separator}inir_art=${Qt.md5(root.metadataKey + ":" + root._generation)}`;
    }

    function _setReadySource(url: string): void {
        root._generation += 1;
        const generation = root._generation;
        const value = url.toString();
        const nextSource = root._cacheBust(value);

        if (value.startsWith("file://")) {
            root._pendingDisplaySource = nextSource;
            root._pendingDisplayGeneration = generation;
            root._pendingDisplayChecksLeft = 5;
            if (!root.displaySource.length)
                root.ready = false;
            fileSourceReadyChecker.running = false;
            fileSourcePublishTimer.restart();
            return;
        }

        if (root.ready && root.displaySource === nextSource)
            return;

        root.ready = true;
        root.displaySource = nextSource;
    }

    function _stopWorkers(): void {
        if (!root._completed)
            return;

        artExistsChecker.running = false;
        artworkDownloader.running = false;
        localFileCacher.running = false;
        localExistsChecker.running = false;
        fileSourceReadyChecker.running = false;
        retryTimer.stop();
        localReloadTimer.stop();
        fileSourcePublishTimer.stop();
    }

    function _reset(preserveDisplay: bool): void {
        root._stopWorkers();
        if (preserveDisplay) {
            root.ready = root.displaySource.length > 0;
        } else {
            root.ready = false;
            root.displaySource = "";
        }
        root._pendingDisplaySource = "";
        root._pendingDisplayGeneration = 0;
        root._pendingDisplayChecksLeft = 0;
        root._retryCount = 0;
        root._localReloadsLeft = root.localReloadPasses;
    }

    function _publishLocalFile(): void {
        if (root.localFileInCache || !root.localCachedArtFilePath.length) {
            root._setReadySource(root.normalizedSourceUrl);
            return;
        }

        localFileCacher.sourceFilePath = root.localFilePath;
        localFileCacher.artFilePath = root.localCachedArtFilePath;
        localFileCacher.running = false;
        localFileCacher.running = true;
    }

    function refresh(): void {
        const url = root.normalizedSourceUrl;
        if (!url.length) {
            root._reset(false);
            return;
        }

        if (root.isDataUri) {
            root._setReadySource(url);
            return;
        }

        if (root.isLocalFile) {
            if (!root.localFilePath.length) {
                root._setReadySource(url);
                return;
            }

            localExistsChecker.filePath = root.localFilePath;
            localExistsChecker.running = false;
            localExistsChecker.running = true;
            return;
        }

        if (root.isRemote && root.artFilePath.length > 0) {
            artExistsChecker.artFilePath = root.artFilePath;
            artExistsChecker.running = false;
            artExistsChecker.running = true;
            return;
        }

        root._setReadySource(url);
    }

    onMetadataKeyChanged: {
        if (!root._completed)
            return;

        root._reset(root.normalizedSourceUrl.length > 0);
        root.refresh();
    }

    onCacheDirectoryChanged: {
        if (!root._completed)
            return;

        root._reset(false);
        root.refresh();
    }

    Component.onCompleted: {
        root._completed = true;
        root._localReloadsLeft = root.localReloadPasses;
        root.refresh();
    }

    property var localReloadTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: {
            if (!root.normalizedSourceUrl.length || !root.isLocalFile)
                return;

            root.refresh();
        }
    }

    property var fileSourcePublishTimer: Timer {
        interval: 120
        repeat: false
        onTriggered: {
            if (root._pendingDisplayGeneration !== root._generation || !root._pendingDisplaySource.length)
                return;

            fileSourceReadyChecker.filePath = root._pathFromFileUrl(root._pendingDisplaySource);
            fileSourceReadyChecker.checkedGeneration = root._pendingDisplayGeneration;
            fileSourceReadyChecker.running = false;
            fileSourceReadyChecker.running = true;
        }
    }

    property var fileSourceReadyChecker: Process {
        property string filePath: ""
        property int checkedGeneration: 0

        command: ["/usr/bin/bash", "-c", `
            path="$1"
            if [ -z "$path" ]; then exit 1; fi
            [ -s "$path" ] || exit 1
            size1=$(/usr/bin/stat -c%s -- "$path" 2>/dev/null) || exit 1
            /usr/bin/sleep 0.2
            [ -s "$path" ] || exit 1
            size2=$(/usr/bin/stat -c%s -- "$path" 2>/dev/null) || exit 1
            [ "$size1" = "$size2" ] || exit 1
        `, "_", filePath]

        onExited: (exitCode, exitStatus) => {
            if (checkedGeneration !== root._pendingDisplayGeneration || checkedGeneration !== root._generation)
                return;
            if (filePath !== root._pathFromFileUrl(root._pendingDisplaySource))
                return;

            if (exitCode === 0) {
                root.ready = true;
                root.displaySource = root._pendingDisplaySource;
                root._pendingDisplaySource = "";
                root._pendingDisplayGeneration = 0;
                root._pendingDisplayChecksLeft = 0;
            } else if (root._pendingDisplayChecksLeft > 0) {
                root._pendingDisplayChecksLeft -= 1;
                fileSourcePublishTimer.restart();
            } else if (!root.displaySource.length) {
                root.ready = false;
            }
        }
    }

    property var retryTimer: Timer {
        interval: 350 * Math.max(1, root._retryCount)
        repeat: false
        onTriggered: root.refresh()
    }

    property var localExistsChecker: Process {
        property string filePath: ""

        command: ["/usr/bin/test", "-s", filePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && exitCode !== 1)
                return;

            if (filePath !== root.localFilePath)
                return;

            if (exitCode === 0) {
                root._localReloadsLeft = 0;
                root._publishLocalFile();
            } else if (root._localReloadsLeft > 0) {
                root._localReloadsLeft -= 1;
                localReloadTimer.restart();
            }
        }
    }

    property var localFileCacher: Process {
        property string sourceFilePath: ""
        property string artFilePath: ""

        command: ["/usr/bin/bash", "-c", `
            src="$1"
            out="$2"
            dir="$3"
            if [ -z "$src" ] || [ -z "$out" ]; then exit 1; fi
            if [ "$src" = "$out" ]; then exit 0; fi
            [ -s "$src" ] || exit 1
            mkdir -p "$dir"
            tmp="$out.tmp.$$"
            /usr/bin/cp -f -- "$src" "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" "$out" || { rm -f "$tmp"; exit 1; }
        `, "_", sourceFilePath, artFilePath, root.cacheDirectory]

        onExited: (exitCode) => {
            if (sourceFilePath !== root.localFilePath || artFilePath !== root.localCachedArtFilePath)
                return;

            if (exitCode === 0) {
                root._setReadySource(Qt.resolvedUrl(artFilePath));
            } else if (!root.displaySource.length) {
                root.ready = false;
            }
        }
    }

    property var artExistsChecker: Process {
        property string artFilePath: ""

        command: ["/usr/bin/test", "-s", artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && exitCode !== 1)
                return;

            if (artFilePath !== root.artFilePath)
                return;

            if (exitCode === 0) {
                root._setReadySource(Qt.resolvedUrl(artFilePath));
            } else {
                artworkDownloader.targetFile = root.normalizedSourceUrl;
                artworkDownloader.artFilePath = artFilePath;
                artworkDownloader.running = false;
                artworkDownloader.running = true;
            }
        }
    }

    property var artworkDownloader: Process {
        property string targetFile: ""
        property string artFilePath: ""

        command: ["/usr/bin/bash", "-c", `
            target="$1"
            out="$2"
            dir="$3"
            if [ -z "$target" ] || [ -z "$out" ]; then exit 1; fi
            if [ -s "$out" ]; then exit 0; fi
            mkdir -p "$dir"
            tmp="$out.tmp.$$"
            /usr/bin/curl -sSL --connect-timeout 4 --max-time 12 "$target" -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" "$out" || { rm -f "$tmp"; exit 1; }
        `, "_", targetFile, artFilePath, root.cacheDirectory]

        onExited: (exitCode) => {
            if (artFilePath !== root.artFilePath)
                return;

            if (exitCode === 0) {
                root._retryCount = 0;
                root._setReadySource(Qt.resolvedUrl(artFilePath));
            } else if (root._retryCount < root._maxRetries) {
                root._retryCount += 1;
                retryTimer.restart();
            }
        }
    }
}
