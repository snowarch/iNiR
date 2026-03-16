---
trigger: model_decision
description: Pull when you need exact file maps inside modules/common, utility function locations, or authoritative per-module file existence.
---

# iNiR Module File Maps (Verified from filesystem)

Every file inside every module. Use to know what exists before creating/modifying.

## modules/bar/ (33 files)
Entry: `Bar.qml` → `BarContent.qml`
```
Bar.qml, BarContent.qml, BarGroup.qml, BarVignette.qml, ScrollHint.qml, StyledPopup.qml
— Taskbar: BarTaskbar.qml, BarTaskbarButton.qml, BarTaskbarPreview.qml, BarTaskbarWindowPreview.qml
— Clock: ClockWidget.qml, ClockWidgetTooltip.qml
— Workspaces: Workspaces.qml
— Media: Media.qml
— Battery: BatteryIndicator.qml, BatteryPopup.qml
— Resources: Resource.qml, Resources.qml, ResourcesPopup.qml
— System tray: SysTray.qml, SysTrayItem.qml, SysTrayMenu.qml, SysTrayMenuEntry.qml
— Utility: UtilButtons.qml, CircleUtilButton.qml, LeftSidebarButton.qml
— Indicators: NotificationUnreadCount.qml, ShellUpdateIndicator.qml, TimerIndicator.qml, TimerIndicatorTooltip.qml, HyprlandXkbIndicator.qml, ActiveWindow.qml
— Weather: weather/WeatherBar.qml, weather/WeatherCard.qml, weather/WeatherPopup.qml
```

## modules/sidebarLeft/ (21 files + subdirs)
Entry: `SidebarLeft.qml` → `SidebarLeftContent.qml`
```
— AI Chat: AiChat.qml, aiChat/{AiMessage, AiMessageControlButton, AnnotationSourceButton, AttachedFileIndicator, MessageCodeBlock, MessageTextBlock, MessageThinkBlock, SearchQueryButton}.qml
— Content: ToolsView.qml, Translator.qml, translator/*, Wallhaven.qml, WallhavenView.qml, YtMusicView.qml, Anime.qml, anime/*, animeSchedule/*
— Plugins: plugins/{PluginsTab.qml, WebAppView.qml}
— Widgets: widgets/WidgetsView.qml, DescriptionBox.qml, ApiCommandButton.qml, ApiInputBoxIndicator.qml, ScrollToBottomButton.qml
```

## modules/sidebarRight/ (21 dirs/files)
Entry: `SidebarRight.qml` → `SidebarRightContent.qml` / `CompactSidebarRightContent.qml`
```
— Layout: BottomWidgetGroup.qml, CenterWidgetGroup.qml, SectionDivider.qml
— Quick toggles: quickToggles/{AbstractQuickPanel, AndroidQuickPanel, ClassicQuickPanel}.qml + androidStyle/*, classicStyle/*
— Media: CompactMediaPlayer.qml, QuickSliders.qml
— Widgets: calendar/*, events/*, todo/*, notepad/*, pomodoro/*, sysmon/*
— Network: wifiNetworks/*, bluetoothDevices/*, nightLight/*
— Notifications: notifications/*, volumeMixer/*
```

## modules/dock/ (11 files)
Entry: `Dock.qml`
```
DockAppButton.qml, DockApps.qml, DockButton.qml, DockContextMenu.qml
DockMacBackground.qml, DockMacItem.qml, DockPillItem.qml
DockPreview.qml, DockWindowPreview.qml, DockSeparator.qml
```

## modules/overview/ (8 files)
Entry: `Overview.qml`
```
OverviewDashboard.qml, OverviewWidget.qml, OverviewNiriWidget.qml, OverviewWindow.qml
SearchBar.qml, SearchWidget.qml, SearchItem.qml
```

## modules/background/ (3 files + widgets/)
Entry: `Background.qml`
```
Backdrop.qml
widgets/AbstractBackgroundWidget.qml, widgets/clock/*, widgets/mediaControls/*, widgets/weather/*
```

## modules/lock/ (6 files)
Entry: `Lock.qml`
```
LockContext.qml, LockSurface.qml, LockMediaWidget.qml, PasswordChars.qml, pam/*
```

## modules/mediaControls/ (6 files + subdirs)
Entry: `MediaControls.qml`
```
PlayerControl.qml, BarMediaPlayerItem.qml, BarMediaPopup.qml
components/*, presets/{AlbumArtPlayer, ClassicPlayer, CompactPlayer, FullPlayer, MinimalPlayer, VisualizerPlayer}.qml
```

## modules/controlPanel/ (11 files)
Entry: `ControlPanel.qml` → `ControlPanelContent.qml`
```
DateTimeHeader.qml, ProfileHeader.qml, QuickActionsSection.qml
SlidersSection.qml, MediaSection.qml, SystemSection.qml
WallpaperSection.qml, WeatherSection.qml
```

