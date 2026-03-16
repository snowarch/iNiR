package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type stringSlice []string

type tokenRule struct {
	Scope    []string          `json:"scope"`
	Settings map[string]string `json:"settings"`
}

var vscodeForks = map[string]string{
	"code":          "Code",
	"codium":        "VSCodium",
	"code-oss":      "Code - OSS",
	"code-insiders": "Code - Insiders",
	"cursor":        "Cursor",
	"windsurf":      "Windsurf",
	"windsurf-next": "Windsurf - Next",
	"qoder":         "Qoder",
	"antigravity":   "Antigravity",
	"positron":      "Positron",
	"void":          "Void",
	"melty":         "Melty",
	"pearai":        "PearAI",
	"aide":          "Aide",
}

func (s *stringSlice) String() string { return strings.Join(*s, ",") }
func (s *stringSlice) Set(value string) error {
	*s = append(*s, value)
	return nil
}

func main() {
	home, _ := os.UserHomeDir()
	defaultColors := filepath.Join(home, ".local/state/quickshell/user/generated/colors.json")
	defaultSCSS := filepath.Join(home, ".local/state/quickshell/user/generated/material_colors.scss")
	colorsPath := flag.String("colors", defaultColors, "")
	scssPath := flag.String("scss", defaultSCSS, "")
	output := flag.String("output", "", "")
	listForks := flag.Bool("list-forks", false, "")
	var forks stringSlice
	flag.Var(&forks, "forks", "")
	flag.Parse()
	if *listForks {
		fmt.Println("Known VSCode forks:")
		for key, name := range vscodeForks {
			path := getSettingsPath(name)
			installed := "✗"
			if dirExists(filepath.Dir(path)) {
				installed = "✓"
			}
			fmt.Printf("  [%s] %s: %s (%s)\n", installed, key, name, path)
		}
		return
	}
	if *output != "" {
		ok, err := generateTheme(*colorsPath, *scssPath, *output)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if ok {
			os.Exit(0)
		}
		os.Exit(1)
	}
	results, err := generateAllThemes(*colorsPath, *scssPath, forks)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	success := 0
	for _, ok := range results {
		if ok {
			success++
		}
	}
	fmt.Printf("Generated themes for %d/%d forks\n", success, len(results))
	if success > 0 {
		os.Exit(0)
	}
	os.Exit(1)
}

func generateAllThemes(colorsPath, scssPath string, forks []string) (map[string]bool, error) {
	selected := forks
	if len(selected) == 0 {
		for key, name := range vscodeForks {
			if dirExists(filepath.Dir(getSettingsPath(name))) {
				selected = append(selected, key)
			}
		}
	}
	results := map[string]bool{}
	for _, forkKey := range selected {
		forkName, ok := vscodeForks[forkKey]
		if !ok {
			fmt.Fprintf(os.Stderr, "Unknown fork: %s\n", forkKey)
			continue
		}
		settingsPath := getSettingsPath(forkName)
		if !dirExists(filepath.Dir(settingsPath)) {
			continue
		}
		ok, err := generateTheme(colorsPath, scssPath, settingsPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "  ✗ %s: %v\n", forkName, err)
			results[forkKey] = false
			continue
		}
		results[forkKey] = ok
		if ok {
			fmt.Printf("  ✓ %s\n", forkName)
		} else {
			fmt.Fprintf(os.Stderr, "  ✗ %s\n", forkName)
		}
	}
	return results, nil
}

func generateTheme(colorsPath, scssPath, settingsPath string) (bool, error) {
	colors, err := readStringMapJSON(colorsPath)
	if err != nil {
		return false, fmt.Errorf("error: could not find %s", colorsPath)
	}
	termColors, _ := parseSCSS(scssPath)
	settings, err := loadSettings(settingsPath)
	if err != nil {
		return false, err
	}
	settings["workbench.colorCustomizations"] = generateColors(colors, termColors)
	settings["editor.tokenColorCustomizations"] = map[string]any{"textMateRules": generateSyntax(colors)}
	settings["editor.semanticTokenColorCustomizations"] = map[string]any{"enabled": true, "rules": generateSemantic(colors)}
	if err := writeSettings(settingsPath, settings); err != nil {
		return false, err
	}
	fmt.Println("✓ Generated VSCode theme (auto-reloads instantly)")
	return true, nil
}

