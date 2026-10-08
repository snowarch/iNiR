package main

import (
	"encoding/json"
	"flag"
	"fmt"
	common "inir/scripts/colors/themegencommon"
	"math"
	"os"
	"path/filepath"
	"strings"
)

// stripJSONCComments removes // and /* */ comments and trailing commas from
// JSONC so encoding/json can parse it. String contents are preserved.
func stripJSONCComments(data []byte) []byte {
	var out strings.Builder
	out.Grow(len(data))

	inString := false
	escaped := false
	i := 0
	n := len(data)

	for i < n {
		c := data[i]

		if inString {
			out.WriteByte(c)
			if escaped {
				escaped = false
			} else if c == '\\' {
				escaped = true
			} else if c == '"' {
				inString = false
			}
			i++
			continue
		}

		switch {
		case c == '"':
			inString = true
			out.WriteByte(c)
			i++

		case c == '/' && i+1 < n && data[i+1] == '/':
			for i < n && data[i] != '\n' {
				i++
			}

		case c == '/' && i+1 < n && data[i+1] == '*':
			i += 2
			for i+1 < n && !(data[i] == '*' && data[i+1] == '/') {
				i++
			}
			if i+1 < n {
				i += 2
			} else {
				i = n
			}

		case c == ',' && i+1 < n:
			j := i + 1
			for j < n && (data[j] == ' ' || data[j] == '\t' || data[j] == '\n' || data[j] == '\r') {
				j++
			}
			if j < n && (data[j] == ']' || data[j] == '}') {
				i++
			} else {
				out.WriteByte(c)
				i++
			}

		default:
			out.WriteByte(c)
			i++
		}
	}

	return []byte(out.String())
}

const (
	themeName        = "iNiR Material"
	themeNameLight   = "iNiR Material Light"
	themeExtensionID = "inir-material-theme"
	themeFileName    = "inir-material-color-theme.json"
	themeFileLight   = "inir-material-light-color-theme.json"
	prevThemeKey     = "inir.previousColorTheme"
)

type stringSlice []string

type tokenRule struct {
	Scope    []string          `json:"scope"`
	Settings map[string]string `json:"settings"`
}

// Config dir name → extensions dir relative to $HOME
var vscodeExtDirs = map[string]string{
	"code":          ".vscode/extensions",
	"codium":        ".vscode-oss/extensions",
	"code-oss":      ".vscode-oss/extensions",
	"code-insiders": ".vscode-insiders/extensions",
	"cursor":        ".cursor/extensions",
	"windsurf":      ".windsurf/extensions",
	"windsurf-next": ".windsurf-next/extensions",
	"qoder":         ".qoder/extensions",
	"antigravity":   ".antigravity/extensions",
	"positron":      ".positron/extensions",
	"void":          ".void/extensions",
	"melty":         ".melty/extensions",
	"pearai":        ".pearai/extensions",
	"aide":          ".aide/extensions",
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

// ── Color manipulation helpers ──────────────────────────────────────────

type hsl struct{ h, s, l float64 }

func hexToHSL(hex string) hsl {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) < 6 {
		return hsl{}
	}
	r := float64(hexByte(hex[0:2])) / 255.0
	g := float64(hexByte(hex[2:4])) / 255.0
	b := float64(hexByte(hex[4:6])) / 255.0
	maxC := math.Max(r, math.Max(g, b))
	minC := math.Min(r, math.Min(g, b))
	l := (maxC + minC) / 2.0
	if maxC == minC {
		return hsl{0, 0, l}
	}
	d := maxC - minC
	var s float64
	if l > 0.5 {
		s = d / (2.0 - maxC - minC)
	} else {
		s = d / (maxC + minC)
	}
	var h float64
	switch maxC {
	case r:
		h = (g - b) / d
		if g < b {
			h += 6
		}
	case g:
		h = (b-r)/d + 2
	default:
		h = (r-g)/d + 4
	}
	return hsl{h * 60.0, s, l}
}

