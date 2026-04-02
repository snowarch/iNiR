package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	hexColorRe      = regexp.MustCompile(`^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$`)
	termColorKeyRe  = regexp.MustCompile(`^term\d{1,2}$`)
	placeholderRe   = regexp.MustCompile(`\{\{colors\.([a-z0-9_]+)\.(dark|light)\.hex\}\}`)
	defaultTermCols = map[string]string{
		"term0":  "#1d1f21",
		"term1":  "#cc6666",
		"term2":  "#b5bd68",
		"term3":  "#f0c674",
		"term4":  "#81a2be",
		"term5":  "#b294bb",
		"term6":  "#8abeb7",
		"term7":  "#c5c8c6",
		"term8":  "#666666",
		"term9":  "#d54e53",
		"term10": "#b9ca4a",
		"term11": "#e7c547",
		"term12": "#7aa6da",
		"term13": "#c397d8",
		"term14": "#70c0ba",
		"term15": "#ffffff",
	}
)

type hsl struct {
	h float64
	s float64
	l float64
}

func isHexColor(v string) bool {
	return hexColorRe.MatchString(strings.TrimSpace(v))
}

func normalizeHex6(v string) string {
	v = strings.ToLower(strings.TrimSpace(v))
	v = strings.TrimPrefix(v, "#")
	if len(v) < 6 {
		return "#000000"
	}
	return "#" + v[:6]
}

func hexWithAlpha(hexColor, alpha string) string {
	return normalizeHex6(hexColor) + strings.ToLower(alpha)
}