func generateColors(colors, termColors map[string]string) map[string]string {
	bg := pick(colors, "background", pick(colors, "surface", "#080809"))
	fg := pick(colors, "on_background", pick(colors, "on_surface", "#e3dfd9"))
	surface := pick(colors, "surface", "#080809")
	surfaceLowest := pick(colors, "surface_container_lowest", surface)
	surfaceLow := pick(colors, "surface_container_low", "#0c0c0e")
	surfaceStd := pick(colors, "surface_container", "#121115")
	surfaceHigh := pick(colors, "surface_container_high", "#1a191d")
	surfaceHighest := pick(colors, "surface_container_highest", "#232126")
	onSurface := pick(colors, "on_surface", "#e3dfd9")
	onSurfaceVariant := pick(colors, "on_surface_variant", "#c4bfb8")
	outline := pick(colors, "outline", "#5c5862")
	outlineVariant := pick(colors, "outline_variant", "#3a363e")
	primary := pick(colors, "primary", "#d4b796")
	onPrimary := pick(colors, "on_primary", "#241c14")
	primaryContainer := pick(colors, "primary_container", "#33281d")
	onPrimaryContainer := pick(colors, "on_primary_container", "#eddccb")
	secondary := pick(colors, "secondary", "#ccc2b2")
	tertiary := pick(colors, "tertiary", "#b8cbb8")
	errorCol := pick(colors, "error", "#ffb4ab")
	termDefaults := map[string]string{"term0": surfaceLowest, "term1": errorCol, "term2": tertiary, "term3": secondary, "term4": primary, "term5": secondary, "term6": tertiary, "term7": onSurface, "term8": outlineVariant, "term9": errorCol, "term10": tertiary, "term11": secondary, "term12": primary, "term13": secondary, "term14": tertiary, "term15": fg}
	term := func(name string) string { return pick(termColors, name, termDefaults[name]) }
	termBg := term("term0")
	termFg := term("term15")
	transparent := "#00000000"
	return map[string]string{
		"focusBorder": primary, "foreground": fg, "disabledForeground": onSurfaceVariant + "80", "widget.shadow": "#00000060", "selection.background": primary + "60", "descriptionForeground": onSurfaceVariant, "errorForeground": errorCol, "icon.foreground": onSurface,
		"window.activeBorder": transparent, "window.inactiveBorder": transparent,
		"textBlockQuote.background": surfaceLow, "textBlockQuote.border": transparent, "textCodeBlock.background": surfaceLow, "textLink.activeForeground": primary, "textLink.foreground": primary, "textPreformat.foreground": tertiary, "textSeparator.foreground": transparent,
		"button.background": primaryContainer, "button.foreground": onPrimaryContainer, "button.hoverBackground": primaryContainer + "dd", "button.secondaryBackground": surfaceHigh, "button.secondaryForeground": onSurface, "button.secondaryHoverBackground": surfaceHighest,
		"checkbox.background": surfaceStd, "checkbox.border": transparent, "checkbox.foreground": onSurface,
		"dropdown.background": surfaceLow, "dropdown.border": transparent, "dropdown.foreground": onSurface, "dropdown.listBackground": surfaceStd,
		"input.background": surfaceLow, "input.border": transparent, "input.foreground": onSurface, "input.placeholderForeground": onSurfaceVariant + "80", "inputOption.activeBackground": primary + "40", "inputOption.activeBorder": primary, "inputOption.activeForeground": onSurface, "inputValidation.errorBackground": errorCol + "20", "inputValidation.errorBorder": errorCol,
		"scrollbar.shadow": "#00000040", "scrollbarSlider.activeBackground": onSurfaceVariant + "80", "scrollbarSlider.background": onSurfaceVariant + "40", "scrollbarSlider.hoverBackground": onSurfaceVariant + "60",
		"badge.background": primaryContainer, "badge.foreground": onPrimaryContainer, "progressBar.background": primary,
		"list.activeSelectionBackground": surfaceHigh, "list.activeSelectionForeground": onSurface, "list.dropBackground": primary + "40", "list.focusBackground": surfaceHigh, "list.focusForeground": onSurface, "list.highlightForeground": primary, "list.hoverBackground": surfaceStd, "list.hoverForeground": onSurface, "list.inactiveSelectionBackground": surfaceStd, "list.inactiveSelectionForeground": onSurface, "list.invalidItemForeground": errorCol, "list.errorForeground": errorCol, "list.warningForeground": tertiary, "listFilterWidget.background": surfaceHigh, "listFilterWidget.outline": primary, "listFilterWidget.noMatchesOutline": errorCol, "list.filterMatchBackground": primary + "40", "tree.indentGuidesStroke": outlineVariant + "40",
		"activityBar.background": surfaceLowest, "activityBar.foreground": onSurface, "activityBar.inactiveForeground": onSurfaceVariant, "activityBar.border": transparent, "activityBarBadge.background": primary, "activityBarBadge.foreground": onPrimary, "activityBar.activeBorder": primary, "activityBar.activeBackground": surfaceStd,
		"sideBar.background": surfaceLowest, "sideBar.foreground": onSurface, "sideBar.border": transparent, "sideBarTitle.foreground": onSurface, "sideBarSectionHeader.background": surfaceLow, "sideBarSectionHeader.foreground": onSurface, "sideBarSectionHeader.border": transparent,
		"editorGroup.border": transparent, "editorGroup.dropBackground": primary + "20", "editorGroupHeader.noTabsBackground": surfaceLowest, "editorGroupHeader.tabsBackground": surfaceLowest, "editorGroupHeader.tabsBorder": transparent, "editorGroupHeader.border": transparent,
		"tab.activeBackground": surfaceLow, "tab.activeForeground": onSurface, "tab.border": transparent, "tab.activeBorder": primary, "tab.unfocusedActiveBorder": outline, "tab.inactiveBackground": surfaceLowest, "tab.inactiveForeground": onSurfaceVariant, "tab.unfocusedActiveForeground": onSurfaceVariant, "tab.unfocusedInactiveForeground": onSurfaceVariant + "80", "tab.hoverBackground": surfaceLow, "tab.unfocusedHoverBackground": surfaceLow, "tab.hoverForeground": onSurface, "tab.hoverBorder": outline, "tab.lastPinnedBorder": outline,
		"editor.background": bg, "editor.foreground": fg, "editorPane.background": bg, "editorGutter.background": bg, "editorOverviewRuler.background": bg, "editorStickyScroll.background": bg, "editorStickyScrollHover.background": surfaceLow, "editorLineNumber.foreground": onSurfaceVariant, "editorLineNumber.activeForeground": onSurface, "editorCursor.foreground": primary, "editor.selectionBackground": primaryContainer + "66", "editor.inactiveSelectionBackground": primaryContainer + "33", "editor.selectionHighlightBackground": primaryContainer + "4d", "editor.wordHighlightBackground": secondary + "30", "editor.wordHighlightStrongBackground": secondary + "50", "editor.findMatchBackground": tertiary + "40", "editor.findMatchHighlightBackground": tertiary + "30", "editor.findRangeHighlightBackground": primary + "20", "editor.hoverHighlightBackground": primary + "20", "editor.lineHighlightBackground": surfaceLow + "80", "editor.lineHighlightBorder": outlineVariant + "00", "editorLink.activeForeground": primary, "editor.rangeHighlightBackground": surfaceStd + "40", "editorWhitespace.foreground": onSurfaceVariant + "40", "editorIndentGuide.background": outlineVariant, "editorIndentGuide.activeBackground": outline, "editorRuler.foreground": outlineVariant, "editorCodeLens.foreground": onSurfaceVariant, "editorBracketMatch.background": primary + "20", "editorBracketMatch.border": primary,
		"diffEditor.insertedTextBackground": tertiary + "20", "diffEditor.removedTextBackground": errorCol + "20", "diffEditor.insertedLineBackground": tertiary + "15", "diffEditor.removedLineBackground": errorCol + "15", "diffEditor.diagonalFill": outlineVariant + "80", "diffEditor.border": transparent,
		"editorWidget.background": surfaceHigh, "editorWidget.border": outline, "editorWidget.foreground": onSurface, "editorSuggestWidget.background": surfaceHigh, "editorSuggestWidget.border": outline, "editorSuggestWidget.foreground": onSurface, "editorSuggestWidget.highlightForeground": primary, "editorSuggestWidget.selectedBackground": surfaceHighest, "editorHoverWidget.background": surfaceHigh, "editorHoverWidget.border": outline,
		"peekView.border": primary, "peekViewEditor.background": surfaceLow, "peekViewEditorGutter.background": surfaceLow, "peekViewEditor.matchHighlightBackground": primary + "40", "peekViewResult.background": surfaceStd, "peekViewResult.fileForeground": onSurface, "peekViewResult.lineForeground": onSurfaceVariant, "peekViewResult.matchHighlightBackground": primary + "40", "peekViewResult.selectionBackground": surfaceHigh, "peekViewResult.selectionForeground": onSurface, "peekViewTitle.background": surfaceStd, "peekViewTitleDescription.foreground": onSurfaceVariant, "peekViewTitleLabel.foreground": onSurface,
		"merge.currentHeaderBackground": primary + "80", "merge.currentContentBackground": primary + "20", "merge.incomingHeaderBackground": secondary + "80", "merge.incomingContentBackground": secondary + "20", "merge.border": outline, "mergeEditor.background": bg, "editorOverviewRuler.currentContentForeground": primary, "editorOverviewRuler.incomingContentForeground": secondary,
		"panel.background": surfaceLowest, "panel.border": transparent, "panelTitle.activeBorder": primary, "panelTitle.activeForeground": onSurface, "panelTitle.inactiveForeground": onSurfaceVariant, "panelInput.border": outline,
		"statusBar.background": surfaceLowest, "statusBar.foreground": onSurface, "statusBar.border": transparent, "statusBar.debuggingBackground": errorCol, "statusBar.debuggingForeground": onPrimary, "statusBar.noFolderBackground": surfaceLowest, "statusBar.noFolderForeground": onSurface, "statusBarItem.activeBackground": surfaceHigh, "statusBarItem.hoverBackground": surfaceStd, "statusBarItem.prominentBackground": primaryContainer, "statusBarItem.prominentForeground": onPrimaryContainer, "statusBarItem.prominentHoverBackground": primaryContainer + "dd",
		"titleBar.activeBackground": surfaceLowest, "titleBar.activeForeground": onSurface, "titleBar.inactiveBackground": surfaceLowest, "titleBar.inactiveForeground": onSurfaceVariant, "titleBar.border": transparent,
		"menubar.selectionForeground": onSurface, "menubar.selectionBackground": surfaceStd, "menu.foreground": onSurface, "menu.background": surfaceHigh, "menu.selectionForeground": onSurface, "menu.selectionBackground": surfaceHighest, "menu.separatorBackground": transparent, "menu.border": transparent,
		"notificationCenter.border": transparent, "notificationCenterHeader.foreground": onSurface, "notificationCenterHeader.background": surfaceStd, "notificationToast.border": transparent, "notifications.foreground": onSurface, "notifications.background": surfaceHigh, "notifications.border": transparent, "notificationLink.foreground": primary,
		"extensionButton.prominentForeground": onPrimary, "extensionButton.prominentBackground": primary, "extensionButton.prominentHoverBackground": primary + "dd",
		"pickerGroup.border": outline, "pickerGroup.foreground": primary, "quickInput.background": surfaceHigh, "quickInput.foreground": onSurface,
		"terminal.background": termBg, "terminal.foreground": termFg, "terminal.ansiBlack": term("term0"), "terminal.ansiRed": term("term1"), "terminal.ansiGreen": term("term2"), "terminal.ansiYellow": term("term3"), "terminal.ansiBlue": term("term4"), "terminal.ansiMagenta": term("term5"), "terminal.ansiCyan": term("term6"), "terminal.ansiWhite": term("term7"), "terminal.ansiBrightBlack": term("term8"), "terminal.ansiBrightRed": term("term9"), "terminal.ansiBrightGreen": term("term10"), "terminal.ansiBrightYellow": term("term11"), "terminal.ansiBrightBlue": term("term12"), "terminal.ansiBrightMagenta": term("term13"), "terminal.ansiBrightCyan": term("term14"), "terminal.ansiBrightWhite": term("term15"), "terminal.selectionBackground": primary + "40", "terminalCursor.background": bg, "terminalCursor.foreground": primary,
		"debugToolBar.background": surfaceHigh, "debugToolBar.border": outline, "editor.stackFrameHighlightBackground": tertiary + "30", "editor.focusedStackFrameHighlightBackground": tertiary + "50",
		"gitDecoration.addedResourceForeground": tertiary, "gitDecoration.modifiedResourceForeground": secondary, "gitDecoration.deletedResourceForeground": errorCol, "gitDecoration.untrackedResourceForeground": tertiary + "cc", "gitDecoration.ignoredResourceForeground": onSurfaceVariant + "80", "gitDecoration.conflictingResourceForeground": errorCol, "gitDecoration.submoduleResourceForeground": secondary,
		"settings.headerForeground": onSurface, "settings.modifiedItemIndicator": primary, "settings.dropdownBackground": surfaceLow, "settings.dropdownForeground": onSurface, "settings.dropdownBorder": outline, "settings.checkboxBackground": surfaceStd, "settings.checkboxForeground": onSurface, "settings.checkboxBorder": outline, "settings.textInputBackground": surfaceLow, "settings.textInputForeground": onSurface, "settings.textInputBorder": outline, "settings.numberInputBackground": surfaceLow, "settings.numberInputForeground": onSurface, "settings.numberInputBorder": outline,
		"breadcrumb.foreground": onSurfaceVariant, "breadcrumb.background": bg, "breadcrumb.focusForeground": onSurface, "breadcrumb.activeSelectionForeground": primary, "breadcrumbPicker.background": surfaceHigh,
		"editor.snippetTabstopHighlightBackground": primary + "30", "editor.snippetTabstopHighlightBorder": primary, "editor.snippetFinalTabstopHighlightBackground": tertiary + "30", "editor.snippetFinalTabstopHighlightBorder": tertiary,
		"symbolIcon.arrayForeground": secondary, "symbolIcon.booleanForeground": tertiary, "symbolIcon.classForeground": primary, "symbolIcon.colorForeground": secondary, "symbolIcon.constantForeground": tertiary, "symbolIcon.constructorForeground": primary, "symbolIcon.enumeratorForeground": secondary, "symbolIcon.enumeratorMemberForeground": tertiary, "symbolIcon.eventForeground": errorCol, "symbolIcon.fieldForeground": secondary, "symbolIcon.fileForeground": onSurface, "symbolIcon.folderForeground": onSurface, "symbolIcon.functionForeground": primary, "symbolIcon.interfaceForeground": secondary, "symbolIcon.keyForeground": tertiary, "symbolIcon.keywordForeground": secondary, "symbolIcon.methodForeground": primary, "symbolIcon.moduleForeground": onSurface, "symbolIcon.namespaceForeground": onSurface, "symbolIcon.nullForeground": onSurfaceVariant, "symbolIcon.numberForeground": tertiary, "symbolIcon.objectForeground": secondary, "symbolIcon.operatorForeground": secondary, "symbolIcon.packageForeground": onSurface, "symbolIcon.propertyForeground": secondary, "symbolIcon.referenceForeground": secondary, "symbolIcon.snippetForeground": tertiary, "symbolIcon.stringForeground": tertiary, "symbolIcon.structForeground": primary, "symbolIcon.textForeground": onSurface, "symbolIcon.typeParameterForeground": secondary, "symbolIcon.unitForeground": tertiary, "symbolIcon.variableForeground": onSurface,
		"notebook.editorBackground": bg, "notebook.cellEditorBackground": bg, "notebook.cellBorderColor": transparent, "notebook.cellToolbarSeparator": transparent, "notebook.focusedCellBackground": bg, "notebookStatusRunningIcon.foreground": primary,
	}
}