func hslToHex(c hsl) string {
	s := math.Max(0, math.Min(1, c.s))
	l := math.Max(0, math.Min(1, c.l))
	h := math.Mod(c.h, 360)
	if h < 0 {
		h += 360
	}
	ch := (1.0 - math.Abs(2.0*l-1.0)) * s
	x := ch * (1.0 - math.Abs(math.Mod(h/60.0, 2.0)-1.0))
	m := l - ch/2.0
	var r, g, b float64
	switch {
	case h < 60:
		r, g, b = ch, x, 0
	case h < 120:
		r, g, b = x, ch, 0
	case h < 180:
		r, g, b = 0, ch, x
	case h < 240:
		r, g, b = 0, x, ch
	case h < 300:
		r, g, b = x, 0, ch
	default:
		r, g, b = ch, 0, x
	}
	return fmt.Sprintf("#%02x%02x%02x", clamp255(r+m), clamp255(g+m), clamp255(b+m))
}

func saturateColor(hex string, factor, minSat float64) string {
	c := hexToHSL(hex)
	if c.s < 0.01 {
		return hex
	}
	c.s = math.Max(minSat, math.Min(1.0, c.s*factor))
	return hslToHex(c)
}

func blendColors(base, accent string, ratio float64) string {
	base = strings.TrimPrefix(base, "#")
	accent = strings.TrimPrefix(accent, "#")
	if len(base) < 6 || len(accent) < 6 {
		return "#" + base
	}
	r := int(float64(hexByte(base[0:2]))*(1-ratio) + float64(hexByte(accent[0:2]))*ratio)
	g := int(float64(hexByte(base[2:4]))*(1-ratio) + float64(hexByte(accent[2:4]))*ratio)
	b := int(float64(hexByte(base[4:6]))*(1-ratio) + float64(hexByte(accent[4:6]))*ratio)
	return fmt.Sprintf("#%02x%02x%02x", clampInt(r, 0, 255), clampInt(g, 0, 255), clampInt(b, 0, 255))
}

func adjustLightness(hex string, minL, maxL float64) string {
	c := hexToHSL(hex)
	c.l = math.Max(minL, math.Min(maxL, c.l))
	return hslToHex(c)
}

func relLuminance(hex string) float64 {
	h := strings.TrimPrefix(hex, "#")
	if len(h) < 6 {
		return 0
	}
	lin := func(v int) float64 {
		c := float64(v) / 255
		if c <= 0.03928 {
			return c / 12.92
		}
		return math.Pow((c+0.055)/1.055, 2.4)
	}
	return 0.2126*lin(hexByte(h[0:2])) + 0.7152*lin(hexByte(h[2:4])) + 0.0722*lin(hexByte(h[4:6]))
}

func contrastHex(a, b string) float64 {
	la, lb := relLuminance(a), relLuminance(b)
	if la < lb {
		la, lb = lb, la
	}
	return (la + 0.05) / (lb + 0.05)
}

// withContrast moves lightness away from the background until the ratio holds.
func withContrast(hex, bg string, ratio float64, dark bool) string {
	c := hexToHSL(hex)
	for i := 0; i < 60 && contrastHex(hslToHex(c), bg) < ratio; i++ {
		if dark {
			c.l = math.Min(0.96, c.l+0.01)
		} else {
			c.l = math.Max(0.04, c.l-0.01)
		}
	}
	return hslToHex(c)
}

// mutedInk is `fg` at `alpha` (0-255) over `bg`, kept translucent while that reads at 4.5:1 and otherwise the nearest
// solid colour that does: a comment stays quiet on any editor background, never under the ratio.
func mutedInk(fg, bg string, alpha int, dark bool) string {
	fg, bg = "#"+strings.TrimPrefix(fg, "#"), "#"+strings.TrimPrefix(bg, "#")
	a := float64(alpha) / 255
	mix := func(i int) int {
		return clampInt(int(float64(hexByte(fg[i:i+2]))*a+float64(hexByte(bg[i:i+2]))*(1-a)+0.5), 0, 255)
	}
	over := fmt.Sprintf("#%02x%02x%02x", mix(1), mix(3), mix(5))
	if contrastHex(over, bg) >= 4.5 {
		return fg + fmt.Sprintf("%02x", alpha)
	}
	return withContrast(fg, bg, 4.5, dark)
}