func hexToHSL(hex string) hsl {
	hex = strings.TrimPrefix(strings.ToLower(hex), "#")
	if len(hex) < 6 {
		return hsl{}
	}
	rv, _ := strconv.ParseInt(hex[0:2], 16, 64)
	gv, _ := strconv.ParseInt(hex[2:4], 16, 64)
	bv, _ := strconv.ParseInt(hex[4:6], 16, 64)
	r := float64(rv) / 255.0
	g := float64(gv) / 255.0
	b := float64(bv) / 255.0
	maxC := math.Max(r, math.Max(g, b))
	minC := math.Min(r, math.Min(g, b))
	l := (maxC + minC) / 2.0
	if maxC == minC {
		return hsl{h: 0, s: 0, l: l}
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
	return hsl{h: h / 6.0, s: s, l: l}
}

func hslToHex(c hsl) string {
	h := c.h
	for h < 0 {
		h += 1
	}
	for h > 1 {
		h -= 1
	}
	s := math.Max(0, math.Min(1, c.s))
	l := math.Max(0, math.Min(1, c.l))
	var r, g, b float64
	if s == 0 {
		r, g, b = l, l, l
	} else {
		var q float64
		if l < 0.5 {
			q = l * (1 + s)
		} else {
			q = l + s - l*s
		}
		p := 2*l - q
		r = hueToRGB(p, q, h+1.0/3.0)
		g = hueToRGB(p, q, h)
		b = hueToRGB(p, q, h-1.0/3.0)
	}
	return fmt.Sprintf("#%02x%02x%02x", clamp255(r), clamp255(g), clamp255(b))
}

func hueToRGB(p, q, t float64) float64 {
	if t < 0 {
		t += 1
	}
	if t > 1 {
		t -= 1
	}
	if t < 1.0/6.0 {
		return p + (q-p)*6*t
	}
	if t < 1.0/2.0 {
		return q
	}
	if t < 2.0/3.0 {
		return p + (q-p)*(2.0/3.0-t)*6
	}
	return p
}

func clamp255(v float64) int {
	i := int(math.Round(v * 255))
	if i < 0 {
		return 0
	}
	if i > 255 {
		return 255
	}
	return i
}

func adjustLightness(hexColor string, factor float64) string {
	c := hexToHSL(hexColor)
	c.l = math.Max(0, math.Min(1, c.l*factor))
	return hslToHex(c)
}

func saturate(hexColor string, factor, minSat, additiveFloor, hueHint float64) string {
	c := hexToHSL(hexColor)
	if c.s < 0.001 {
		c.h = math.Mod(hueHint+1.0, 1.0)
	}
	boosted := math.Min(1.0, c.s*factor+additiveFloor*(1.0-c.s))
	if boosted < minSat {
		boosted = math.Min(1.0, boosted+minSat)
	}
	c.s = boosted
	return hslToHex(c)
}

func blendColors(baseHex, mixHex string, mixRatio float64) string {
	baseHex = strings.TrimPrefix(normalizeHex6(baseHex), "#")
	mixHex = strings.TrimPrefix(normalizeHex6(mixHex), "#")
	ratio := math.Max(0, math.Min(1, mixRatio))

	br, _ := strconv.ParseInt(baseHex[0:2], 16, 64)
	bg, _ := strconv.ParseInt(baseHex[2:4], 16, 64)
	bb, _ := strconv.ParseInt(baseHex[4:6], 16, 64)
	mr, _ := strconv.ParseInt(mixHex[0:2], 16, 64)
	mg, _ := strconv.ParseInt(mixHex[2:4], 16, 64)
	mb, _ := strconv.ParseInt(mixHex[4:6], 16, 64)

	r := int(math.Round(float64(br)*(1-ratio) + float64(mr)*ratio))
	g := int(math.Round(float64(bg)*(1-ratio) + float64(mg)*ratio))
	b := int(math.Round(float64(bb)*(1-ratio) + float64(mb)*ratio))
	return fmt.Sprintf("#%02x%02x%02x", clampInt(r, 0, 255), clampInt(g, 0, 255), clampInt(b, 0, 255))
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

func luminance(hexColor string) float64 {
	hexColor = strings.TrimPrefix(normalizeHex6(hexColor), "#")
	r, _ := strconv.ParseInt(hexColor[0:2], 16, 64)
	g, _ := strconv.ParseInt(hexColor[2:4], 16, 64)
	b, _ := strconv.ParseInt(hexColor[4:6], 16, 64)
	return float64(r)*0.299 + float64(g)*0.587 + float64(b)*0.114
}

func termColor(termColors map[string]string, idx int) string {
	key := fmt.Sprintf("term%d", idx)
	if v, ok := termColors[key]; ok && isHexColor(v) {
		return normalizeHex6(v)
	}
	if v, ok := defaultTermCols[key]; ok {
		return v
	}
	return "#ffffff"
}

func syntaxEntry(color string, fontStyle any, fontWeight any) map[string]any {
	return map[string]any{
		"color":       hexWithAlpha(color, "ff"),
		"font_style":  fontStyle,
		"font_weight": fontWeight,
	}
}

type syntaxToken struct {
	Color      string
	FontStyle  any
	FontWeight any
}

var oneDarkSyntaxDefaults = map[string]syntaxToken{
	"attribute":               {Color: "#74ade8"},
	"boolean":                 {Color: "#bf956a"},
	"comment":                 {Color: "#5d636f"},
	"comment.doc":             {Color: "#878e98"},
	"constant":                {Color: "#dfc184"},
	"constructor":             {Color: "#73ade9"},
	"embedded":                {Color: "#dce0e5"},
	"emphasis":                {Color: "#74ade8"},
	"emphasis.strong":         {Color: "#bf956a", FontWeight: 700},
	"enum":                    {Color: "#6eb4bf"},
	"function":                {Color: "#73ade9"},
	"hint":                    {Color: "#788ca6"},
	"keyword":                 {Color: "#b477cf"},
	"label":                   {Color: "#74ade8"},
	"link_text":               {Color: "#73ade9", FontStyle: "normal"},
	"link_uri":                {Color: "#6eb4bf"},
	"namespace":               {Color: "#dce0e5"},
	"number":                  {Color: "#bf956a"},
	"operator":                {Color: "#6eb4bf"},
	"predictive":              {Color: "#5a6a87", FontStyle: "italic"},
	"preproc":                 {Color: "#dce0e5"},
	"primary":                 {Color: "#acb2be"},
	"property":                {Color: "#d07277"},
	"punctuation":             {Color: "#acb2be"},
	"punctuation.bracket":     {Color: "#b2b9c6"},
	"punctuation.delimiter":   {Color: "#b2b9c6"},
	"punctuation.list_marker": {Color: "#d07277"},
	"punctuation.markup":      {Color: "#d07277"},
	"punctuation.special":     {Color: "#b1574b"},
	"selector":                {Color: "#dfc184"},
	"selector.pseudo":         {Color: "#74ade8"},
	"string":                  {Color: "#a1c181"},
	"string.escape":           {Color: "#878e98"},
	"string.regex":            {Color: "#bf956a"},
	"string.special":          {Color: "#bf956a"},
	"string.special.symbol":   {Color: "#bf956a"},
	"tag":                     {Color: "#74ade8"},
	"text.literal":            {Color: "#a1c181"},
	"title":                   {Color: "#d07277", FontWeight: 400},
	"type":                    {Color: "#6eb4bf"},
	"variable":                {Color: "#acb2be"},
	"variable.special":        {Color: "#bf956a"},
	"variant":                 {Color: "#73ade9"},
}

var oneLightSyntaxDefaults = map[string]syntaxToken{
	"attribute":               {Color: "#5c78e2"},
	"boolean":                 {Color: "#ad6e25"},
	"comment":                 {Color: "#a2a3a7"},
	"comment.doc":             {Color: "#7c7e86"},
	"constant":                {Color: "#c18401"},
	"constructor":             {Color: "#5c78e2"},
	"embedded":                {Color: "#242529"},
	"emphasis":                {Color: "#5c78e2"},
	"emphasis.strong":         {Color: "#ad6e25", FontWeight: 700},
	"enum":                    {Color: "#3882b7"},
	"function":                {Color: "#5b79e3"},
	"hint":                    {Color: "#7274a7"},
	"keyword":                 {Color: "#a449ab"},
	"label":                   {Color: "#5c78e2"},
	"link_text":               {Color: "#5b79e3", FontStyle: "italic"},
	"link_uri":                {Color: "#3882b7"},
	"namespace":               {Color: "#242529"},
	"number":                  {Color: "#ad6e25"},
	"operator":                {Color: "#3882b7"},
	"predictive":              {Color: "#9b9ec6", FontStyle: "italic"},
	"preproc":                 {Color: "#242529"},
	"primary":                 {Color: "#242529"},
	"property":                {Color: "#d3604f"},
	"punctuation":             {Color: "#242529"},
	"punctuation.bracket":     {Color: "#4d4f52"},
	"punctuation.delimiter":   {Color: "#4d4f52"},
	"punctuation.list_marker": {Color: "#d3604f"},
	"punctuation.markup":      {Color: "#d3604f"},
	"punctuation.special":     {Color: "#b92b46"},
	"selector":                {Color: "#669f59"},
	"selector.pseudo":         {Color: "#5c78e2"},
	"string":                  {Color: "#649f57"},
	"string.escape":           {Color: "#7c7e86"},
	"string.regex":            {Color: "#ad6e26"},
	"string.special":          {Color: "#ad6e26"},
	"string.special.symbol":   {Color: "#ad6e26"},
	"tag":                     {Color: "#5c78e2"},
	"text.literal":            {Color: "#649f57"},
	"title":                   {Color: "#d3604f", FontWeight: 400},
	"type":                    {Color: "#3882b7"},
	"variable":                {Color: "#242529"},
	"variable.special":        {Color: "#ad6e25"},
	"variant":                 {Color: "#5b79e3"},
}

func buildSyntaxMap(primary, appearance string) map[string]any {
	// Start from Zed's built-in One Dark/One Light syntax defaults,
	// then blend in the generated theme primary for cohesion.
	mixRatio := 0.50
	defaults := oneDarkSyntaxDefaults
	if appearance == "light" {
		defaults = oneLightSyntaxDefaults
	}
	syntax := map[string]any{}
	for token, spec := range defaults {
		syntax[token] = syntaxEntry(
			blendColors(spec.Color, primary, mixRatio),
			spec.FontStyle,
			spec.FontWeight,
		)
	}
	return syntax
}

func applyBorderPalette(dst, src map[string]any) {
	for _, key := range []string{
		"border",
		"border.variant",
		"border.focused",
		"border.selected",
		"border.transparent",
		"border.disabled",
		"scrollbar.thumb.border",
		"scrollbar.track.border",
		"panel.focused_border",
		"pane.focused_border",
	} {
		if v, ok := src[key]; ok {
			dst[key] = v
		}
	}
}

func deepCopyMap(in map[string]any) map[string]any {
	b, _ := json.Marshal(in)
	var out map[string]any
	_ = json.Unmarshal(b, &out)
	return out
}

func makeBorderlessStyle(style map[string]any) map[string]any {
	out := deepCopyMap(style)
	for _, key := range []string{
		"border",
		"border.variant",
		"border.focused",
		"border.selected",
		"border.transparent",
		"border.disabled",
		"scrollbar.thumb.border",
		"scrollbar.track.border",
	} {
		if _, ok := out[key]; ok {
			out[key] = "#00000000"
		}
	}
	out["panel.focused_border"] = nil
	out["pane.focused_border"] = nil
	return out
}

func sanitizeHexMap(in map[string]string) map[string]string {
	out := map[string]string{}
	for k, v := range in {
		if isHexColor(v) {
			out[k] = strings.ToLower(v)
		}
	}
	return out
}

func parseTermMap(in map[string]string) map[string]string {
	out := map[string]string{}
	for k, v := range in {
		if termColorKeyRe.MatchString(k) && isHexColor(v) {
			out[k] = strings.ToLower(v)
		}
	}
	return out
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
	re := regexp.MustCompile(`\$(\w+):\s*(#[A-Fa-f0-9]{6}|True|False);`)
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		match := re.FindStringSubmatch(strings.TrimSpace(line))
		if len(match) == 3 {
			out[match[1]] = match[2]
		}
	}
	return out, nil
}

func readStringJSON(path string) map[string]string {
	m, err := readStringMapJSON(path)
	if err != nil {
		return map[string]string{}
	}
	return m
}

func buildStyles(myColors map[string]string, termColors map[string]string) (map[string]any, map[string]any, map[string]string, map[string]string) {
	surfaceLum := luminance(pick(myColors, "surface", "#000000"))
	isDark := surfaceLum < 128

	var dkSurface, dkSurfaceLow, dkSurfaceStd, dkSurfaceHigh, dkSurfaceHighest string
	var dkOnSurface, dkOnSurfaceVariant, dkOutline, dkOutlineVariant string
	var ltSurface, ltSurfaceLow, ltSurfaceStd, ltSurfaceHigh, ltSurfaceHighest string
	var ltOnSurface, ltOnSurfaceVariant, ltOutline, ltOutlineVariant string

	if isDark {
		dkSurface = pick(myColors, "surface", "#1a1b26")
		dkSurfaceLow = pick(myColors, "surface_container_low", "#24283b")
		dkSurfaceStd = pick(myColors, "surface_container", "#414868")
		dkSurfaceHigh = pick(myColors, "surface_container_high", "#565f89")
		dkSurfaceHighest = pick(myColors, "surface_container_highest", "#3d3231")
		dkOnSurface = pick(myColors, "on_surface", "#c0caf5")
		dkOnSurfaceVariant = pick(myColors, "on_surface_variant", "#9aa5ce")
		dkOutline = pick(myColors, "outline", "#565f89")
		dkOutlineVariant = pick(myColors, "outline_variant", "#534341")
		ltSurface = pick(myColors, "inverse_surface", "#f1dedc")
		ltOnSurface = pick(myColors, "inverse_on_surface", "#392e2c")
		ltOnSurfaceVariant = pick(myColors, "outline_variant", "#534341")
		ltOutline = pick(myColors, "outline", "#565f89")
		ltOutlineVariant = pick(myColors, "outline_variant", "#534341")
		ltSurfaceLow = adjustLightness(ltSurface, 0.97)
		ltSurfaceStd = adjustLightness(ltSurface, 0.94)
		ltSurfaceHigh = adjustLightness(ltSurface, 0.91)
		ltSurfaceHighest = adjustLightness(ltSurface, 0.88)
	} else {
		ltSurface = pick(myColors, "surface", "#fff8f7")
		ltSurfaceLow = pick(myColors, "surface_container_low", "#fff0f2")
		ltSurfaceStd = pick(myColors, "surface_container", "#fbeaec")
		ltSurfaceHigh = pick(myColors, "surface_container_high", "#f5e4e6")
		ltSurfaceHighest = pick(myColors, "surface_container_highest", "#efdee0")
		ltOnSurface = pick(myColors, "on_surface", "#22191b")
		ltOnSurfaceVariant = pick(myColors, "on_surface_variant", "#514346")
		ltOutline = pick(myColors, "outline", "#847376")
		ltOutlineVariant = pick(myColors, "outline_variant", "#d6c2c4")
		dkSurface = pick(myColors, "inverse_surface", "#382e30")
		dkOnSurface = pick(myColors, "inverse_on_surface", "#feedef")
		dkOnSurfaceVariant = pick(myColors, "outline_variant", "#d6c2c4")
		dkOutline = pick(myColors, "outline", "#847376")
		dkOutlineVariant = pick(myColors, "outline_variant", "#d6c2c4")
		dkSurfaceLow = adjustLightness(dkSurface, 1.15)
		dkSurfaceStd = adjustLightness(dkSurface, 1.35)
		dkSurfaceHigh = adjustLightness(dkSurface, 1.55)
		dkSurfaceHighest = adjustLightness(dkSurface, 1.75)
	}

	primary := pick(myColors, "primary", "#7aa2f7")
	secondary := pick(myColors, "secondary", "#bb9af7")
	tertiary := pick(myColors, "tertiary", "#9ece6a")
	errorCol := pick(myColors, "error", "#f7768e")

	darkStyle := map[string]any{
		"border":                                     hexWithAlpha(dkOnSurface, "20"),
		"border.variant":                             hexWithAlpha(dkSurface, "20"),
		"border.focused":                             hexWithAlpha(dkSurface, "40"),
		"border.selected":                            hexWithAlpha(dkSurface, "ff"),
		"border.transparent":                         hexWithAlpha(dkSurface, "20"),
		"border.disabled":                            hexWithAlpha(dkOutlineVariant, "60"),
		"elevated_surface.background":                hexWithAlpha(dkSurfaceLow, "ff"),
		"surface.background":                         hexWithAlpha(dkSurfaceLow, "ff"),
		"background":                                 hexWithAlpha(dkSurface, "ff"),
		"element.background":                         hexWithAlpha(dkSurfaceLow, "ff"),
		"element.hover":                              hexWithAlpha(dkSurfaceStd, "ff"),
		"element.active":                             hexWithAlpha(dkSurfaceHigh, "ff"),
		"element.selected":                           hexWithAlpha(dkSurfaceHigh, "ff"),
		"element.disabled":                           hexWithAlpha(dkSurfaceLow, "ff"),
		"drop_target.background":                     hexWithAlpha(primary, "80"),
		"ghost_element.background":                   "#00000000",
		"ghost_element.hover":                        hexWithAlpha(dkSurfaceStd, "ff"),
		"ghost_element.active":                       hexWithAlpha(dkSurfaceHigh, "ff"),
		"ghost_element.selected":                     hexWithAlpha(dkSurfaceHigh, "ff"),
		"ghost_element.disabled":                     hexWithAlpha(dkSurfaceLow, "ff"),
		"text":                                       hexWithAlpha(dkOnSurface, "ff"),
		"text.muted":                                 hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"text.placeholder":                           hexWithAlpha(adjustLightness(dkOnSurfaceVariant, 0.7), "ff"),
		"text.disabled":                              hexWithAlpha(adjustLightness(dkOnSurfaceVariant, 0.6), "ff"),
		"text.accent":                                hexWithAlpha(primary, "ff"),
		"icon":                                       hexWithAlpha(dkOnSurface, "ff"),
		"icon.muted":                                 hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"icon.disabled":                              hexWithAlpha(adjustLightness(dkOnSurfaceVariant, 0.6), "ff"),
		"icon.placeholder":                           hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"icon.accent":                                hexWithAlpha(primary, "ff"),
		"status_bar.background":                      hexWithAlpha(dkSurface, "ff"),
		"title_bar.background":                       hexWithAlpha(dkSurface, "ff"),
		"title_bar.inactive_background":              hexWithAlpha(dkSurfaceLow, "ff"),
		"toolbar.background":                         hexWithAlpha(dkSurfaceLow, "ff"),
		"tab_bar.background":                         hexWithAlpha(dkSurfaceLow, "ff"),
		"tab.inactive_background":                    hexWithAlpha(dkSurfaceLow, "ff"),
		"tab.active_background":                      hexWithAlpha(adjustLightness(dkSurface, 0.9), "ff"),
		"search.match_background":                    hexWithAlpha(primary, "66"),
		"search.active_match_background":             hexWithAlpha(tertiary, "66"),
		"panel.background":                           hexWithAlpha(dkSurfaceLow, "ff"),
		"panel.focused_border":                       nil,
		"pane.focused_border":                        nil,
		"scrollbar.thumb.background":                 hexWithAlpha(dkOnSurfaceVariant, "4c"),
		"scrollbar.thumb.hover_background":           hexWithAlpha(dkSurfaceHigh, "ff"),
		"scrollbar.thumb.border":                     hexWithAlpha(dkSurfaceStd, "ff"),
		"scrollbar.track.background":                 "#00000000",
		"scrollbar.track.border":                     hexWithAlpha(dkSurfaceStd, "ff"),
		"editor.foreground":                          hexWithAlpha(dkOnSurface, "ff"),
		"editor.background":                          hexWithAlpha(dkSurface, "ff"),
		"editor.gutter.background":                   hexWithAlpha(dkSurface, "ff"),
		"editor.subheader.background":                hexWithAlpha(dkSurfaceLow, "ff"),
		"editor.active_line.background":              hexWithAlpha(dkSurfaceLow, "bf"),
		"editor.highlighted_line.background":         hexWithAlpha(dkSurfaceStd, "ff"),
		"editor.line_number":                         hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"editor.active_line_number":                  hexWithAlpha(dkOnSurface, "ff"),
		"editor.hover_line_number":                   hexWithAlpha(adjustLightness(dkOnSurface, 1.1), "ff"),
		"editor.invisible":                           hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"editor.wrap_guide":                          hexWithAlpha(dkOnSurfaceVariant, "0d"),
		"editor.active_wrap_guide":                   hexWithAlpha(dkOnSurfaceVariant, "1a"),
		"editor.document_highlight.read_background":  hexWithAlpha(primary, "1a"),
		"editor.document_highlight.write_background": hexWithAlpha(dkSurfaceStd, "66"),
		"terminal.background":                        hexWithAlpha(dkSurface, "ff"),
		"terminal.foreground":                        hexWithAlpha(dkOnSurface, "ff"),
		"terminal.bright_foreground":                 hexWithAlpha(dkOnSurface, "ff"),
		"terminal.dim_foreground":                    hexWithAlpha(adjustLightness(dkOnSurface, 0.6), "ff"),
		"link_text.hover":                            hexWithAlpha(primary, "ff"),
		"version_control.added":                      hexWithAlpha(tertiary, "ff"),
		"version_control.modified":                   hexWithAlpha(adjustLightness(primary, 0.8), "ff"),
		"version_control.word_added":                 hexWithAlpha(tertiary, "59"),
		"version_control.word_deleted":               hexWithAlpha(errorCol, "cc"),
		"version_control.deleted":                    hexWithAlpha(errorCol, "ff"),
		"version_control.conflict_marker.ours":       hexWithAlpha(tertiary, "1a"),
		"version_control.conflict_marker.theirs":     hexWithAlpha(primary, "1a"),
		"conflict":                                   hexWithAlpha(adjustLightness(tertiary, 0.8), "ff"),
		"conflict.background":                        hexWithAlpha(adjustLightness(tertiary, 0.8), "1a"),
		"conflict.border":                            hexWithAlpha(adjustLightness(tertiary, 0.6), "ff"),
		"created":                                    hexWithAlpha(tertiary, "ff"),
		"created.background":                         hexWithAlpha(tertiary, "1a"),
		"created.border":                             hexWithAlpha(adjustLightness(tertiary, 0.6), "ff"),
		"deleted":                                    hexWithAlpha(errorCol, "ff"),
		"deleted.background":                         hexWithAlpha(errorCol, "1a"),
		"deleted.border":                             hexWithAlpha(adjustLightness(errorCol, 0.6), "ff"),
		"error":                                      hexWithAlpha(errorCol, "ff"),
		"error.background":                           hexWithAlpha(errorCol, "1a"),
		"error.border":                               hexWithAlpha(adjustLightness(errorCol, 0.6), "ff"),
		"hidden":                                     hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"hidden.background":                          hexWithAlpha(adjustLightness(dkOnSurfaceVariant, 0.3), "1a"),
		"hidden.border":                              hexWithAlpha(dkOutline, "ff"),
		"hint":                                       hexWithAlpha(adjustLightness(primary, 0.7), "ff"),
		"hint.background":                            hexWithAlpha(adjustLightness(primary, 0.7), "1a"),
		"hint.border":                                hexWithAlpha(adjustLightness(primary, 0.6), "ff"),
		"ignored":                                    hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"ignored.background":                         hexWithAlpha(adjustLightness(dkOnSurfaceVariant, 0.3), "1a"),
		"ignored.border":                             hexWithAlpha(dkOutline, "ff"),
		"info":                                       hexWithAlpha(primary, "ff"),
		"info.background":                            hexWithAlpha(primary, "1a"),
		"info.border":                                hexWithAlpha(adjustLightness(primary, 0.6), "ff"),
		"modified.background":                        hexWithAlpha(adjustLightness(primary, 0.8), "1a"),
		"modified.border":                            hexWithAlpha(primary, "ff"),
		"predictive":                                 hexWithAlpha(adjustLightness(secondary, 0.8), "ff"),
		"predictive.background":                      hexWithAlpha(adjustLightness(secondary, 0.8), "1a"),
		"predictive.border":                          hexWithAlpha(secondary, "ff"),
		"renamed":                                    hexWithAlpha(primary, "ff"),
		"renamed.background":                         hexWithAlpha(primary, "1a"),
		"renamed.border":                             hexWithAlpha(adjustLightness(primary, 0.6), "ff"),
		"success":                                    hexWithAlpha(tertiary, "ff"),
		"success.background":                         hexWithAlpha(tertiary, "1a"),
		"success.border":                             hexWithAlpha(adjustLightness(tertiary, 0.6), "ff"),
		"unreachable":                                hexWithAlpha(dkOnSurfaceVariant, "ff"),
		"unreachable.background":                     hexWithAlpha(adjustLightness(dkOnSurfaceVariant, 0.3), "1a"),
		"unreachable.border":                         hexWithAlpha(dkOutline, "ff"),
		"warning":                                    hexWithAlpha(adjustLightness(tertiary, 0.9), "ff"),
		"warning.background":                         hexWithAlpha(adjustLightness(tertiary, 0.9), "1a"),
		"warning.border":                             hexWithAlpha(adjustLightness(tertiary, 0.9), "ff"),
	}

	darkStyle["terminal.ansi.black"] = hexWithAlpha(termColor(termColors, 0), "ff")
	darkStyle["terminal.ansi.bright_black"] = hexWithAlpha(termColor(termColors, 8), "ff")
	darkStyle["terminal.ansi.dim_black"] = hexWithAlpha(adjustLightness(termColor(termColors, 0), 0.6), "ff")
	for name, idx := range map[string]int{
		"red": 1, "bright_red": 9, "dim_red": 1,
		"green": 2, "bright_green": 10, "dim_green": 2,
		"yellow": 3, "bright_yellow": 11, "dim_yellow": 3,
		"blue": 4, "bright_blue": 12, "dim_blue": 4,
		"magenta": 5, "bright_magenta": 13, "dim_magenta": 5,
		"cyan": 6, "bright_cyan": 14, "dim_cyan": 6,
		"white": 7, "bright_white": 15, "dim_white": 7,
	} {
		base := termColor(termColors, idx)
		c := base
		if strings.Contains(name, "bright") {
			c = adjustLightness(base, 1.2)
		} else if strings.Contains(name, "dim") {
			c = adjustLightness(base, 0.7)
		}
		darkStyle["terminal.ansi."+name] = hexWithAlpha(c, "ff")
	}
	playerColors := []string{
		primary, errorCol, adjustLightness(tertiary, 0.8), secondary,
		adjustLightness(secondary, 1.2), adjustLightness(errorCol, 0.8),
		adjustLightness(tertiary, 0.9), adjustLightness(primary, 0.8),
	}
	players := []any{}
	for _, c := range playerColors {
		players = append(players, map[string]any{
			"cursor":     hexWithAlpha(c, "ff"),
			"background": hexWithAlpha(c, "ff"),
			"selection":  hexWithAlpha(c, "3d"),
		})
	}
	darkStyle["players"] = players
	darkStyle["syntax"] = buildSyntaxMap(primary, "dark")

	lighten := func(color string, factor float64) string { return adjustLightness(color, factor) }
	darken := func(color string, factor float64) string { return adjustLightness(color, factor) }
	sat := func(color string, factor float64) string {
		return saturate(color, factor, 0.38, 0.22, 0.0)
	}

	lightStyle := map[string]any{
		"border":                                     hexWithAlpha(ltOnSurface, "20"),
		"border.variant":                             hexWithAlpha(ltSurface, "20"),
		"border.focused":                             hexWithAlpha(ltSurface, "40"),
		"border.selected":                            hexWithAlpha(ltSurface, "ff"),
		"border.transparent":                         hexWithAlpha(ltSurface, "20"),
		"border.disabled":                            hexWithAlpha(ltOutlineVariant, "60"),
		"elevated_surface.background":                hexWithAlpha(ltSurfaceLow, "ff"),
		"surface.background":                         hexWithAlpha(ltSurfaceLow, "ff"),
		"background":                                 hexWithAlpha(ltSurface, "ff"),
		"element.background":                         hexWithAlpha(ltSurfaceStd, "ff"),
		"element.hover":                              hexWithAlpha(ltSurfaceHigh, "ff"),
		"element.active":                             hexWithAlpha(ltSurfaceHighest, "ff"),
		"element.selected":                           hexWithAlpha(ltSurfaceHighest, "ff"),
		"element.disabled":                           hexWithAlpha(ltSurfaceLow, "ff"),
		"drop_target.background":                     hexWithAlpha(primary, "30"),
		"ghost_element.background":                   "#00000000",
		"ghost_element.hover":                        hexWithAlpha(ltSurfaceHigh, "ff"),
		"ghost_element.active":                       hexWithAlpha(ltSurfaceHighest, "ff"),
		"ghost_element.selected":                     hexWithAlpha(ltSurfaceHighest, "ff"),
		"ghost_element.disabled":                     hexWithAlpha(ltSurfaceLow, "ff"),
		"text":                                       hexWithAlpha(ltOnSurface, "ff"),
		"text.muted":                                 hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"text.placeholder":                           hexWithAlpha(lighten(ltOnSurfaceVariant, 1.3), "ff"),
		"text.disabled":                              hexWithAlpha(lighten(ltOnSurfaceVariant, 1.5), "ff"),
		"text.accent":                                hexWithAlpha(primary, "ff"),
		"icon":                                       hexWithAlpha(ltOnSurface, "ff"),
		"icon.muted":                                 hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"icon.disabled":                              hexWithAlpha(lighten(ltOnSurfaceVariant, 1.5), "ff"),
		"icon.placeholder":                           hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"icon.accent":                                hexWithAlpha(primary, "ff"),
		"status_bar.background":                      hexWithAlpha(ltSurface, "ff"),
		"title_bar.background":                       hexWithAlpha(ltSurface, "ff"),
		"title_bar.inactive_background":              hexWithAlpha(ltSurfaceLow, "ff"),
		"toolbar.background":                         hexWithAlpha(ltSurfaceLow, "ff"),
		"tab_bar.background":                         hexWithAlpha(ltSurfaceLow, "ff"),
		"tab.inactive_background":                    hexWithAlpha(ltSurfaceLow, "ff"),
		"tab.active_background":                      hexWithAlpha(ltSurface, "ff"),
		"search.match_background":                    hexWithAlpha(primary, "40"),
		"search.active_match_background":             hexWithAlpha(tertiary, "40"),
		"panel.background":                           hexWithAlpha(ltSurfaceLow, "ff"),
		"panel.focused_border":                       nil,
		"pane.focused_border":                        nil,
		"scrollbar.thumb.background":                 hexWithAlpha(ltOnSurfaceVariant, "4c"),
		"scrollbar.thumb.hover_background":           hexWithAlpha(ltOnSurfaceVariant, "80"),
		"scrollbar.thumb.border":                     hexWithAlpha(ltOnSurfaceVariant, "60"),
		"scrollbar.track.background":                 "#00000000",
		"scrollbar.track.border":                     hexWithAlpha(ltOutlineVariant, "ff"),
		"editor.foreground":                          hexWithAlpha(ltOnSurface, "ff"),
		"editor.background":                          hexWithAlpha(ltSurface, "ff"),
		"editor.gutter.background":                   hexWithAlpha(ltSurface, "ff"),
		"editor.subheader.background":                hexWithAlpha(ltSurfaceLow, "ff"),
		"editor.active_line.background":              hexWithAlpha(ltSurfaceStd, "bf"),
		"editor.highlighted_line.background":         hexWithAlpha(ltSurfaceHigh, "ff"),
		"editor.line_number":                         hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"editor.active_line_number":                  hexWithAlpha(ltOnSurface, "ff"),
		"editor.hover_line_number":                   hexWithAlpha(darken(ltOnSurface, 0.8), "ff"),
		"editor.invisible":                           hexWithAlpha(lighten(ltOnSurfaceVariant, 1.3), "ff"),
		"editor.wrap_guide":                          hexWithAlpha(ltOnSurfaceVariant, "0d"),
		"editor.active_wrap_guide":                   hexWithAlpha(ltOnSurfaceVariant, "1a"),
		"editor.document_highlight.read_background":  hexWithAlpha(primary, "20"),
		"editor.document_highlight.write_background": hexWithAlpha(ltOnSurfaceVariant, "66"),
		"terminal.background":                        hexWithAlpha(ltSurface, "ff"),
		"terminal.foreground":                        hexWithAlpha(ltOnSurface, "ff"),
		"terminal.bright_foreground":                 hexWithAlpha(ltOnSurface, "ff"),
		"terminal.dim_foreground":                    hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"link_text.hover":                            hexWithAlpha(primary, "ff"),
		"version_control.added":                      hexWithAlpha(sat(tertiary, 1.3), "ff"),
		"version_control.modified":                   hexWithAlpha(sat(primary, 1.3), "ff"),
		"version_control.word_added":                 hexWithAlpha(tertiary, "40"),
		"version_control.word_deleted":               hexWithAlpha(errorCol, "40"),
		"version_control.deleted":                    hexWithAlpha(sat(errorCol, 1.3), "ff"),
		"version_control.conflict_marker.ours":       hexWithAlpha(tertiary, "25"),
		"version_control.conflict_marker.theirs":     hexWithAlpha(primary, "25"),
		"conflict":                                   hexWithAlpha(sat(tertiary, 1.3), "ff"),
		"conflict.background":                        hexWithAlpha(tertiary, "18"),
		"conflict.border":                            hexWithAlpha(sat(tertiary, 1.5), "ff"),
		"created":                                    hexWithAlpha(sat(tertiary, 1.3), "ff"),
		"created.background":                         hexWithAlpha(tertiary, "18"),
		"created.border":                             hexWithAlpha(sat(tertiary, 1.5), "ff"),
		"deleted":                                    hexWithAlpha(sat(errorCol, 1.3), "ff"),
		"deleted.background":                         hexWithAlpha(errorCol, "18"),
		"deleted.border":                             hexWithAlpha(sat(errorCol, 1.5), "ff"),
		"error":                                      hexWithAlpha(sat(errorCol, 1.3), "ff"),
		"error.background":                           hexWithAlpha(errorCol, "18"),
		"error.border":                               hexWithAlpha(sat(errorCol, 1.5), "ff"),
		"hidden":                                     hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"hidden.background":                          hexWithAlpha(ltOnSurfaceVariant, "18"),
		"hidden.border":                              hexWithAlpha(ltOutlineVariant, "ff"),
		"hint":                                       hexWithAlpha(sat(primary, 1.3), "ff"),
		"hint.background":                            hexWithAlpha(primary, "18"),
		"hint.border":                                hexWithAlpha(sat(primary, 1.5), "ff"),
		"ignored":                                    hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"ignored.background":                         hexWithAlpha(ltOnSurfaceVariant, "18"),
		"ignored.border":                             hexWithAlpha(ltOutlineVariant, "ff"),
		"info":                                       hexWithAlpha(sat(primary, 1.3), "ff"),
		"info.background":                            hexWithAlpha(primary, "18"),
		"info.border":                                hexWithAlpha(sat(primary, 1.5), "ff"),
		"modified":                                   hexWithAlpha(sat(primary, 1.3), "ff"),
		"modified.background":                        hexWithAlpha(primary, "18"),
		"modified.border":                            hexWithAlpha(sat(primary, 1.5), "ff"),
		"predictive":                                 hexWithAlpha(sat(secondary, 1.3), "ff"),
		"predictive.background":                      hexWithAlpha(secondary, "18"),
		"predictive.border":                          hexWithAlpha(sat(secondary, 1.5), "ff"),
		"renamed":                                    hexWithAlpha(sat(primary, 1.3), "ff"),
		"renamed.background":                         hexWithAlpha(primary, "18"),
		"renamed.border":                             hexWithAlpha(sat(primary, 1.5), "ff"),
		"success":                                    hexWithAlpha(sat(tertiary, 1.3), "ff"),
		"success.background":                         hexWithAlpha(tertiary, "18"),
		"success.border":                             hexWithAlpha(sat(tertiary, 1.5), "ff"),
		"unreachable":                                hexWithAlpha(ltOnSurfaceVariant, "ff"),
		"unreachable.background":                     hexWithAlpha(ltOnSurfaceVariant, "18"),
		"unreachable.border":                         hexWithAlpha(ltOutlineVariant, "ff"),
		"warning":                                    hexWithAlpha(sat(tertiary, 1.3), "ff"),
		"warning.background":                         hexWithAlpha(tertiary, "18"),
		"warning.border":                             hexWithAlpha(sat(tertiary, 1.5), "ff"),
	}

	lightStyle["terminal.ansi.black"] = hexWithAlpha(termColor(termColors, 0), "ff")
	lightStyle["terminal.ansi.white"] = hexWithAlpha(darken(termColor(termColors, 7), 0.5), "ff")
	lightStyle["terminal.ansi.bright_black"] = hexWithAlpha(darken(termColor(termColors, 8), 0.6), "ff")
	lightStyle["terminal.ansi.bright_white"] = hexWithAlpha(darken(termColor(termColors, 15), 0.3), "ff")
	for name, idx := range map[string]int{
		"red": 1, "bright_red": 9, "dim_red": 1,
		"green": 2, "bright_green": 10, "dim_green": 2,
		"yellow": 3, "bright_yellow": 11, "dim_yellow": 3,
		"blue": 4, "bright_blue": 12, "dim_blue": 4,
		"magenta": 5, "bright_magenta": 13, "dim_magenta": 5,
		"cyan": 6, "bright_cyan": 14, "dim_cyan": 6,
	} {
		base := termColor(termColors, idx)
		c := darken(base, 0.85)
		if strings.Contains(name, "bright") {
			c = darken(base, 0.75)
		} else if strings.Contains(name, "dim") {
			c = darken(base, 0.5)
		}
		lightStyle["terminal.ansi."+name] = hexWithAlpha(c, "ff")
	}
	playerColorsLight := []string{sat(primary, 1.3), sat(errorCol, 1.3), sat(tertiary, 1.3), sat(secondary, 1.3)}
	playersLight := []any{}
	for _, c := range playerColorsLight {
		playersLight = append(playersLight, map[string]any{
			"cursor":     hexWithAlpha(c, "ff"),
			"background": hexWithAlpha(c, "ff"),
			"selection":  hexWithAlpha(lighten(c, 1.2), "3d"),
		})
	}
	lightStyle["players"] = playersLight
	lightStyle["syntax"] = buildSyntaxMap(primary, "light")

	modeDark := map[string]string{
		"surface":                   dkSurface,
		"surface_container_low":     dkSurfaceLow,
		"surface_container":         dkSurfaceStd,
		"surface_container_high":    dkSurfaceHigh,
		"surface_container_highest": dkSurfaceHighest,
		"on_surface":                dkOnSurface,
		"on_surface_variant":        dkOnSurfaceVariant,
		"outline":                   dkOutline,
		"outline_variant":           dkOutlineVariant,
		"surface_dim":               pick(myColors, "surface_dim", adjustLightness(dkSurface, 0.92)),
		"surface_variant":           pick(myColors, "surface_variant", dkSurfaceStd),
	}
	modeLight := map[string]string{
		"surface":                   ltSurface,
		"surface_container_low":     ltSurfaceLow,
		"surface_container":         ltSurfaceStd,
		"surface_container_high":    ltSurfaceHigh,
		"surface_container_highest": ltSurfaceHighest,
		"on_surface":                ltOnSurface,
		"on_surface_variant":        ltOnSurfaceVariant,
		"outline":                   ltOutline,
		"outline_variant":           ltOutlineVariant,
		"surface_dim":               pick(myColors, "surface_dim", adjustLightness(ltSurface, 0.95)),
		"surface_variant":           pick(myColors, "surface_variant", ltSurfaceStd),
	}
	for k, v := range myColors {
		if _, ok := modeDark[k]; !ok {
			modeDark[k] = v
		}
		if _, ok := modeLight[k]; !ok {
			modeLight[k] = v
		}
	}

	return darkStyle, lightStyle, modeDark, modeLight
}

func pick(m map[string]string, key, fallback string) string {
	if v, ok := m[key]; ok && v != "" {
		return normalizeHex6(v)
	}
	return normalizeHex6(fallback)
}

func resolveMaterialColor(token, mode string, modePalettes map[string]map[string]string) string {
	palette := modePalettes[mode]
	if palette == nil {
		palette = modePalettes["dark"]
	}
	if raw, ok := palette[token]; ok && isHexColor(raw) {
		return normalizeHex6(raw)
	}
	fallbackMap := map[string]string{
		"primary":               "#7aa2f7",
		"secondary":             "#bb9af7",
		"tertiary":              "#9ece6a",
		"error":                 "#f7768e",
		"surface":               tern(mode == "dark", "#1a1b26", "#faf4f2"),
		"surface_container":     tern(mode == "dark", "#24283b", "#f0e8e6"),
		"surface_container_low": tern(mode == "dark", "#1f2230", "#f7efed"),
		"surface_container_high": tern(mode == "dark",
			"#2d3246", "#ece2df"),
		"surface_container_highest": tern(mode == "dark", "#3a415b", "#e5d9d6"),
		"surface_dim":               tern(mode == "dark", "#14161d", "#ece2df"),
		"on_surface":                tern(mode == "dark", "#c0caf5", "#2a2022"),
		"on_surface_variant":        tern(mode == "dark", "#9aa5ce", "#5a4b4e"),
		"outline":                   tern(mode == "dark", "#565f89", "#7e6e72"),
		"outline_variant":           tern(mode == "dark", "#434a68", "#ccb8bc"),
		"primary_container":         tern(mode == "dark", "#39426a", "#dbe2ff"),
		"on_primary_container":      tern(mode == "dark", "#d7e2ff", "#1f2a4d"),
		"secondary_container":       tern(mode == "dark", "#4a4064", "#e8defc"),
		"on_secondary_container":    tern(mode == "dark", "#e8defd", "#352d4b"),
		"tertiary_container":        tern(mode == "dark", "#334f2e", "#d9f4bf"),
		"on_tertiary_container":     tern(mode == "dark", "#d2f0b8", "#243a1e"),
		"error_container":           tern(mode == "dark", "#5d1f2d", "#f9d8df"),
		"on_error_container":        tern(mode == "dark", "#ffd9df", "#5b1b2a"),
	}
	if v, ok := fallbackMap[token]; ok {
		return v
	}
	if strings.HasPrefix(token, "on_") {
		return resolveMaterialColor("on_surface", mode, modePalettes)
	}
	if strings.HasSuffix(token, "_container") {
		return resolveMaterialColor("surface_container", mode, modePalettes)
	}
	if strings.HasPrefix(token, "surface") {
		return resolveMaterialColor("surface", mode, modePalettes)
	}
	return resolveMaterialColor("primary", mode, modePalettes)
}

func tern(cond bool, t, f string) string {
	if cond {
		return t
	}
	return f
}

func renderTemplate(node any, modePalettes map[string]map[string]string) any {
	switch v := node.(type) {
	case map[string]any:
		out := map[string]any{}
		for k, item := range v {
			out[k] = renderTemplate(item, modePalettes)
		}
		return out
	case []any:
		out := make([]any, 0, len(v))
		for _, item := range v {
			out = append(out, renderTemplate(item, modePalettes))
		}
		return out
	case string:
		return placeholderRe.ReplaceAllStringFunc(v, func(match string) string {
			g := placeholderRe.FindStringSubmatch(match)
			if len(g) != 3 {
				return match
			}
			return resolveMaterialColor(g[1], g[2], modePalettes)
		})
	default:
		return v
	}
}

func loadAltStyles(templatePath string, modePalettes map[string]map[string]string) map[string]map[string]any {
	styles := map[string]map[string]any{}
	if templatePath == "" {
		return styles
	}
	data, err := os.ReadFile(templatePath)
	if err != nil {
		return styles
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return styles
	}
	themes, ok := raw["themes"].([]any)
	if !ok {
		return styles
	}
	for _, item := range themes {
		obj, ok := item.(map[string]any)
		if !ok {
			continue
		}
		appearance, _ := obj["appearance"].(string)
		if appearance != "dark" && appearance != "light" {
			continue
		}
		style, ok := obj["style"].(map[string]any)
		if !ok {
			continue
		}
		rendered, ok := renderTemplate(style, modePalettes).(map[string]any)
		if !ok {
			continue
		}
		styles[appearance] = rendered
	}
	return styles
}

func mergeMaps(base map[string]string, overlays ...map[string]string) map[string]string {
	out := map[string]string{}
	for k, v := range base {
		out[k] = v
	}
	for _, overlay := range overlays {
		for k, v := range overlay {
			out[k] = v
		}
	}
	return out
}

func main() {
	home, _ := os.UserHomeDir()
	defaultSCSS := filepath.Join(home, ".local/state/quickshell/user/generated/material_colors.scss")
	defaultPalette := filepath.Join(home, ".local/state/quickshell/user/generated/palette.json")
	defaultTerminal := filepath.Join(home, ".local/state/quickshell/user/generated/terminal.json")
	defaultOutput := filepath.Join(home, ".config/zed/themes/ii-theme.json")
	defaultTemplate := filepath.Join(".", "dots/.config/matugen/templates/zed-colors.json")
	if _, err := os.Stat(defaultTemplate); err != nil {
		defaultTemplate = ""
	}

	scssPath := flag.String("scss", defaultSCSS, "")
	colorsPath := flag.String("colors", defaultPalette, "")
	terminalJSONPath := flag.String("terminal-json", defaultTerminal, "")
	outputPath := flag.String("output", defaultOutput, "")
	templatePath := flag.String("template", defaultTemplate, "")
	flag.Parse()

	// Backward-compatible positional args: <scss> <colors> <terminal-json>
	if flag.NArg() >= 1 {
		*scssPath = flag.Arg(0)
	}
	if flag.NArg() >= 2 {
		*colorsPath = flag.Arg(1)
	}
	if flag.NArg() >= 3 {
		*terminalJSONPath = flag.Arg(2)
	}

	myColorsRaw := readStringJSON(*colorsPath)
	myColors := sanitizeHexMap(myColorsRaw)
	if len(myColors) == 0 {
		myColors = map[string]string{
			"primary":                "#7aa2f7",
			"secondary":              "#bb9af7",
			"tertiary":               "#9ece6a",
			"error":                  "#f7768e",
			"surface":                "#1a1b26",
			"surface_container_low":  "#24283b",
			"surface_container":      "#414868",
			"surface_container_high": "#565f89",
			"outline":                "#565f89",
			"on_surface":             "#c0caf5",
			"on_surface_variant":     "#9aa5ce",
			"on_primary":             "#1a1b26",
		}
	}

	scssColors, _ := parseSCSS(*scssPath)
	termFromSCSS := parseTermMap(scssColors)
	termFromPalette := parseTermMap(myColorsRaw)
	termFromJSON := parseTermMap(readStringJSON(*terminalJSONPath))
	termColors := mergeMaps(termFromPalette, termFromSCSS, termFromJSON)

	darkStyle, lightStyle, modeDark, modeLight := buildStyles(myColors, termColors)
	modePalettes := map[string]map[string]string{
		"dark":  modeDark,
		"light": modeLight,
	}

	altStyles := loadAltStyles(*templatePath, modePalettes)
	altDark := darkStyle
	if s, ok := altStyles["dark"]; ok {
		altDark = s
	}
	altLight := lightStyle
	if s, ok := altStyles["light"]; ok {
		altLight = s
	}
	altDark = deepCopyMap(altDark)
	altLight = deepCopyMap(altLight)

	// Keep default iNiR border tones aligned with the iNiR-alt border palette.
	applyBorderPalette(darkStyle, altDark)
	applyBorderPalette(lightStyle, altLight)

	altDark["syntax"] = buildSyntaxMap(resolveMaterialColor("primary", "dark", modePalettes), "dark")
	altLight["syntax"] = buildSyntaxMap(resolveMaterialColor("primary", "light", modePalettes), "light")

	themeData := map[string]any{
		"$schema": "https://zed.dev/schema/themes/v0.2.0.json",
		"name":    "iNiR Material",
		"author":  "iNiR Theme System",
		"themes": []any{
			map[string]any{"name": "iNiR Dark", "appearance": "dark", "style": darkStyle},
			map[string]any{"name": "iNiR Light", "appearance": "light", "style": lightStyle},
			map[string]any{"name": "iNiR Borderless Dark", "appearance": "dark", "style": makeBorderlessStyle(darkStyle)},
			map[string]any{"name": "iNiR Borderless Light", "appearance": "light", "style": makeBorderlessStyle(lightStyle)},
			map[string]any{"name": "iNiR-alt Dark", "appearance": "dark", "style": altDark},
			map[string]any{"name": "iNiR-alt Light", "appearance": "light", "style": altLight},
		},
	}

	if err := os.MkdirAll(filepath.Dir(*outputPath), 0o755); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	data, err := json.MarshalIndent(themeData, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err := os.WriteFile(*outputPath, append(data, '\n'), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println("✓ Generated Zed theme")
}