func generateSyntax(colors map[string]string) []tokenRule {
	primary := pick(colors, "primary", "#d4b796")
	secondary := pick(colors, "secondary", "#ccc2b2")
	tertiary := pick(colors, "tertiary", "#b8cbb8")
	errorCol := pick(colors, "error", "#ffb4ab")
	onSurface := pick(colors, "on_surface", "#e3dfd9")
	onSurfaceVariant := pick(colors, "on_surface_variant", "#c4bfb8")
	return []tokenRule{
		{[]string{"comment", "punctuation.definition.comment"}, map[string]string{"foreground": onSurfaceVariant + "cc", "fontStyle": "italic"}},
		{[]string{"keyword", "storage.type", "storage.modifier"}, map[string]string{"foreground": secondary}},
		{[]string{"keyword.control"}, map[string]string{"foreground": secondary, "fontStyle": ""}},
		{[]string{"keyword.operator"}, map[string]string{"foreground": secondary}},
		{[]string{"constant", "constant.language", "constant.character"}, map[string]string{"foreground": tertiary}},
		{[]string{"constant.numeric"}, map[string]string{"foreground": tertiary}},
		{[]string{"constant.other.color"}, map[string]string{"foreground": tertiary}},
		{[]string{"string"}, map[string]string{"foreground": tertiary}},
		{[]string{"string.regexp"}, map[string]string{"foreground": tertiary}},
		{[]string{"punctuation.definition.string"}, map[string]string{"foreground": tertiary}},
		{[]string{"entity.name.function", "support.function"}, map[string]string{"foreground": primary}},
		{[]string{"meta.function-call"}, map[string]string{"foreground": primary}},
		{[]string{"entity.name.type", "entity.name.class", "support.type", "support.class"}, map[string]string{"foreground": primary}},
		{[]string{"entity.other.inherited-class"}, map[string]string{"foreground": primary, "fontStyle": "italic"}},
		{[]string{"variable", "variable.other"}, map[string]string{"foreground": onSurface}},
		{[]string{"variable.language"}, map[string]string{"foreground": errorCol, "fontStyle": "italic"}},
		{[]string{"variable.parameter"}, map[string]string{"foreground": onSurface}},
		{[]string{"variable.other.property", "support.variable.property"}, map[string]string{"foreground": secondary}},
		{[]string{"entity.other.attribute-name"}, map[string]string{"foreground": secondary}},
		{[]string{"entity.name.tag"}, map[string]string{"foreground": primary}},
		{[]string{"punctuation.definition.tag"}, map[string]string{"foreground": primary}},
		{[]string{"punctuation"}, map[string]string{"foreground": onSurface}},
		{[]string{"punctuation.separator", "punctuation.terminator"}, map[string]string{"foreground": onSurfaceVariant}},
		{[]string{"markup.heading"}, map[string]string{"foreground": primary, "fontStyle": "bold"}},
		{[]string{"markup.bold"}, map[string]string{"foreground": onSurface, "fontStyle": "bold"}},
		{[]string{"markup.italic"}, map[string]string{"foreground": onSurface, "fontStyle": "italic"}},
		{[]string{"markup.underline.link"}, map[string]string{"foreground": primary, "fontStyle": "underline"}},
		{[]string{"markup.inline.raw"}, map[string]string{"foreground": tertiary}},
		{[]string{"markup.list"}, map[string]string{"foreground": secondary}},
		{[]string{"invalid"}, map[string]string{"foreground": errorCol}},
		{[]string{"invalid.deprecated"}, map[string]string{"foreground": errorCol, "fontStyle": "italic"}},
	}
}