// syntaxColor keeps the ANSI hue of a slot and solves its lightness for the
// editor background: the dark range on a dark theme, a deep one on a light theme.
func syntaxColor(termColors map[string]string, primary, bg string, termIdx int) string {
	raw := pick(termColors, fmt.Sprintf("term%d", termIdx), "#888888")
	dark := hexToHSL(bg).l < 0.5
	if dark {
		// Pastel, like the best dark schemes (Catppuccin Mocha sits at s 0.5-0.6, l 0.75-0.85): a 2.1x boost
		// turned the terminal's green into a neon (hsl 83, 77 %, 64 %) that fought every warm palette.
		tuned := saturateColor(raw, 1.0, 0.42)
		if c := hexToHSL(tuned); c.s > 0.62 {
			c.s = 0.62
			tuned = hslToHex(c)
		}
		blended := blendColors(tuned, primary, 0.25)
		return withContrast(adjustLightness(blended, 0.72, 0.86), bg, 4.5, true)
	}
	boosted := saturateColor(raw, 1.2, 0.45)
	blended := blendColors(boosted, primary, 0.2)
	return withContrast(adjustLightness(blended, 0.22, 0.46), bg, 4.5, false)
}

func hexByte(s string) int {
	var v int
	fmt.Sscanf(s, "%x", &v)
	return v
}

func clamp255(v float64) int {
	return clampInt(int(v*255), 0, 255)
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// ── Extension management ────────────────────────────────────────────────

// Legacy extension IDs to clean up on first run
var legacyExtensionDirs = []string{"inir.inir-theme-1.0.0"}

func getExtensionsDir(forkKey string) string {
	home, _ := os.UserHomeDir()
	rel, ok := vscodeExtDirs[forkKey]
	if !ok {
		rel = "." + forkKey + "/extensions"
	}
	return filepath.Join(home, rel)
}

func isDarkTheme(colors map[string]string) bool {
	bg := pick(colors, "background", pick(colors, "surface", "#080809"))
	c := hexToHSL(bg)
	return c.l < 0.5
}

func cleanLegacyExtensions(forkKey string) {
	extBase := getExtensionsDir(forkKey)
	for _, legacy := range legacyExtensionDirs {
		legacyDir := filepath.Join(extBase, legacy)
		if dirExists(legacyDir) {
			os.RemoveAll(legacyDir)
		}
	}
}

// ensureExtensionRegistered adds our extension to the editor's extensions.json
// registry if absent. Editors like Cursor/Windsurf only load extensions listed
// here; physical presence in the directory is not enough.
func ensureExtensionRegistered(forkKey, extDir string) error {
	extBase := getExtensionsDir(forkKey)
	registryPath := filepath.Join(extBase, "extensions.json")

	var entries []map[string]any
	if data, err := os.ReadFile(registryPath); err == nil {
		_ = json.Unmarshal(data, &entries)
	}

	extID := "inir." + themeExtensionID
	for _, e := range entries {
		ident, _ := e["identifier"].(map[string]any)
		if id, _ := ident["id"].(string); id == extID {
			return nil // already registered
		}
	}

	entry := map[string]any{
		"identifier":       map[string]any{"id": extID},
		"version":          "1.0.0",
		"location":         map[string]any{"$mid": float64(1), "path": extDir, "scheme": "file"},
		"relativeLocation": themeExtensionID,
	}
	entries = append(entries, entry)

	data, err := json.Marshal(entries)
	if err != nil {
		return err
	}
	tmp := registryPath + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, registryPath)
}

// unregisterExtension removes our entry from extensions.json (companion to ensureExtensionRegistered)
func unregisterExtension(forkKey string) {
	registryPath := filepath.Join(getExtensionsDir(forkKey), "extensions.json")
	data, err := os.ReadFile(registryPath)
	if err != nil {
		return
	}
	var entries []map[string]any
	if err := json.Unmarshal(data, &entries); err != nil {
		return
	}
	extID := "inir." + themeExtensionID
	filtered := entries[:0]
	for _, e := range entries {
		ident, _ := e["identifier"].(map[string]any)
		if id, _ := ident["id"].(string); id == extID {
			continue
		}
		filtered = append(filtered, e)
	}
	if len(filtered) == len(entries) {
		return
	}
	out, err := json.Marshal(filtered)
	if err != nil {
		return
	}
	tmp := registryPath + ".tmp"
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return
	}
	os.Rename(tmp, registryPath)
}

