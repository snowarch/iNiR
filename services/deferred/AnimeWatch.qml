pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services
import qs.services.deferred

/**
 * AnimeWatch — anime from the shell, with the installed CLI as the engine.
 *
 * With ani-cli, iNiR is the whole interface: scripts/inir-ani runs it with iNiR as
 * its menu (scripts/inir-ani-menu) and its player (scripts/inir-mpv), so every
 * question ani-cli asks comes here, and mpv hands its IPC socket to MpvIpc. Each
 * run owns a directory under $XDG_RUNTIME_DIR; its `exit` file says when ani-cli
 * is gone and why. Progress is kept here per show and episode, so an episode
 * resumes where it stopped. jerry and curd only get their history listed and
 * their own continue command in a terminal.
 */
Singleton {
    id: root

    readonly property int maxShows: 6
    // The service is constructed whenever IrisPieces.available("watching") is read,
    // so nothing here may start a process until the piece is actually on.
    readonly property bool enabled: Config.options?.iris?.bubbles?.extras?.watching?.enable ?? false
    readonly property double finishedRatio: 0.9
    readonly property string audio: Config.options?.iris?.anime?.audio === "dub" ? "dub" : "sub"
    readonly property string quality: String(Config.options?.iris?.anime?.quality ?? "best")
    readonly property int subtitleScale: Math.max(50, Math.min(200, Number(Config.options?.iris?.anime?.subtitleScale ?? 100)))
    readonly property int subtitlePosition: Math.max(50, Math.min(100, Number(Config.options?.iris?.anime?.subtitlePosition ?? 100)))
    readonly property bool skipIntro: Config.options?.iris?.anime?.skipIntro ?? false
    property bool hasAniSkip: false

    property string cli: ""
    property var shows: []
    property bool detected: false
    property var progress: ({})
    property var session: null
    // Why the last run ended without playing, in words for the card.
    property string error: ""
    readonly property bool available: root.enabled && root.cli.length > 0
    readonly property bool canTarget: root.available && root.cli === "ani-cli"
    readonly property var current: root.shows.length > 0 ? root.shows[0] : null

    readonly property string _dataHome: {
        const value = Quickshell.env("XDG_DATA_HOME")
        return value && value.length > 0 ? value : Directories.homePath + "/.local/share"
    }

    readonly property string _stateHome: {
        const value = Quickshell.env("XDG_STATE_HOME")
        return value && value.length > 0 ? value : Directories.homePath + "/.local/state"
    }

    readonly property string _runsHome: {
        const value = Quickshell.env("XDG_RUNTIME_DIR")
        return (value && value.length > 0 ? value : "/tmp") + "/inir-anime"
    }

    readonly property string progressPath: Directories.stateUserPath + "/anime-watch-progress.json"
    readonly property string coversPath: Directories.stateUserPath + "/anime-watch-covers.json"
    // AniList cover art by show key. ani-cli's history names a show but carries no
    // art, and mpv playing a stream publishes none, so the title is looked up once.
    property var covers: ({})
    property var _coverAsked: ({})
    readonly property string playingCover: root.session ? root.coverOf(root.session) : ""
    readonly property string launcher: Directories.scriptPath + "/inir-ani"

    property string runDir: ""
    readonly property bool running: root.runDir.length > 0
    property int _pid: 0
    property bool _cancelled: false
    // An answer decided before ani-cli asks: skipping from the Island quits the
    // player, and the question that follows is answered with where to go.
    property string _autoAnswer: ""

    // idle -> searching (ani-cli is asking which show or episode) -> launching (an
    // episode is resolving, no player yet) -> playing -> between (the player closed,
    // ani-cli is asking what next) -> ... -> idle once ani-cli exits. Nothing starts
    // a second run before the first ends: two players would share one show's
    // progress and fight over its position.
    property string phase: "idle"
    readonly property bool busy: root.running || root.phase !== "idle"
    readonly property string busyKey: root.session ? String(root.session.key) : ""
    readonly property string busyEpisode: root.session ? String(root.session.episode) : ""
    readonly property string playingTitle: root.phase === "playing" ? mpv.mediaTitle : ""

    function coverOf(entry: var): string {
        return String(root.covers[root.progressKey(entry)] ?? "")
    }

    function _wantCover(title: string): void {
        const key = root.progressKey({ title: title })
        if (!root.enabled || key.length === 0 || root.covers[key] || root._coverAsked[key]) return
        root._coverAsked[key] = true
        AnimeService.findCover(title, url => {
            if (url.length === 0) return
            const all = Object.assign({}, root.covers)
            all[key] = url
            root.covers = all
            coversFile.setText(JSON.stringify(all))
        })
    }

    onShowsChanged: {
        if (coversFile.loaded) for (const show of root.shows) root._wantCover(String(show.title))
    }
    onSessionChanged: if (root.session && coversFile.loaded) root._wantCover(String(root.session.title))

    function isBusyFor(entry: var): bool {
        return root.busy && root.busyKey.length > 0 && root.busyKey === root.progressKey(entry)
    }

    // The Island's player is this run's mpv when MPRIS reports the title the wrapper set.
    function ownsPlayer(player: var): bool {
        return root.playingTitle.length > 0 && String(player?.trackTitle ?? "") === root.playingTitle
    }

    property var pick: null
    readonly property bool choosing: root.pick !== null
    readonly property string pickPrompt: root.pick ? String(root.pick.prompt ?? "") : ""
    readonly property var pickItems: root.pick ? (root.pick.items ?? []) : []
    readonly property bool betweenEpisodes: root.pickPrompt.indexOf("Playing episode") === 0
    readonly property bool pickingQuality: root.pickPrompt.indexOf("Select Quality") === 0
    readonly property bool pickingShow: root.pickPrompt.indexOf("Select anime") === 0
    readonly property bool pickingEpisode: root.pickPrompt.indexOf("Select episode") === 0
    property string query: ""

    function actionLabel(id: string): string {
        switch (String(id)) {
        case "next": return Translation.tr("Next episode")
        case "replay": return Translation.tr("Play again")
        case "previous": return Translation.tr("Previous")
        case "select": return Translation.tr("Another episode")
        case "change_quality": return Translation.tr("Quality")
        case "quit": return Translation.tr("Done")
        }
        return String(id)
    }

    // ani-cli numbers what it offers and expects that number back; the label is what
    // follows it. Quality lines are "<quality> ><url>" and answer with the quality.
    function pickLabel(item: string): string {
        const text = String(item ?? "")
        if (root.pickingQuality) return text.split(">")[0].trim()
        const cut = text.indexOf(" ")
        return cut < 0 ? text : text.slice(cut + 1)
    }

    function pickValue(item: string): string {
        const text = String(item ?? "")
        if (root.pickingQuality) return text.split(">")[0].trim()
        const cut = text.indexOf(" ")
        return cut < 0 ? text : text.slice(0, cut)
    }

    readonly property var subtitles: root.phase === "playing" ? (mpv.subTracks ?? []) : []
    readonly property int subtitleId: mpv.subId
    readonly property double subtitleDelay: mpv.subDelay
    readonly property var audios: root.phase === "playing" ? (mpv.audioTracks ?? []) : []
    readonly property int audioId: mpv.audioId

    function selectAudio(id: int): void { mpv.apply("aid", id) }
    function nudgeSubtitleDelay(seconds: real): void { mpv.apply("sub-delay", Math.round((mpv.subDelay + seconds) * 10) / 10) }
    function resetSubtitleDelay(): void { mpv.apply("sub-delay", 0) }
    function seekBy(seconds: real): void { mpv.seekBy(seconds) }
    function addSubtitle(path: string): void { mpv.addSub(String(path ?? "").replace(/^file:\/\//, "")) }
    function setSubtitleScale(percent: int): void {
        Config.setNestedValue("iris.anime.subtitleScale", Math.max(50, Math.min(200, Math.round(percent / 10) * 10)))
    }
    function setSubtitlePosition(percent: int): void {
        Config.setNestedValue("iris.anime.subtitlePosition", Math.max(50, Math.min(100, Math.round(percent))))
    }
    function _applySubtitleLook(): void {
        mpv.apply("sub-scale", root.subtitleScale / 100)
        mpv.apply("sub-pos", root.subtitlePosition)
    }
    onSubtitleScaleChanged: root._applySubtitleLook()
    onSubtitlePositionChanged: root._applySubtitleLook()

    // An external track's title is the provider's file name, never a label a person
    // can read, so only the language names a track.
    // ani-cli's provider publishes one track, labelled English, as a remote file named by a hash; a
    // file the person loaded is named after itself.
    function subtitleLabel(track: var, index: int): string {
        const lang = String(track?.lang ?? "").trim()
        if (lang.length > 0) return lang.toUpperCase()
        const file = String(track?.["external-filename"] ?? "")
        if (track?.external === true && file.length > 0 && !/^[a-z]+:\/\//i.test(file))
            return file.split("/").pop().replace(/\.[^.]+$/, "")
        if (track?.external === true) return Translation.tr("English")
        const title = String(track?.title ?? "").trim()
        return title.length > 0 ? title : String(index + 1)
    }

    function selectSubtitle(id: int): void {
        mpv.selectSub(id)
    }

    function historyPath(id: string): string {
        if (id === "jerry") return root._dataHome + "/jerry/jerry_history.txt"
        if (id === "curd") return root._dataHome + "/curd/curd_history.txt"
        if (id === "ani-cli") {
            const custom = Quickshell.env("ANI_CLI_HIST_DIR")
            const dir = custom && custom.length > 0 ? custom : root._stateHome + "/ani-cli"
            return dir + "/ani-hsts"
        }
        return ""
    }

    function reload(): void {
        if (!root.enabled) {
            root.shows = []
            return
        }
        if (root.cli.length === 0) return
        historyFile.reload()
        progressFile.reload()
    }

    function refresh(): void {
        if (!root.enabled) {
            root.cli = ""
            root.shows = []
            root.detected = false
            root.progress = ({})
            root.error = ""
            return
        }
        root.detected = false
        detectProcess.running = false
        detectProcess.running = true
    }

    function resume(entry: var): void {
        if (root.cli.length === 0 || root.busy) return
        const target = entry ?? root.current
        if (!target) return
        if (root.cli !== "ani-cli") {
            root._resumeCli(root.cli)
            return
        }
        const episode = root.stateOf(target).episode
        if (episode.length === 0) return
        root.session = { key: root.progressKey(target), title: String(target.title ?? ""), episode: episode }
        root._start(["-e", episode, String(target.title)], String(target.title))
        root.phase = "launching"
        mpv.begin(root.runDir + "/mpv.sock", root.runDir + "/reject")
    }

    function search(text: string): void {
        const wanted = String(text ?? "").trim()
        if (wanted.length === 0 || root.busy || root.cli !== "ani-cli") return
        root.query = wanted
        root.session = null
        root._start([wanted], "")
        root.phase = "searching"
    }

    function choose(value: string): void {
        if (!root.pick || !root.running) return
        const action = root.betweenEpisodes ? String(value) : ""
        const plays = root.pickingEpisode || root.pickingQuality
            || action === "next" || action === "replay" || action === "previous"
        root.pick = null
        ShellExec.writeFileViaShell(root.runDir + "/response", String(value) + "\n")
        if (plays) {
            root.phase = "launching"
            mpv.begin(root.runDir + "/mpv.sock", root.runDir + "/reject")
        }
    }

    // From the Island while an episode plays: close it (its place is saved) and
    // answer ani-cli's next question with the direction, keeping the series resolved.
    function skip(action: string): void {
        if (action !== "next" && action !== "previous") return
        if (root.betweenEpisodes) {
            root.choose(action)
            return
        }
        if (root.phase !== "playing" || !mpv.connected) return
        root._autoAnswer = action
        mpv.quit()
    }

    function cancel(): void {
        if (!root.running) return
        root._cancelled = true
        if (root.choosing) {
            root.pick = null
            ShellExec.writeFileViaShell(root.runDir + "/response", "")
        } else if (root._pid > 0) {
            ShellExec.execDetachedArgs(["kill", String(root._pid)], "Stop anime run")
        }
    }

    // Everything a row or the bubble needs about one show, resolved once: the episode
    // that would actually play, where it would start, and how far in that leaves it.
    function stateOf(entry: var): var {
        const empty = { episode: "", start: 0, progress: 0 }
        const episode = String(entry?.episode ?? "").trim()
        if (episode.length === 0) return empty
        const series = root.progress?.[root.progressKey(entry)] ?? ({})
        let target = episode
        let saved = series[episode]
        if (saved && root._finished(saved)) {
            const value = Number(episode)
            if (isFinite(value)) {
                target = String(value + 1)
                saved = series[target]
            }
        }
        const seconds = saved && !root._finished(saved) ? (Number(saved.seconds) || 0) : 0
        const duration = saved ? (Number(saved.duration) || 0) : 0
        return {
            episode: target,
            start: seconds,
            progress: duration > 0 ? Math.max(0, Math.min(1, seconds / duration)) : 0
        }
    }

    function targetEpisodeOf(entry: var): string {
        return root.stateOf(entry).episode
    }

    function targetStartOf(entry: var): double {
        return root.stateOf(entry).start
    }

    function _finished(saved: var): bool {
        const duration = Number(saved?.duration) || 0
        return duration > 0 && (Number(saved?.seconds) || 0) / duration > root.finishedRatio
    }

    function _start(args: var, expect: string): void {
        const token = String(Date.now())
        root.runDir = root._runsHome + "/" + token
        root.error = ""
        root.pick = null
        root._pid = 0
        root._cancelled = false
        root._autoAnswer = ""
        const flags = []
        if (root.audio === "dub") flags.push("--dub")
        if (root.skipIntro && root.hasAniSkip) flags.push("--skip")
        if (root.quality !== "best") flags.push("-q", root.quality)
        ShellExec.execDetachedArgs([
            "/usr/bin/env",
            "INIR_ANI_EXPECT=" + expect,
            "INIR_ANI_PROGRESS=" + root.progressPath,
            "INIR_ANI_FINISHED=" + String(root.finishedRatio),
            root.launcher, root.runDir,
            ...flags, ...args
        ], "Anime: " + args.join(" "))
    }

    function _resumeCli(id: string): void {
        const command = ["/usr/bin/bash", "-lc", id + " -c"]
        const terminal = root._terminal()
        if (terminal === "wezterm")
            ShellExec.execDetachedArgs([terminal, "start", "--always-new-process", "--", ...command], "Resume anime")
        else
            ShellExec.execDetachedArgs([terminal, "-e", ...command], "Resume anime")
    }

    // ani-cli exited: the run is over whatever phase it was in. Its last complaint is
    // the reason, unless the person cancelled or it simply finished.
    function _ended(text: string): void {
        if (!root.running) return
        const lines = String(text ?? "").split("\n")
        const status = Number(lines[0])
        const said = String(lines[1] ?? "").trim()
        const finished = root.session
        const run = root.runDir
        const asked = root.query
        root.runDir = ""
        root.pick = null
        root.query = ""
        // A player can outlive a launcher that was killed; it keeps being observed
        // and saves its place when it closes.
        if (root.phase !== "playing") {
            mpv.stop()
            root.session = null
            root.phase = "idle"
        }
        root._pid = 0
        if (status !== 0 && !root._cancelled && root.error.length === 0)
            root.error = root._explain(said, finished, asked)
        root._cancelled = false
        root._autoAnswer = ""
        if (run.indexOf(root._runsHome + "/") === 0)
            ShellExec.execDetachedArgs(["rm", "-rf", "--", run], "Clean anime run")
    }

    function _explain(said: string, session: var, asked: string): string {
        const episode = session ? String(session.episode) : ""
        if (said.indexOf("No results found") >= 0) return Translation.tr("Nothing found for “%1”").arg(asked)
        if (said.indexOf("Invalid anime selection") >= 0 && session)
            return Translation.tr("Could not find %1 again").arg(session.title)
        if (said.indexOf("Invalid episode") >= 0 || said.indexOf("not released") >= 0)
            return episode.length > 0 ? Translation.tr("Episode %1 is not out yet").arg(episode) : Translation.tr("That episode is not out yet")
        if (said.indexOf("Out of range") >= 0) return Translation.tr("No more episodes")
        if (said.indexOf("No sources found for dub") >= 0) return Translation.tr("No dub for this one; try subtitles")
        if (said.indexOf("No sources found") >= 0 || said.indexOf("no valid sources") >= 0) return Translation.tr("No stream found for this episode")
        if (said.indexOf("cloudflare") >= 0) return Translation.tr("The anime site is blocking requests right now")
        if (said.indexOf("Request failed") >= 0 || said.indexOf("Could not resolve") >= 0) return Translation.tr("The anime site did not answer")
        return said.length > 0 ? said : Translation.tr("ani-cli stopped")
    }

    function _persist(): void {
        const finished = root.session
        root.session = null
        root.phase = root.running ? "between" : "idle"
        root._record(finished)
    }

    // The position is written while the episode runs, not only when it ends: a
    // shell reload or a killed player would otherwise lose the whole point.
    function _record(entry: var): void {
        if (!entry) return
        const position = Math.max(0, Number(mpv.position) || 0)
        const duration = Math.max(0, Number(mpv.duration) || 0)
        if (position <= 0 && duration <= 0) return
        const all = Object.assign({}, root.progress ?? ({}))
        const series = Object.assign({}, all[entry.key] ?? ({}))
        series[entry.episode] = { episode: entry.episode, seconds: position, duration: duration, at: Date.now() }
        all[entry.key] = series
        root.progress = all
        progressFile.setText(JSON.stringify(all))
    }

    function _reject(found: string): void {
        root.session = null
        root.phase = root.running ? "between" : "idle"
        root._autoAnswer = "quit"
        const resolved = String(found ?? "").trim()
        root.error = Translation.tr("Refused · %1").arg(resolved.length > 0 ? resolved : "?")
    }

    function clock(seconds: real): string {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const rest = total % 60
        if (hours > 0)
            return hours + ":" + String(minutes).padStart(2, "0") + ":" + String(rest).padStart(2, "0")
        return minutes + ":" + String(rest).padStart(2, "0")
    }

    function _terminal(): string {
        const configured = String(Config.options?.apps?.terminal ?? "kitty").trim()
        if (configured.length === 0) return "kitty"
        if (!/^[A-Za-z0-9._+-]+$/.test(configured)) return "kitty"
        return configured
    }

    function _parseProgress(text: string): void {
        let data = null
        try {
            data = JSON.parse(String(text ?? ""))
        } catch (error) {
            data = null
        }
        root.progress = (data && typeof data === "object") ? data : ({})
    }

    MpvIpc {
        id: mpv
        onStarted: {
            if (root.phase !== "idle") root.phase = "playing"
            root._applySubtitleLook()
            claimTimer.tries = 0
            claimTimer.restart()
        }
        onMediaTitleChanged: if (!root.session) root._adopt()
        onClosed: root._persist()
        onRejected: (expected, found) => root._reject(found)
    }

    // A player that outlived a shell reload, or the next episode of a search run,
    // says which show it is through the title the wrapper set: "<show> Episode <n>".
    function _adopt(): void {
        const title = String(mpv.mediaTitle ?? "").trim()
        const match = title.match(/^(.*?)\s+Episode\s+([0-9.]+)\s*$/i)
        if (!match) return
        root.session = { key: root.progressKey({ title: match[1] }), title: match[1], episode: match[2] }
    }

    // A run still going after the shell reloaded: its directory has no `exit` and its
    // launcher is alive. Dead runs are swept. Prints "<dir>\t<1 if mpv listens>".
    Process {
        id: findRunProcess
        running: false
        command: ["/usr/bin/python3", "-c",
            "import os, shutil, socket, sys\n"
            + "base = sys.argv[1]\n"
            + "found = ''\n"
            + "for name in sorted(os.listdir(base) if os.path.isdir(base) else [], reverse=True):\n"
            + "    run = os.path.join(base, name)\n"
            + "    try:\n"
            + "        alive = not os.path.exists(os.path.join(run, 'exit')) and os.path.exists('/proc/' + open(os.path.join(run, 'pid')).read().strip())\n"
            + "    except OSError:\n"
            + "        alive = False\n"
            + "    if alive and not found:\n"
            + "        found = run\n"
            + "    elif not alive:\n"
            + "        shutil.rmtree(run, ignore_errors=True)\n"
            + "if found:\n"
            + "    listening = '0'\n"
            + "    try:\n"
            + "        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n"
            + "        client.settimeout(1)\n"
            + "        client.connect(os.path.join(found, 'mpv.sock'))\n"
            + "        client.close()\n"
            + "        listening = '1'\n"
            + "    except OSError:\n"
            + "        pass\n"
            + "    sys.stdout.write(found + '\\t' + listening)\n",
            root._runsHome]
        stdout: StdioCollector {
            id: findRunCollector
            onStreamFinished: {
                const fields = findRunCollector.text.trim().split("\t")
                if (fields[0].length === 0 || root.busy) return
                root.runDir = fields[0]
                if (fields[1] === "1") {
                    root.phase = "launching"
                    mpv.begin(root.runDir + "/mpv.sock", root.runDir + "/reject")
                } else {
                    root.phase = "between"
                }
            }
        }
    }

    // Starting an episode is asking to watch it: its player becomes the one the
    // Island and the media card follow, once MPRIS has registered it.
    Timer {
        id: claimTimer
        property int tries: 0
        interval: 500
        repeat: true
        onTriggered: {
            const title = mpv.mediaTitle
            const player = title.length > 0 ? Array.from(MprisController.players ?? []).find(candidate => String(candidate?.trackTitle ?? "") === title) : null
            if (player) MprisController.setActivePlayer(player)
            if (player || ++claimTimer.tries >= 12 || root.phase !== "playing") claimTimer.stop()
        }
    }

    Timer {
        running: root.error.length > 0 && !root.busy
        interval: 30000
        onTriggered: root.error = ""
    }

    Timer {
        running: root.phase === "playing" && root.session !== null
        interval: 20000
        repeat: true
        onTriggered: root._record(root.session)
    }

    Process {
        id: detectProcess
        command: ["/usr/bin/bash", "-c",
            'command -v ani-skip >/dev/null 2>&1 && printf "skip "; for c in ani-cli jerry curd; do command -v "$c" >/dev/null 2>&1 && { printf %s "$c"; exit 0; }; done']
        stdout: StdioCollector {
            id: detectCollector
            onStreamFinished: {
                const found = detectCollector.text.trim().split(" ")
                root.hasAniSkip = found[0] === "skip"
                root.cli = found[found.length - 1] === "skip" ? "" : found[found.length - 1]
                root.detected = true
                root.reload()
                if (root.cli === "ani-cli" && !root.busy) findRunProcess.running = true
            }
        }
    }

    FileView {
        id: historyFile
        path: root.enabled && root.cli.length > 0 ? Qt.resolvedUrl(root.historyPath(root.cli)) : ""
        watchChanges: true
        printErrors: false
        onFileChanged: historyDebounce.restart()
        onLoaded: root._parse(historyFile.text())
        onLoadFailed: root.shows = []
    }

    // An episode ending rewrites the history and the position together.
    Timer {
        id: historyDebounce
        interval: 400
        repeat: false
        onTriggered: root.reload()
    }

    // The run's files are replaced, not rewritten, and appear after the watch would
    // start, so they are polled, and only while a run is alive.
    Timer {
        running: root.running
        interval: 400
        repeat: true
        onTriggered: {
            if (!root.choosing) requestFile.reload()
            exitFile.reload()
            if (root._pid === 0) pidFile.reload()
        }
    }

    // A launcher killed outright writes no `exit`; its process going away is the end.
    Timer {
        running: root.running && root._pid > 0
        interval: 2000
        repeat: true
        onTriggered: processFile.reload()
    }

    FileView {
        id: requestFile
        path: root.running ? Qt.resolvedUrl(root.runDir + "/request.json") : ""
        printErrors: false
        onLoaded: {
            let data = null
            try {
                data = JSON.parse(requestFile.text())
            } catch (error) {
                data = null
            }
            const asked = (data && Array.isArray(data.items) && data.items.length > 0) ? data : null
            if (!asked) return
            root.pick = asked
            if (root.betweenEpisodes && root.phase !== "between") root.phase = "between"
            if (root.betweenEpisodes && root._autoAnswer.length > 0) {
                const answer = root._autoAnswer
                root._autoAnswer = ""
                root.choose(answer)
            }
        }
        onLoadFailed: root.pick = null
    }

    FileView {
        id: exitFile
        path: root.running ? Qt.resolvedUrl(root.runDir + "/exit") : ""
        printErrors: false
        onLoaded: root._ended(exitFile.text())
    }

    FileView {
        id: pidFile
        path: root.running ? Qt.resolvedUrl(root.runDir + "/pid") : ""
        printErrors: false
        onLoaded: root._pid = Number(pidFile.text().trim()) || 0
    }

    FileView {
        id: processFile
        path: root._pid > 0 ? "/proc/" + root._pid + "/stat" : ""
        printErrors: false
        onLoadFailed: if (root.running) root._ended("137\n")
    }

    FileView {
        id: coversFile
        property bool loaded: false
        path: root.enabled ? Qt.resolvedUrl(root.coversPath) : ""
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(coversFile.text())
                root.covers = (data && typeof data === "object") ? data : ({})
            } catch (error) {
                root.covers = ({})
            }
            coversFile.loaded = true
            root.showsChanged()
        }
        onLoadFailed: {
            coversFile.loaded = true
            root.showsChanged()
        }
    }

    FileView {
        id: progressFile
        path: root.enabled ? Qt.resolvedUrl(root.progressPath) : ""
        watchChanges: true
        printErrors: false
        onLoaded: root._parseProgress(progressFile.text())
        onLoadFailed: root.progress = ({})
    }

    Connections {
        target: Config
        function onRevisionChanged(): void {
            if (root.enabled && !root.detected) root.refresh()
        }
    }

    Component.onCompleted: {
        if (root.enabled) root.refresh()
    }

    // The provider slug is not stable: searching the same show can resolve it to a
    // different id, which would orphan its saved position. The title is what both
    // the history and the player agree on. scripts/inir-mpv derives the same key.
    function progressKey(entry: var): string {
        return String(entry?.title ?? "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim()
    }

    function _parse(text: string): void {
        const entries = []
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.replace(/\r$/, "")
            if (line.length === 0) continue
            const entry = root.cli === "ani-cli" ? root._parseAniCli(line)
                : root.cli === "jerry" ? root._parseJerry(line)
                : root.cli === "curd" ? root._parseCurd(line) : null
            if (entry && entry.title.length > 0) entries.push(entry)
        }
        entries.reverse()
        const seen = ({})
        const unique = []
        for (const entry of entries) {
            const key = root.progressKey(entry)
            if (key.length === 0 || seen[key]) continue
            seen[key] = true
            unique.push(entry)
        }
        root.shows = unique.slice(0, root.maxShows)
    }

    // ani-cli ~/.local/state/ani-cli/ani-hsts: episode<TAB>provider_id<TAB>title.
    function _parseAniCli(line: string): var {
        const fields = line.split("\t")
        if (fields.length < 3) return null
        return {
            id: fields[1].trim(), anilistId: 0,
            title: fields[2].trim(), episode: fields[0].trim(), total: ""
        }
    }

    // jerry ~/.local/share/jerry/jerry_history.txt: anilist_id<TAB>ep/total<TAB>stopped<TAB>title.
    function _parseJerry(line: string): var {
        const fields = line.split("\t")
        if (fields.length < 4) return null
        const progress = String(fields[1]).split("/")
        return {
            id: fields[0].trim(), anilistId: Number(fields[0]) || 0,
            title: fields[3].trim(), episode: String(progress[0] ?? "").trim(),
            total: String(progress[1] ?? "").trim()
        }
    }

    // curd ~/.local/share/curd/curd_history.txt, CSV written by Go's encoding/csv:
    // anilist_id,provider_id,episode,playback_time,duration,provider,title. Older
    // rows end at provider_id or drop provider, so the title is the last field.
    function _parseCurd(line: string): var {
        const fields = root._csv(line)
        if (fields.length < 5) return null
        let title = ""
        if (fields.length >= 7) title = fields[6]
        else if (fields.length === 6) title = fields[5]
        else if (isNaN(Number(fields[4]))) title = fields[4]
        return {
            id: String(fields[1] ?? ""), anilistId: Number(fields[0]) || 0,
            title: String(title).trim(), episode: String(fields[2]).trim(), total: ""
        }
    }

    function _csv(line: string): var {
        const fields = []
        let value = ""
        let quoted = false
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (quoted) {
                if (ch === '"') {
                    if (line[i + 1] === '"') { value += '"'; i++ }
                    else quoted = false
                } else value += ch
            } else if (ch === '"') quoted = true
            else if (ch === ",") { fields.push(value); value = "" }
            else value += ch
        }
        fields.push(value)
        return fields
    }
}