## modules/ii/overlay/ (16 files + subdirs)
Entry: `Overlay.qml` → `OverlayContent.qml`
```
OverlayBackground.qml, OverlayContext.qml, OverlayTaskbar.qml
OverlayWidgetDelegateChooser.qml, StyledOverlayWidget.qml
— Widgets: crosshair/*, discord/*, floatingImage/*, fpsLimiter/*, notes/*, notifications/*, recorder/*, resources/*, volumeMixer/*
```

## modules/verticalBar/ (8 files)
Entry: `VerticalBar.qml` → `VerticalBarContent.qml`
```
VerticalClockWidget.qml, VerticalDateWidget.qml, VerticalMedia.qml
BatteryIndicator.qml, Resource.qml, Resources.qml
```

## modules/wallpaperSelector/ (7 files)
Entry: `WallpaperSelector.qml` → `WallpaperSelectorContent.qml`
```
WallpaperCoverflow.qml, WallpaperCoverflowGallery.qml, WallpaperCoverflowView.qml
WallpaperDirectoryItem.qml, WallpaperSkewView.qml
```

## modules/cheatsheet/ (9 files)
Entry: `Cheatsheet.qml`
```
CheatsheetKeybinds.qml, CheatsheetKeybindRow.qml, CheatsheetNoResults.qml
CheatsheetPeriodicTable.qml, CheatsheetElementLegend.qml
ElementTile.qml, ElementTooltip.qml, periodic_table.js
```

## modules/altSwitcher/ (1 file)
`AltSwitcher.qml` — IPC router dispatches to material or waffle alt-switcher.

## modules/clipboard/ (2 files)
`ClipboardPanel.qml`, `ClipboardItem.qml`

## modules/closeConfirm/ (4 files)
`CloseConfirm.qml`, `CloseConfirmContent.qml`, `WCloseConfirmContent.qml`

## modules/notificationPopup/ (1 file)
`NotificationPopup.qml`

## modules/onScreenDisplay/ (3 files)
`OnScreenDisplay.qml`, `OsdValueIndicator.qml`, `indicators/*`

## modules/onScreenKeyboard/ (4 files)
`OnScreenKeyboard.qml`, `OskContent.qml`, `OskKey.qml`, `layouts.js`

## modules/polkit/ (2 files)
`Polkit.qml`, `PolkitContent.qml`

## modules/regionSelector/ (7 files)
`RegionSelector.qml`, `RegionSelection.qml`, `RegionFunctions.qml`, `TargetRegion.qml`, `OptionsToolbar.qml`, `CircleSelectionDetails.qml`, `RectCornersSelectionDetails.qml`

## modules/screenCorners/ (1 file)
`ScreenCorners.qml` — invisible corner hit-zones + fake rounded corners.

## modules/sessionScreen/ (2 files)
`SessionScreen.qml`, `SessionActionButton.qml`

## modules/shellUpdate/ (2 files)
`ShellUpdateOverlay.qml`

## modules/tilingOverlay/ (3 files)
`TilingOverlay.qml`, `LayoutPreview.qml`

## modules/settings/ (19 files)
Entry: `SettingsOverlay.qml` (overlay) or `settings.qml` (window)
```
GeneralConfig, InterfaceConfig, BarConfig, BackgroundConfig, ThemesConfig
AngelStyleEditor, CustomThemeEditor, AdvancedConfig, ServicesConfig
ModulesConfig, CheatsheetConfig, QuickConfig, WaffleConfig, About
ColorPickerRow, ThemePresetCard, QuickWallpaperItem
```

## modules/waffle/ (20 subdirs)
bar/(21), startMenu/(12), actionCenter/(15), notificationCenter/(14), backdrop/(2), widgets/(3), taskview/(5), looks/(42), altSwitcher/, background/, clipboard/, lock/, notificationPopup/, onScreenDisplay/, polkit/, regionSelector/, sessionScreen/, settings/

## modules/common/ (core library)
```
Appearance.qml, Config.qml, Directories.qml, Icons.qml, Images.qml
NerdIconMap.qml, Persistent.qml, StylePresets.qml, ThemePresets.qml, ToastManager.qml
functions/{ColorUtils, DateUtils, FileUtils, Fuzzy, fuzzysort.js, Levendist, levendist.js, md5.js, NotificationUtils, ObjectUtils, Session, ShellExec, StringUtils}
models/{AdaptedMaterialScheme, AnimatedTabIndexPair, FolderListModelWithHistory, LauncherSearchResult, quickToggles/}
utils/ImageDownloaderProcess.qml
widgets/ (127 files — see 05-widget-api.md)
```

## Utility Functions API (selected)

### ColorUtils
`transparentize`, `mix`, `isDark`, `applyAlpha`, `hslLightness`, `brighten`, `darken`, `desaturate`

### StringUtils
`splitMarkdownBlocks(markdown)`, `wordWrap`, `cleanMusicTitle`, `friendlyTimeForSeconds`, `toTitleCase`

### ObjectUtils
`toPlainObject(qtObj)`, `applyToQtObject(qtObj, jsonObj)`
