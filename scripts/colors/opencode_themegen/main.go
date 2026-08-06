package main

import (
	"encoding/json"
	"fmt"
	common "inir/scripts/colors/themegencommon"
	"os"
	"path/filepath"
)

func main() {
	home, _ := os.UserHomeDir()
	defaultSCSS := filepath.Join(home, ".local/state/quickshell/user/generated/material_colors.scss")
	defaultPalette := filepath.Join(home, ".local/state/quickshell/user/generated/palette.json")
	defaultTerminal := filepath.Join(home, ".local/state/quickshell/user/generated/terminal.json")
	outputDir := filepath.Join(home, ".config/opencode/themes")

	scssPath := defaultSCSS
	if len(os.Args) >= 2 {
		scssPath = os.Args[1]
	}
	palettePath := defaultPalette
	if len(os.Args) >= 3 {
		palettePath = os.Args[2]
	}
	terminalPath := defaultTerminal
	if len(os.Args) >= 4 {
		terminalPath = os.Args[3]
	}
	if len(os.Args) >= 5 {
		outputDir = os.Args[4]
	}

	scssColors, err := common.ParseSCSS(scssPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s not found\n", scssPath)
		os.Exit(1)
	}
	paletteColors, _ := common.ReadStringMapJSON(palettePath)
	terminalColors, _ := common.ReadStringMapJSON(terminalPath)
	colors := common.MergeStringMaps(scssColors, paletteColors, terminalColors)

	theme := generateOpenCodeTheme(colors)
	if err := os.MkdirAll(outputDir, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	outputPath := filepath.Join(outputDir, "inir.json")
	data, err := json.MarshalIndent(theme, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	data = append(data, '\n')
	if err := os.WriteFile(outputPath, data, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("[opencode] Theme generated: %s\n", outputPath)
}

func generateOpenCodeTheme(colors map[string]string) map[string]any {
	primary := common.Pick(colors, "primary", "#7aa2f7")
	onPrimary := common.Pick(colors, "onPrimary", common.Pick(colors, "on_primary", "#1a1b26"))
	primaryContainer := common.Pick(colors, "primaryContainer", common.Pick(colors, "primary_container", "#004c6b"))
	onPrimaryContainer := common.Pick(colors, "onPrimaryContainer", common.Pick(colors, "on_primary_container", "#c6e7ff"))
	secondary := common.Pick(colors, "secondary", "#bb9af7")
	secondaryContainer := common.Pick(colors, "secondaryContainer", common.Pick(colors, "secondary_container", "#394b58"))
	tertiary := common.Pick(colors, "tertiary", "#9ece6a")
	tertiaryContainer := common.Pick(colors, "tertiaryContainer", common.Pick(colors, "tertiary_container", "#958bb1"))
	surface := common.Pick(colors, "surface", "#0f1417")
	surfaceDim := common.Pick(colors, "surfaceDim", common.Pick(colors, "surface_dim", "#0f1417"))
	surfaceBright := common.Pick(colors, "surfaceBright", common.Pick(colors, "surface_bright", "#353a3d"))
	surfaceContainer := common.Pick(colors, "surfaceContainer", common.Pick(colors, "surface_container", "#1c2024"))
	surfaceContainerLow := common.Pick(colors, "surfaceContainerLow", common.Pick(colors, "surface_container_low", "#181c1f"))
	surfaceContainerHigh := common.Pick(colors, "surfaceContainerHigh", common.Pick(colors, "surface_container_high", "#262b2e"))
	surfaceContainerHighest := common.Pick(colors, "surfaceContainerHighest", common.Pick(colors, "surface_container_highest", "#313539"))
	onSurface := common.Pick(colors, "onSurface", common.Pick(colors, "on_surface", "#dfe3e7"))
	onSurfaceVariant := common.Pick(colors, "onSurfaceVariant", common.Pick(colors, "on_surface_variant", "#c1c7ce"))
	outline := common.Pick(colors, "outline", "#8b9298")
	outlineVariant := common.Pick(colors, "outlineVariant", common.Pick(colors, "outline_variant", "#41484d"))
	shadow := common.Pick(colors, "shadow", "#000000")
	errorCol := common.Pick(colors, "error", "#ffb4ab")
	errorContainer := common.Pick(colors, "errorContainer", common.Pick(colors, "error_container", "#93000a"))
	success := common.Pick(colors, "success", "#b5ccba")
	successContainer := common.Pick(colors, "successContainer", common.Pick(colors, "success_container", "#374b3e"))
	inverseSurface := common.Pick(colors, "inverseSurface", common.Pick(colors, "inverse_surface", "#dfe3e7"))
	inverseOnSurface := common.Pick(colors, "inverseOnSurface", common.Pick(colors, "inverse_on_surface", "#2c3135"))
	inversePrimary := common.Pick(colors, "inversePrimary", common.Pick(colors, "inverse_primary", primary))

	term := map[int]string{}
	for i := range 16 {
		term[i] = common.Pick(colors, fmt.Sprintf("term%d", i), "#888888")
	}

	diffAddedBg := common.Blend(surfaceContainer, success, 0.15)
	diffRemovedBg := common.Blend(surfaceContainer, errorCol, 0.15)
	diffAddedLineBg := common.Blend(surfaceContainer, success, 0.10)
	diffRemovedLineBg := common.Blend(surfaceContainer, errorCol, 0.10)
	warning := common.Pick(colors, "term3", term[3])

	lightPrimary := inversePrimary
	lightSecondary := common.Blend(secondary, inverseSurface, 0.25)
	lightAccent := common.Blend(tertiary, inverseSurface, 0.25)
	lightError := common.Blend(errorCol, inverseSurface, 0.35)
	lightWarning := common.Blend(warning, inverseSurface, 0.40)
	lightSuccess := common.Blend(success, inverseSurface, 0.35)
	lightTextMuted := common.Blend(inverseOnSurface, inverseSurface, 0.35)
	lightBackgroundPanel := common.Blend(inverseSurface, "#ffffff", 0.06)
	lightBackgroundElement := common.Blend(inverseSurface, "#ffffff", 0.12)
	lightBackgroundMenu := common.Blend(inverseSurface, "#ffffff", 0.08)
	lightBorder := common.Blend(inverseOnSurface, inverseSurface, 0.55)
	lightBorderSubtle := common.Blend(inverseOnSurface, inverseSurface, 0.70)
	lightDiffAddedBg := common.Blend(inverseSurface, lightSuccess, 0.18)
	lightDiffRemovedBg := common.Blend(inverseSurface, lightError, 0.18)
	lightDiffAddedLineBg := common.Blend(inverseSurface, lightSuccess, 0.12)
	lightDiffRemovedLineBg := common.Blend(inverseSurface, lightError, 0.12)
	lightMarkdownLink := common.Blend(tertiary, inverseSurface, 0.20)
	lightMarkdownCode := common.Blend(term[2], inverseSurface, 0.20)
	lightSyntaxKeyword := common.Blend(term[5], inverseSurface, 0.25)
	lightSyntaxFunction := common.Blend(term[4], inverseSurface, 0.25)
	lightSyntaxVariable := common.Blend(term[6], inverseSurface, 0.20)
	lightSyntaxString := common.Blend(term[2], inverseSurface, 0.25)
	lightSyntaxNumber := common.Blend(term[13], inverseSurface, 0.25)
	lightSyntaxType := common.Blend(term[3], inverseSurface, 0.25)
	lightSelectedListItemText := inverseSurface

	themeValue := func(dark any, light any) map[string]any {
		return map[string]any{"dark": dark, "light": light}
	}

	defs := map[string]any{
		"m3Primary":                 primary,
		"m3OnPrimary":               onPrimary,
		"m3PrimaryContainer":        primaryContainer,
		"m3OnPrimaryContainer":      onPrimaryContainer,
		"m3Secondary":               secondary,
		"m3SecondaryContainer":      secondaryContainer,
		"m3Tertiary":                tertiary,
		"m3TertiaryContainer":       tertiaryContainer,
		"m3Surface":                 surface,
		"m3SurfaceDim":              surfaceDim,
		"m3SurfaceBright":           surfaceBright,
		"m3SurfaceContainer":        surfaceContainer,
		"m3SurfaceContainerLow":     surfaceContainerLow,
		"m3SurfaceContainerHigh":    surfaceContainerHigh,
		"m3SurfaceContainerHighest": surfaceContainerHighest,
		"m3OnSurface":               onSurface,
		"m3OnSurfaceVariant":        onSurfaceVariant,
		"m3Outline":                 outline,
		"m3OutlineVariant":          outlineVariant,
		"m3Error":                   errorCol,
		"m3ErrorContainer":          errorContainer,
		"m3Success":                 success,
		"m3SuccessContainer":        successContainer,
		"m3Shadow":                  shadow,
		"m3InverseSurface":          inverseSurface,
		"m3InverseOnSurface":        inverseOnSurface,
		"m3InversePrimary":          inversePrimary,
		"ansiRed":                   term[1],
		"ansiGreen":                 term[2],
		"ansiYellow":                term[3],
		"ansiBlue":                  term[4],
		"ansiMagenta":               term[5],
		"ansiCyan":                  term[6],
		"ansiBrightRed":             term[9],
		"ansiBrightGreen":           term[10],
		"ansiBrightYellow":          term[11],
		"ansiBrightBlue":            term[12],
		"ansiBrightMagenta":         term[13],
		"ansiBrightCyan":            term[14],
	}

	theme := map[string]any{
		"primary":                 themeValue("m3Primary", "m3InversePrimary"),
		"secondary":               themeValue("m3Secondary", lightSecondary),
		"accent":                  themeValue("m3Tertiary", lightAccent),
		"error":                   themeValue("m3Error", lightError),
		"warning":                 themeValue(warning, lightWarning),
		"success":                 themeValue("m3Success", lightSuccess),
		"info":                    themeValue("m3Primary", lightPrimary),
		"text":                    themeValue("m3OnSurface", "m3InverseOnSurface"),
		"textMuted":               themeValue("m3OnSurfaceVariant", lightTextMuted),
		"selectedListItemText":    themeValue("m3Surface", lightSelectedListItemText),
		"background":              themeValue("m3Surface", "m3InverseSurface"),
		"backgroundPanel":         themeValue("m3SurfaceContainer", lightBackgroundPanel),
		"backgroundElement":       themeValue("m3SurfaceContainerHigh", lightBackgroundElement),
		"backgroundMenu":          themeValue("m3SurfaceContainerHigh", lightBackgroundMenu),
		"border":                  themeValue("m3OutlineVariant", lightBorder),
		"borderActive":            themeValue("m3Primary", "m3InversePrimary"),
		"borderSubtle":            themeValue(common.Blend(outlineVariant, surface, 0.3), lightBorderSubtle),
		"diffAdded":               themeValue("m3Success", lightSuccess),
		"diffRemoved":             themeValue("m3Error", lightError),
		"diffContext":             themeValue("m3OnSurfaceVariant", lightTextMuted),
		"diffHunkHeader":          themeValue("m3Outline", lightBorder),
		"diffHighlightAdded":      themeValue("ansiBrightGreen", "ansiGreen"),
		"diffHighlightRemoved":    themeValue("ansiBrightRed", "ansiRed"),
		"diffAddedBg":             themeValue(diffAddedBg, lightDiffAddedBg),
		"diffRemovedBg":           themeValue(diffRemovedBg, lightDiffRemovedBg),
		"diffContextBg":           themeValue("m3SurfaceContainer", lightBackgroundPanel),
		"diffLineNumber":          themeValue("m3Outline", lightBorder),
		"diffAddedLineNumberBg":   themeValue(diffAddedLineBg, lightDiffAddedLineBg),
		"diffRemovedLineNumberBg": themeValue(diffRemovedLineBg, lightDiffRemovedLineBg),
		"markdownText":            themeValue("m3OnSurface", "m3InverseOnSurface"),
		"markdownHeading":         themeValue("m3Primary", "m3InversePrimary"),
		"markdownLink":            themeValue("m3Tertiary", lightMarkdownLink),
		"markdownLinkText":        themeValue("ansiCyan", "ansiBlue"),
		"markdownCode":            themeValue("ansiGreen", lightMarkdownCode),
		"markdownBlockQuote":      themeValue("m3OnSurfaceVariant", lightTextMuted),
		"markdownEmph":            themeValue("ansiYellow", lightWarning),
		"markdownStrong":          themeValue("ansiBrightYellow", warning),
		"markdownHorizontalRule":  themeValue("m3OutlineVariant", lightBorder),
		"markdownListItem":        themeValue("m3Primary", "m3InversePrimary"),
		"markdownListEnumeration": themeValue("m3Secondary", lightSecondary),
		"markdownImage":           themeValue("ansiMagenta", lightAccent),
		"markdownImageText":       themeValue("ansiBrightMagenta", "ansiMagenta"),
		"markdownCodeBlock":       themeValue("m3OnSurface", "m3InverseOnSurface"),
		"syntaxComment":           themeValue("m3Outline", lightTextMuted),
		"syntaxKeyword":           themeValue("ansiMagenta", lightSyntaxKeyword),
		"syntaxFunction":          themeValue("ansiBlue", lightSyntaxFunction),
		"syntaxVariable":          themeValue("ansiCyan", lightSyntaxVariable),
		"syntaxString":            themeValue("ansiGreen", lightSyntaxString),
		"syntaxNumber":            themeValue("ansiBrightMagenta", lightSyntaxNumber),
		"syntaxType":              themeValue("ansiYellow", lightSyntaxType),
		"syntaxOperator":          themeValue("m3OnSurfaceVariant", lightTextMuted),
		"syntaxPunctuation":       themeValue("m3OnSurfaceVariant", lightTextMuted),
		"thinkingOpacity":         0.6,
	}

	return map[string]any{
		"$schema": "https://opencode.ai/theme.json",
		"defs":    defs,
		"theme":   theme,
	}
}