func writeExtensionManifest(extDir string) error {
	manifest := map[string]any{
		"name":        themeExtensionID,
		"displayName": themeName,
		"description": "Dynamic Material You theme — auto-generated by iNiR from wallpaper colors",
		"version":     "1.0.0",
		"publisher":   "inir",
		"engines":     map[string]string{"vscode": "^1.34.0"},
		"categories":  []string{"Themes"},
		"contributes": map[string]any{
			"themes": []map[string]any{
				{"label": themeName, "uiTheme": "vs-dark", "path": "./themes/" + themeFileName, "_watch": true},
				{"label": themeNameLight, "uiTheme": "vs", "path": "./themes/" + themeFileLight, "_watch": true},
			},
		},
	}
	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(extDir, "package.json"), append(data, '\n'), 0o644)
}

// themeIdentity picks the entry VS Code knows the palette by: the uiTheme of
// each entry sets the base (webview class, unset colours), the file's own
// "type" is ignored.
func themeIdentity(colors map[string]string) (label, file string) {
	if isDarkTheme(colors) {
		return themeName, themeFileName
	}
	return themeNameLight, themeFileLight
}

func manifestHasLight(pkgPath string) bool {
	data, err := os.ReadFile(pkgPath)
	return err == nil && strings.Contains(string(data), themeFileLight)
}

func writeThemeFile(themePath string, colors, termColors map[string]string) error {
	if err := os.MkdirAll(filepath.Dir(themePath), 0o755); err != nil {
		return err
	}
	themeType := "dark"
	if !isDarkTheme(colors) {
		themeType = "light"
	}
	label, _ := themeIdentity(colors)
	theme := map[string]any{
		"$schema":              "vscode://schemas/color-theme",
		"name":                 label,
		"type":                 themeType,
		"colors":               generateColors(colors, termColors),
		"tokenColors":          generateSyntax(colors, termColors),
		"semanticHighlighting": true,
		"semanticTokenColors":  generateSemantic(colors, termColors),
	}
	data, err := json.MarshalIndent(theme, "", "  ")
	if err != nil {
		return err
	}
	// Atomic write: tmp + rename. VS Code's EventCoalescer normalizes
	// DELETE+CREATE into UPDATED, so _watch picks this up correctly.
	tmp := themePath + ".tmp"
	if err := os.WriteFile(tmp, append(data, '\n'), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, themePath)
}

// ── Main ────────────────────────────────────────────────────────────────