func generateSemantic(colors map[string]string) map[string]string {
	primary := pick(colors, "primary", "#d4b796")
	secondary := pick(colors, "secondary", "#ccc2b2")
	tertiary := pick(colors, "tertiary", "#b8cbb8")
	errorCol := pick(colors, "error", "#ffb4ab")
	onSurface := pick(colors, "on_surface", "#e3dfd9")
	onSurfaceVariant := pick(colors, "on_surface_variant", "#c4bfb8")
	return map[string]string{"class": primary, "enum": secondary, "enumMember": tertiary, "function": primary, "method": primary, "interface": secondary, "namespace": secondary, "parameter": onSurface, "property": secondary, "struct": secondary, "type": secondary, "typeParameter": tertiary, "variable": onSurface, "variable.constant": tertiary, "variable.defaultLibrary": errorCol, "comment": onSurfaceVariant + "cc", "keyword": secondary, "keyword.control": secondary, "number": tertiary, "string": tertiary, "regexp": tertiary, "operator": secondary}
}

func loadSettings(path string) (map[string]any, error) {
	settings := map[string]any{}
	data, err := os.ReadFile(path)
	if err == nil {
		if err := json.Unmarshal(data, &settings); err != nil {
			backup := path + ".backup"
			if strings.HasSuffix(path, ".json") {
				backup = strings.TrimSuffix(path, ".json") + ".json.backup"
			}
			if renameErr := os.Rename(path, backup); renameErr != nil {
				return nil, renameErr
			}
			settings = map[string]any{}
		}
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	return settings, nil
}

func writeSettings(path string, settings map[string]any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(settings, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return os.WriteFile(path, data, 0o644)
}

func readStringMapJSON(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, err
	}
	out := map[string]string{}
	for k, v := range raw {
		if s, ok := v.(string); ok {
			out[k] = s
		}
	}
	return out, nil
}

func parseSCSS(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	re := regexp.MustCompile(`\$(\w+):\s*(#[A-Fa-f0-9]{6});`)
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		match := re.FindStringSubmatch(strings.TrimSpace(line))
		if len(match) == 3 {
			out[match[1]] = match[2]
		}
	}
	return out, nil
}

func getSettingsPath(forkName string) string { return filepath.Join(configDir(), forkName, "User", "settings.json") }
func configDir() string {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return xdg
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config")
}
func dirExists(path string) bool { info, err := os.Stat(path); return err == nil && info.IsDir() }
func pick(m map[string]string, key, fallback string) string {
	if v, ok := m[key]; ok && v != "" {
		return v
	}
	return fallback
}
