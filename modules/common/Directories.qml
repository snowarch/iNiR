pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions
import qs.services
import QtCore
import QtQuick
import Quickshell

Singleton {
    id: root

    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string genericCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]
    readonly property string homePath: FileUtils.trimFileProtocol(home)
    readonly property string configPath: FileUtils.trimFileProtocol(config)
    readonly property string statePath: FileUtils.trimFileProtocol(state)
    readonly property string cachePath: FileUtils.trimFileProtocol(cache)
    readonly property string genericCachePath: FileUtils.trimFileProtocol(genericCache)
    readonly property string documentsPath: FileUtils.trimFileProtocol(documents)
    readonly property string downloadsPath: FileUtils.trimFileProtocol(downloads)
    readonly property string picturesPath: FileUtils.trimFileProtocol(pictures)
    readonly property string musicPath: FileUtils.trimFileProtocol(music)
    readonly property string videosPath: FileUtils.trimFileProtocol(videos)

    // Other dirs used by the shell, without "file://"
    property string assetsPath: Quickshell.shellPath("assets")
    property string scriptPath: Quickshell.shellPath("scripts")
    property string scriptsPath: FileUtils.trimFileProtocol(scriptPath)
    property string stateUserPath: `${Directories.statePath}/user`
    property string wallpapersPath: `${Directories.picturesPath}/Wallpapers`
    property string screenshotsPath: `${Directories.picturesPath}/Screenshots`
    property string persistentStatesPath: `${Directories.statePath}/states.json`
    property string eventsPath: `${Directories.stateUserPath}/events.json`
    property string generatedMaterialScssPath: `${Directories.stateUserPath}/generated/material_colors.scss`
    property string favicons: `${Directories.cachePath}/media/favicons`
    // User avatar paths
    property string userAvatarPathAccountsService: FileUtils.trimFileProtocol(`/var/lib/AccountsService/icons/${SystemInfo.username}`)
    property string userAvatarPathRicersAndWeirdSystems: `${Directories.homePath}/.face`
    property string userAvatarPathRicersAndWeirdSystems2: `${Directories.homePath}/.face.icon`
    readonly property var userAvatarPaths: [
        userAvatarPathAccountsService,
        userAvatarPathRicersAndWeirdSystems,
        userAvatarPathRicersAndWeirdSystems2
    ]
    readonly property string userAvatarSourcePrimary: avatarSourceAt(0)
    property string coverArt: `${Directories.cachePath}/media/coverart`
    property string tempImages: "/tmp/quickshell/media/images"
    property string booruPreviews: `${Directories.cachePath}/media/boorus`
    property string booruDownloads: Directories.wallpapersPath
    property string booruDownloadsNsfw: `${Directories.wallpapersPath}/🌶️`
    property string latexOutput: `${Directories.cachePath}/media/latex`
    property string shellConfig: `${Directories.configPath}/illogical-impulse`
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
    property string updateLogPath: `${Directories.stateUserPath}/update.log`
    property string updateStatusPath: `${Directories.stateUserPath}/update-status`
    property string todoPath: `${Directories.stateUserPath}/todo.json`
    property string todoTxtPath: `${Directories.stateUserPath}/todo.txt`
    property string notepadPath: `${Directories.stateUserPath}/notepad.txt`
    property string notesPath: `${Directories.stateUserPath}/notes.txt`
    property string conflictCachePath: `${Directories.cachePath}/conflict-killer`
    property string notificationsPath: `${Directories.stateUserPath}/notifications.json`
    property string generatedMaterialThemePath: `${Directories.stateUserPath}/generated/colors.json`
    property string generatedPalettePath: `${Directories.stateUserPath}/generated/palette.json`
    property string generatedTerminalPalettePath: `${Directories.stateUserPath}/generated/terminal.json`
    property string generatedThemeMetaPath: `${Directories.stateUserPath}/generated/theme-meta.json`
    property string generatedWallpaperCategoryPath: `${Directories.stateUserPath}/generated/wallpaper/category.txt`
    property string cliphistDecode: FileUtils.trimFileProtocol(`/tmp/quickshell/media/cliphist`)
    property string screenshotTemp: "/tmp/quickshell/media/screenshot"
    property string wallpaperSwitchScriptPath: `${Directories.scriptsPath}/colors/switchwall.sh`
    property string defaultAiPrompts: Quickshell.shellPath("defaults/ai/prompts")
    property string userAiPrompts: FileUtils.trimFileProtocol(`${Directories.shellConfig}/ai/prompts`)
    property string userActions: FileUtils.trimFileProtocol(`${Directories.shellConfig}/actions`)
    property string aiChats: `${Directories.stateUserPath}/ai/chats`
    property string aiTranslationScriptPath: `${Directories.scriptsPath}/ai/gemini-translate.sh`
    property string recordScriptPath: `${Directories.scriptsPath}/videos/record.sh`

    function shortHomePath(path: string): string {
        const cleaned = FileUtils.trimFileProtocol(path)
        if (cleaned === root.homePath)
            return "~"
        if (cleaned.startsWith(root.homePath + "/"))
            return "~" + cleaned.slice(root.homePath.length)
        return cleaned
    }

    function avatarSourceAt(index: int): string {
        if (index < 0 || index >= userAvatarPaths.length)
            return ""

        const path = String(userAvatarPaths[index] ?? "").trim()
        return path.length > 0 ? `file://${path}` : ""
    }

    function nextAvatarSource(currentSource: string): string {
        const normalized = String(currentSource ?? "").replace(/^file:\/\//, "")

        for (let i = 0; i < userAvatarPaths.length; ++i) {
            if (String(userAvatarPaths[i] ?? "") === normalized)
                return avatarSourceAt(i + 1)
        }

        return userAvatarSourcePrimary
    }
    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`])
        Quickshell.execDetached(["mkdir", "-p", `${stateUserPath}`])
        Quickshell.execDetached(["mkdir", "-p", `${favicons}`])
        Quickshell.execDetached(["rm", "-rf", `${coverArt}`])
        Quickshell.execDetached(["mkdir", "-p", `${coverArt}`])
        Quickshell.execDetached(["rm", "-rf", `${booruPreviews}`])
        Quickshell.execDetached(["mkdir", "-p", `${booruPreviews}`])
        Quickshell.execDetached(["rm", "-rf", `${latexOutput}`])
        Quickshell.execDetached(["mkdir", "-p", `${latexOutput}`])
        Quickshell.execDetached(["rm", "-rf", `${cliphistDecode}`])
        Quickshell.execDetached(["mkdir", "-p", `${cliphistDecode}`])
        Quickshell.execDetached(["mkdir", "-p", `${aiChats}`])
        Quickshell.execDetached(["mkdir", "-p", `${userActions}`])
        Quickshell.execDetached(["rm", "-rf", `${tempImages}`])
    }
}