func main() {
	home, _ := os.UserHomeDir()
	defaultColors := filepath.Join(home, ".local/state/quickshell/user/generated/palette.json")
	defaultTerminal := filepath.Join(home, ".local/state/quickshell/user/generated/terminal.json")
	defaultSCSS := filepath.Join(home, ".local/state/quickshell/user/generated/material_colors.scss")
	colorsPath := flag.String("colors", defaultColors, "")
	terminalJSONPath := flag.String("terminal-json", defaultTerminal, "")
	scssPath := flag.String("scss", defaultSCSS, "")
	listForks := flag.Bool("list-forks", false, "List known forks and exit")
	stripMode := flag.Bool("strip", false, "Remove iNiR theme extension and clean settings.json")
	var forks stringSlice
	flag.Var(&forks, "forks", "Fork key(s) to target")
	flag.Parse()

	if *stripMode {
		results := stripAllThemes(forks)
		success := 0
		for _, ok := range results {
			if ok {
				success++
			}
		}
		fmt.Printf("Stripped themes from %d/%d forks\n", success, len(results))
		if success > 0 {
			os.Exit(0)
		}
		os.Exit(1)
	}
	if *listForks {
		fmt.Println("Known VSCode forks:")
		for key, name := range vscodeForks {
			path := getSettingsPath(name)
			installed := "✗"
			if dirExists(filepath.Dir(path)) {
				installed = "✓"
			}
			extInstalled := "✗"
			extDir := filepath.Join(getExtensionsDir(key), themeExtensionID)
			if dirExists(extDir) {
				extInstalled = "✓"
			}
			fmt.Printf("  [%s] %s: %s (ext: %s)\n", installed, key, name, extInstalled)
		}
		return
	}

	results, err := generateAllThemes(*colorsPath, *terminalJSONPath, *scssPath, forks)
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

func generateAllThemes(colorsPath, terminalJSONPath, scssPath string, forks []string) (map[string]bool, error) {
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
		ok, err := generateThemeForFork(colorsPath, terminalJSONPath, scssPath, settingsPath, forkKey)
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

func generateThemeForFork(colorsPath, terminalJSONPath, scssPath, settingsPath, forkKey string) (bool, error) {
	colors, err := common.ReadStringMapJSON(colorsPath)
	if err != nil {
		return false, fmt.Errorf("could not read %s", colorsPath)
	}
	termColors, _ := common.ParseSCSS(scssPath)
	if terminalJSONPath != "" {
		if explicitTerms, err := common.ReadStringMapJSON(terminalJSONPath); err == nil {
			for k, v := range explicitTerms {
				termColors[k] = v
			}
		}
	}

	// Clean up legacy extensions from older iNiR versions
	cleanLegacyExtensions(forkKey)

	// Install local extension with _watch: true.
	// Only write package.json once — rewriting mid-session causes extension host errors.
	extDir := filepath.Join(getExtensionsDir(forkKey), themeExtensionID)
	if err := os.MkdirAll(extDir, 0o755); err != nil {
		return false, fmt.Errorf("failed to create extension dir: %v", err)
	}
	pkgPath := filepath.Join(extDir, "package.json")
	if _, err := os.Stat(pkgPath); os.IsNotExist(err) || !manifestHasLight(pkgPath) {
		if err := writeExtensionManifest(extDir); err != nil {
			return false, fmt.Errorf("failed to write extension manifest: %v", err)
		}
	}

	// Register in extensions.json (Cursor/Windsurf require this; VS Code is more lenient)
	if err := ensureExtensionRegistered(forkKey, extDir); err != nil {
		fmt.Fprintf(os.Stderr, "  warn: extensions.json registration failed: %v\n", err)
	}

	// Write the theme file (atomic rename — _watch handles live reload)
	activeName, activeFile := themeIdentity(colors)
	themePath := filepath.Join(extDir, "themes", activeFile)
	if err := writeThemeFile(themePath, colors, termColors); err != nil {
		return false, fmt.Errorf("failed to write theme: %v", err)
	}

	// Only touch settings.json when needed: first activation or legacy cleanup.
	// Once our theme is active, _watch:true handles reload — no settings changes needed.
	settings, err := loadSettings(settingsPath)
	if err != nil {
		return false, err
	}
	currentTheme, _ := settings["workbench.colorTheme"].(string)
	settingsChanged := false

	// Save previous theme for restoration on strip
	if currentTheme != "" && currentTheme != themeName && currentTheme != themeNameLight {
		settings[prevThemeKey] = currentTheme
		settingsChanged = true
	}

	// Clean up old-style injection from previous iNiR versions
	for _, key := range []string{
		"workbench.colorCustomizations",
		"editor.tokenColorCustomizations",
		"editor.semanticTokenColorCustomizations",
	} {
		if _, exists := settings[key]; exists {
			delete(settings, key)
			settingsChanged = true
		}
	}

	// Activate our theme if not already active
	if currentTheme != activeName {
		settings["workbench.colorTheme"] = activeName
		settingsChanged = true
	}
	// If already our theme: do nothing. _watch:true reloads on file change.

	if settingsChanged {
		if err := writeSettings(settingsPath, settings); err != nil {
			return false, err
		}
	}
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
	m := map[string]string{
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
	if hexToHSL(bg).l >= 0.5 {
		lightenEdges(m, bg, onSurfaceVariant, outline, outlineVariant, primary)
	}
	if contrastHex(term("term0"), termBg) < 3 {
		m["terminal.ansiBlack"] = outline
	}
	return m
}

// lightenEdges gives a light theme the boundaries a tonal dark one gets from
// its darker surfaces: hairlines on the panels and a solid placeholder.
func lightenEdges(m map[string]string, bg, onSurfaceVariant, outline, outlineVariant, primary string) {
	for _, k := range []string{"panel.border", "sideBar.border", "editorGroup.border", "editorGroupHeader.tabsBorder", "tab.border", "activityBar.border", "statusBar.border", "titleBar.border"} {
		m[k] = outlineVariant
	}
	m["input.border"] = outline
	m["dropdown.border"] = outline
	m["checkbox.border"] = outline
	m["input.placeholderForeground"] = withContrast(onSurfaceVariant, bg, 4.5, false)
	m["editor.selectionBackground"] = primary + "40"
	m["editor.inactiveSelectionBackground"] = primary + "22"
}

func generateSyntax(colors, termColors map[string]string) []tokenRule {
	primary := pick(colors, "primary", "#d4b796")
	onSurface := pick(colors, "on_surface", "#e3dfd9")
	onSurfaceVariant := pick(colors, "on_surface_variant", "#c4bfb8")
	errorCol := saturateColor(pick(colors, "error", "#ffb4ab"), 1.4, 0.50)
	editorBg := pick(colors, "background", pick(colors, "surface", "#080809"))

	// ANSI palette: always has distinct hues regardless of wallpaper saturation
	colKeyword := syntaxColor(termColors, primary, editorBg, 5)  // magenta
	colString := syntaxColor(termColors, primary, editorBg, 2)   // green
	colFunction := syntaxColor(termColors, primary, editorBg, 4) // blue
	colType := syntaxColor(termColors, primary, editorBg, 6)     // cyan
	colConstant := syntaxColor(termColors, primary, editorBg, 3) // yellow
	colTag := syntaxColor(termColors, primary, editorBg, 1)      // red
	colProperty := withContrast(blendColors(syntaxColor(termColors, primary, editorBg, 4), syntaxColor(termColors, primary, editorBg, 6), 0.5), editorBg, 4.5, hexToHSL(editorBg).l < 0.5)

	return []tokenRule{
		// Comments — muted, italic
		{[]string{"comment", "punctuation.definition.comment"}, map[string]string{"foreground": mutedInk(onSurfaceVariant, editorBg, 0xaa, hexToHSL(editorBg).l < 0.5), "fontStyle": "italic"}},
		{[]string{"comment.block.documentation", "comment.block.javadoc"}, map[string]string{"foreground": mutedInk(onSurfaceVariant, editorBg, 0xcc, hexToHSL(editorBg).l < 0.5), "fontStyle": "italic"}},
		// Keywords & storage
		{[]string{"keyword", "storage.type", "storage.modifier"}, map[string]string{"foreground": colKeyword}},
		{[]string{"keyword.control", "keyword.control.flow"}, map[string]string{"foreground": colKeyword}},
		{[]string{"keyword.operator", "keyword.operator.assignment"}, map[string]string{"foreground": colKeyword}},
		{[]string{"keyword.other.unit"}, map[string]string{"foreground": colConstant}},
		// Constants & numbers
		{[]string{"constant", "constant.language", "constant.character"}, map[string]string{"foreground": colConstant}},
		{[]string{"constant.numeric", "constant.numeric.integer", "constant.numeric.float"}, map[string]string{"foreground": colConstant}},
		{[]string{"constant.other.color", "constant.other.symbol"}, map[string]string{"foreground": colConstant}},
		// Strings & literals
		{[]string{"string", "string.quoted"}, map[string]string{"foreground": colString}},
		{[]string{"string.regexp"}, map[string]string{"foreground": colTag}},
		{[]string{"string.template", "string.interpolated"}, map[string]string{"foreground": colString}},
		{[]string{"string.other.link"}, map[string]string{"foreground": colFunction}},
		{[]string{"punctuation.definition.string"}, map[string]string{"foreground": colString}},
		{[]string{"constant.character.escape", "string.escape"}, map[string]string{"foreground": colTag}},
		// Functions & methods
		{[]string{"entity.name.function", "support.function"}, map[string]string{"foreground": colFunction}},
		{[]string{"meta.function-call", "entity.name.function.call"}, map[string]string{"foreground": colFunction}},
		{[]string{"support.function.builtin"}, map[string]string{"foreground": colFunction}},
		{[]string{"entity.name.function.decorator", "meta.decorator"}, map[string]string{"foreground": colTag, "fontStyle": "italic"}},
		// Classes, types & interfaces
		{[]string{"entity.name.type", "entity.name.class", "support.type", "support.class"}, map[string]string{"foreground": colType}},
		{[]string{"entity.other.inherited-class"}, map[string]string{"foreground": colType, "fontStyle": "italic"}},
		{[]string{"entity.name.type.interface"}, map[string]string{"foreground": colType}},
		{[]string{"entity.name.type.enum"}, map[string]string{"foreground": colType}},
		{[]string{"support.type.builtin", "support.type.primitive"}, map[string]string{"foreground": colType}},
		// Variables
		{[]string{"variable", "variable.other"}, map[string]string{"foreground": onSurface}},
		{[]string{"variable.language"}, map[string]string{"foreground": colTag, "fontStyle": "italic"}},
		{[]string{"variable.parameter", "variable.parameter.function"}, map[string]string{"foreground": onSurface}},
		// Properties & attributes
		{[]string{"variable.other.property", "support.variable.property", "variable.other.object.property"}, map[string]string{"foreground": colProperty}},
		{[]string{"entity.other.attribute-name"}, map[string]string{"foreground": colProperty}},
		{[]string{"meta.object-literal.key"}, map[string]string{"foreground": colProperty}},
		// Tags (HTML/XML/JSX)
		{[]string{"entity.name.tag"}, map[string]string{"foreground": colTag}},
		{[]string{"punctuation.definition.tag"}, map[string]string{"foreground": colTag}},
		{[]string{"entity.name.tag.css"}, map[string]string{"foreground": colType}},
		{[]string{"support.type.property-name.css"}, map[string]string{"foreground": colProperty}},
		{[]string{"support.constant.property-value.css"}, map[string]string{"foreground": colConstant}},
		// Punctuation
		{[]string{"punctuation"}, map[string]string{"foreground": onSurface}},
		{[]string{"punctuation.separator", "punctuation.terminator"}, map[string]string{"foreground": onSurfaceVariant}},
		{[]string{"punctuation.section.embedded"}, map[string]string{"foreground": colTag}},
		// Markup (Markdown)
		{[]string{"markup.heading"}, map[string]string{"foreground": colFunction, "fontStyle": "bold"}},
		{[]string{"markup.bold"}, map[string]string{"foreground": onSurface, "fontStyle": "bold"}},
		{[]string{"markup.italic"}, map[string]string{"foreground": onSurface, "fontStyle": "italic"}},
		{[]string{"markup.underline.link"}, map[string]string{"foreground": colFunction, "fontStyle": "underline"}},
		{[]string{"markup.inline.raw", "markup.fenced_code"}, map[string]string{"foreground": colString}},
		{[]string{"markup.list"}, map[string]string{"foreground": colKeyword}},
		{[]string{"markup.deleted"}, map[string]string{"foreground": errorCol}},
		{[]string{"markup.inserted"}, map[string]string{"foreground": colString}},
		{[]string{"markup.changed"}, map[string]string{"foreground": colConstant}},
		// Invalid
		{[]string{"invalid"}, map[string]string{"foreground": errorCol}},
		{[]string{"invalid.deprecated"}, map[string]string{"foreground": errorCol, "fontStyle": "italic strikethrough"}},
	}
}

func generateSemantic(colors, termColors map[string]string) map[string]string {
	primary := pick(colors, "primary", "#d4b796")
	onSurface := pick(colors, "on_surface", "#e3dfd9")
	onSurfaceVariant := pick(colors, "on_surface_variant", "#c4bfb8")
	editorBg := pick(colors, "background", pick(colors, "surface", "#080809"))

	colKeyword := syntaxColor(termColors, primary, editorBg, 5)
	colString := syntaxColor(termColors, primary, editorBg, 2)
	colFunction := syntaxColor(termColors, primary, editorBg, 4)
	colType := syntaxColor(termColors, primary, editorBg, 6)
	colConstant := syntaxColor(termColors, primary, editorBg, 3)
	colTag := syntaxColor(termColors, primary, editorBg, 1)
	colProperty := withContrast(blendColors(syntaxColor(termColors, primary, editorBg, 4), syntaxColor(termColors, primary, editorBg, 6), 0.5), editorBg, 4.5, hexToHSL(editorBg).l < 0.5)

	return map[string]string{
		"class": colType, "enum": colType, "enumMember": colConstant,
		"function": colFunction, "method": colFunction,
		"interface": colType, "namespace": colType,
		"parameter": onSurface, "property": colProperty,
		"struct": colType, "type": colType, "typeParameter": colConstant,
		"variable": onSurface, "variable.constant": colConstant, "variable.defaultLibrary": colTag,
		"comment": mutedInk(onSurfaceVariant, editorBg, 0xaa, hexToHSL(editorBg).l < 0.5),
		"keyword": colKeyword, "keyword.control": colKeyword,
		"number": colConstant, "string": colString, "regexp": colTag,
		"operator": colKeyword, "decorator": colTag,
	}
}

// stripThemeForFork removes the iNiR extension and cleans settings.json
func stripThemeForFork(settingsPath, forkKey string) bool {
	// Remove the extension directory and registry entry
	extDir := filepath.Join(getExtensionsDir(forkKey), themeExtensionID)
	if dirExists(extDir) {
		if err := os.RemoveAll(extDir); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to remove extension dir %s: %v\n", extDir, err)
		}
	}
	unregisterExtension(forkKey)
	cleanLegacyExtensions(forkKey)

	// Clean settings.json
	data, err := os.ReadFile(settingsPath)
	if err != nil {
		return true // nothing to strip
	}
	var settings map[string]any
	if err := json.Unmarshal(stripJSONCComments(data), &settings); err != nil {
		return false
	}
	changed := false

	// Restore previous theme if we're the active one
	if current, ok := settings["workbench.colorTheme"].(string); ok && (current == themeName || current == themeNameLight) {
		if prev, ok := settings[prevThemeKey].(string); ok && prev != "" {
			settings["workbench.colorTheme"] = prev
		} else {
			delete(settings, "workbench.colorTheme")
		}
		changed = true
	}
	if _, ok := settings[prevThemeKey]; ok {
		delete(settings, prevThemeKey)
		changed = true
	}

	// Clean up legacy injection keys from any previous iNiR version
	for _, key := range []string{
		"workbench.colorCustomizations",
		"editor.tokenColorCustomizations",
		"editor.semanticTokenColorCustomizations",
	} {
		if _, ok := settings[key]; ok {
			delete(settings, key)
			changed = true
		}
	}
	if !changed {
		return true
	}
	if err := writeSettings(settingsPath, settings); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to write %s: %v\n", settingsPath, err)
		return false
	}
	return true
}

func stripAllThemes(forks []string) map[string]bool {
	selected := forks
	if len(selected) == 0 {
		for key, name := range vscodeForks {
			path := getSettingsPath(name)
			extDir := filepath.Join(getExtensionsDir(key), themeExtensionID)
			if fileExists(path) || dirExists(extDir) {
				selected = append(selected, key)
			}
		}
	}
	results := map[string]bool{}
	for _, forkKey := range selected {
		forkName, ok := vscodeForks[forkKey]
		if !ok {
			continue
		}
		path := getSettingsPath(forkName)
		results[forkKey] = stripThemeForFork(path, forkKey)
		if results[forkKey] {
			fmt.Printf("  ✓ %s\n", forkName)
		} else {
			fmt.Fprintf(os.Stderr, "  ✗ %s\n", forkName)
		}
	}
	return results
}

func loadSettings(path string) (map[string]any, error) {
	settings := map[string]any{}
	data, err := os.ReadFile(path)
	if err == nil {
		// VSCode settings.json is JSONC. Strip comments/trailing commas
		// before parsing so we never fall back to destroying the file.
		stripped := stripJSONCComments(data)
		if err := json.Unmarshal(stripped, &settings); err != nil {
			// Do not rename or overwrite the file on parse failure.
			// Return the error so the caller skips settings injection.
			return nil, fmt.Errorf("parse %s: %w", path, err)
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

func getSettingsPath(forkName string) string {
	return filepath.Join(configDir(), forkName, "User", "settings.json")
}
func configDir() string {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return xdg
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config")
}
func dirExists(path string) bool  { info, err := os.Stat(path); return err == nil && info.IsDir() }
func fileExists(path string) bool { _, err := os.Stat(path); return err == nil }
func pick(m map[string]string, key, fallback string) string {
	return common.Pick(m, key, fallback)
}
