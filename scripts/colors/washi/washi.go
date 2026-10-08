package main

import (
	"math"
	"strings"
)

// Request is everything iRiS chose that colours it, resolved by the shell (a colour theme it follows already
// names "theme" here) plus the seeds it read from the wallpaper and the colour theme.
type Request struct {
	Language string `json:"language,omitempty"` // the aesthetic; empty is washi
	Variant  string `json:"variant,omitempty"`  // Material's scheme: tonalSpot, vibrant, expressive, fidelity, monochrome
	Material string `json:"material"`
	Glass    bool   `json:"glass,omitempty"` // the shell wears glass: apps take the colour its frost shows
	// InkStyle "style" lets Ink follow Language; anything else (the default) dresses Ink in washi, which is what Ink is.
	InkStyle string `json:"inkStyle,omitempty"`
	// DarkStyle "ink" dresses Dark in washi too: a sumi night instead of the style's own (Settings' night papers).
	DarkStyle    string          `json:"darkStyle,omitempty"`
	Accent       string          `json:"accent"`
	AccentHue    float64         `json:"accentHue"`
	Highlight    string          `json:"highlight"`
	HighlightHue float64         `json:"highlightHue"`
	Vibrance     float64         `json:"vibrance"`
	Tune         map[string]Tune `json:"tune"`
	Seeds        Seeds           `json:"seeds"`
}

type Tune struct {
	Tone    float64  `json:"tone"`
	Colour  *float64 `json:"colour"`
	Widgets *float64 `json:"widgets"`
	Warmth  *float64 `json:"warmth"` // paper schemes: how much washi fibre the paper carries, 0–100
}

// paperLevel is a named paper for a paper scheme: its tone and warmth together.
type paperLevel struct {
	name         string
	tone, warmth float64
}

// paperLevels are the papers Settings offers per paper scheme, lightest first. Light's go from a clean page to a calm
// evening one; Ink's are washi grades from bleached shironeri to sumi-dyed (darker and greyer, not yellower). Settings' level tiles carry the same
// numbers (TestShellKnowsPaperLevels).
var paperLevels = map[string][]paperLevel{
	"light": {{"bright", 6, 0}, {"soft", -8, 38}, {"calm", -18, 55}},
	"ink":   {{"shironeri", 14, 30}, {"kinari", 0, 50}, {"torinoko", -10, 68}, {"sumi", -24, 52}},
	// Dark's are ink at night (DarkStyle "ink"): kuro washi, sumi, then usuzumi, ink thinned to a soft charcoal.
	"dark": {{"kuro", 40, 42}, {"sumi", 50, 62}, {"usuzumi", 68, 50}},
}

// ownWarmth is where each paper scheme's own paper sits on the warmth scale: there a language's paper is left as it
// is, below it the paper loses its hue toward a neutral page, above it it takes washi fibre.
var ownWarmth = map[string]float64{"light": 20, "ink": 50, "dark": 20}

// fibreC is the most chroma the warmest paper reaches, in the fibre's hue (sumiHue).
var fibreC = map[string]float64{"light": 0.045, "ink": 0.05, "dark": 0.024}

// warm moves a paper along the warmth scale. Hue and chroma are mixed as a vector (OKLab a, b), so a tinted paper
// (wallpaper, midnight) warms smoothly instead of jumping hue.
func warm(s spec, p LCH, warmth float64) LCH {
	own, ok := ownWarmth[s.name]
	if !ok {
		return p
	}
	w := clampF(warmth, 0, 100)
	a, b := p.C*math.Cos(p.H*math.Pi/180), p.C*math.Sin(p.H*math.Pi/180)
	if w < own {
		k := 1 - (own-w)/own
		a, b = a*k, b*k
	} else {
		k := (w - own) / (100 - own)
		fa, fb := fibreC[s.name]*math.Cos(sumiHue*math.Pi/180), fibreC[s.name]*math.Sin(sumiHue*math.Pi/180)
		a, b = a+(fa-a)*k, b+(fb-b)*k
	}
	c := math.Hypot(a, b)
	h := p.H
	if c > 1e-6 {
		h = math.Mod(math.Atan2(b, a)*180/math.Pi+360, 360)
	}
	return LCH{p.L, c, h}
}

// warmthOf is a scheme's warmth: the person's, else its own (the language's paper unchanged).
func warmthOf(name string, t Tune) float64 {
	if t.Warmth != nil {
		return *t.Warmth
	}
	return ownWarmth[name]
}

type Seeds struct {
	Wallpaper  string `json:"wallpaper"`
	Primary    string `json:"primary"`
	Secondary  string `json:"secondary"`
	Tertiary   string `json:"tertiary"`
	Background string `json:"background"`
}

// spec is one scheme: its papers and the band every colour on them is solved in.
type spec struct {
	name      string
	dark      bool
	materials map[string]LCH // the three named papers
	paperL    float64        // a paper taken from a seed (wallpaper, theme)
	paperC    float64        // the most chroma such a paper keeps: a ground, never a colour
	steps     [2]float64     // lightness of a group and of the deepest group, from the paper
	inkL      float64
	accentL   float64 // the accent is the brightest (paper) or darkest (night) tone past this that reads
	accentC   [2]float64
	markL     float64 // the band of marks: highlight, identity, data
	markC     float64
	widgets   float64 // default Widget colour
}

// washi is the shell's own language: paper and sumi, pigments instead of light.
var washi = Language{
	name: "washi", schemes: schemes, materialNames: []string{"black", "graphite", "midnight", "wallpaper", "theme"},
	accentSeeds: accentSeeds, highlightSeeds: highlightSeeds, identity: identitySeeds, identityPull: 12,
	neutralHue: sumiHue, onColour: white, darkOn: [2]float64{0.2, 0.03}, fillFrom: [2]float64{0.66, 0.52}, fillC: [2]float64{0.09, 0.15},
	paper: paper, ramp: rampOf, container: washiContainer, inkChroma: washiInk,
}

var schemes = []spec{
	{
		// Dark: sumi night. Black stays black for the screen edge; its groups, ink and colours are the same washi
		// language turned over: warm fibre greys, gofun ink, pigments instead of light.
		name: "dark", dark: true,
		materials: map[string]LCH{"black": {0, 0, 0}, "graphite": {0.215, 0.011, 72}, "midnight": {0.19, 0.028, 258}},
		paperL:    0.18, paperC: 0.03, steps: [2]float64{0.055, 0.11}, inkL: 0.94,
		accentL: 0.66, accentC: [2]float64{0.04, 0.085}, markL: 0.7, markC: 0.1, widgets: 1,
	},
	{
		// Ink: torinoko washi and sumi. Warm fibre, never grey; colours are pigments, quieter than Light's.
		name:      "ink",
		materials: map[string]LCH{"black": {0.905, 0.018, 88}, "graphite": {0.865, 0.03, 72}, "midnight": {0.89, 0.014, 232}},
		paperL:    0.9, paperC: 0.035, steps: [2]float64{-0.035, -0.07}, inkL: 0.25,
		accentL: 0.56, accentC: [2]float64{0.05, 0.1}, markL: 0.62, markC: 0.12, widgets: 1,
	},
	{
		// Light: shironeri, washi bleached to almost white. Still paper, not a screen's blank white.
		name:      "light",
		materials: map[string]LCH{"black": {0.975, 0.011, 88}, "graphite": {0.935, 0.007, 85}, "midnight": {0.95, 0.014, 240}},
		paperL:    0.965, paperC: 0.025, steps: [2]float64{-0.03, -0.06}, inkL: 0.21,
		accentL: 0.6, accentC: [2]float64{0.06, 0.115}, markL: 0.65, markC: 0.13, widgets: 1.1,
	},
}

// Seeds of the named choices, as the colours people know them by.
var accentSeeds = map[string]string{"blue": "#0a60d1", "mint": "#0f8f66", "rose": "#c2274f", "lilac": "#6b47c9"}
var highlightSeeds = map[string]string{"orange": "#ff9f0a", "yellow": "#ffd60a", "red": "#ff453a", "pink": "#ff375f", "green": "#30d158"}
var identitySeeds = []identitySeed{
	{"blue", 255, 0, 0}, {"sky", 232, 0.05, -0.02}, {"teal", 200, 0, -0.02}, {"green", 148, 0, 0},
	{"yellow", 84, 0.04, 0.01}, {"orange", 58, 0, 0}, {"red", 27, 0, 0.02}, {"pink", 2, 0, 0},
	{"indigo", 278, -0.03, 0}, {"purple", 308, 0, 0}, {"lavender", 295, 0.06, -0.05}, {"gray", -1, 0, 0},
}

type Ramp struct {
	Surface, High, Highest LCH
}

func (r Ramp) all() []RGB { return []RGB{r.Surface.RGB(), r.High.RGB(), r.Highest.RGB()} }

func clampF(v, lo, hi float64) float64 { return math.Max(lo, math.Min(hi, v)) }

// sumiHue is the warmth of ink and greys where the paper has no hue of its own (Black).
const sumiHue = 80.0

func seedLCH(hex string) (LCH, bool) {
	c, ok := parseHex(hex)
	if !ok {
		return LCH{}, false
	}
	return c.LCH(), true
}

// paper resolves a material name to its paper in a scheme.
func paper(s spec, name string, seeds Seeds, tone float64) LCH {
	p, ok := s.materials[name]
	fromSeed := func(hex string) (LCH, bool) {
		c, ok := seedLCH(hex)
		if !ok || c.C < 0.02 {
			return LCH{}, false
		}
		return LCH{s.paperL, math.Min(s.paperC, c.C*0.3), c.H}, true
	}
	switch name {
	case "wallpaper":
		if p, ok = fromSeed(seeds.Wallpaper); !ok {
			p, ok = fromSeed(seeds.Primary)
		}
	case "theme":
		// A theme's own background when it is of this scheme's polarity, kept a paper (or a night).
		if bg, good := seedLCH(seeds.Background); good && (s.dark && bg.L < 0.36 || !s.dark && bg.L > 0.8) {
			if s.dark {
				p = LCH{bg.L, math.Min(bg.C, 0.05), bg.H}
			} else if s.name == "ink" {
				p = LCH{clampF(bg.L, 0.86, 0.92), math.Min(bg.C, 0.04), bg.H}
			} else {
				p = LCH{math.Max(bg.L, 0.93), math.Min(bg.C, 0.03), bg.H}
			}
			ok = true
		} else {
			p, ok = fromSeed(seeds.Primary)
		}
	}
	if !ok {
		p = s.materials["graphite"]
	}
	// Tone lifts or dims the paper, never past where it stops being one (or a night stops being one).
	if s.dark {
		p.L = clampF(p.L+tone/100*0.4, 0, 0.3)
	} else {
		p.L = clampF(p.L+tone/100*0.3, map[string]float64{"ink": 0.83, "light": 0.89}[s.name], 1)
	}
	return p
}

func rampOf(s spec, p LCH) Ramp {
	step := func(i int) LCH {
		if s.dark && p.L < 0.05 {
			// Black has no hue to keep: its groups are sumi greys, warm like the paper of the other schemes.
			return LCH{[2]float64{0.235, 0.305}[i], 0.006, sumiHue}
		}
		return LCH{clampF(p.L+s.steps[i], 0, 1), p.C * 1.1, p.H}
	}
	return Ramp{p, step(0), step(1)}
}

func washiInk(s spec, pc LCH) float64 {
	if s.dark {
		// Gofun, not a screen's grey: the night's ink keeps the fibre's warmth.
		return math.Min(0.012, pc.C*0.3+0.008)
	}
	return math.Min(0.014, pc.C*0.8+0.004)
}

func washiContainer(s spec, pc, al LCH) LCH {
	if s.dark {
		return LCH{math.Max(0.32, pc.L+0.16), math.Min(0.05, al.C*0.45), al.H}
	}
	// A wash of the pigment on the paper, not a tinted screen.
	return LCH{pc.L - 0.075, math.Min(0.042, al.C*0.4), al.H}
}

// solve moves a colour's lightness from where it is preferred, away from the paper, until every check holds;
// chroma is the most the gamut gives there, up to the asked chroma. The paper side keeps the brightest tone
// that reads (the most colour), the night side the darkest.
func solve(s spec, h, c, from float64, ok func(RGB) bool) RGB {
	dir := -1.0
	if s.dark {
		dir = 1
	}
	at := func(L float64) RGB { return LCH{L, math.Min(c, maxChroma(L, h)), h}.RGB() }
	// Coarse steps to the first tone that reads, then back in fine steps to the first one past it.
	L := clampF(from, 0, 1)
	for ; L > 0 && L < 1 && !ok(at(L)); L += dir * 0.02 {
	}
	L = clampF(L, 0, 1)
	if !ok(at(L)) {
		return at(L)
	}
	for i := 0; i < 10; i++ {
		back := L - dir*0.002
		if (dir < 0 && back > from) || (dir > 0 && back < from) || !ok(at(back)) {
			break
		}
		L = back
	}
	return at(L)
}

func readsOn(min float64, grounds ...RGB) func(RGB) bool {
	return func(c RGB) bool {
		for _, g := range grounds {
			if contrast(c, g) < min {
				return false
			}
		}
		return true
	}
}

func over(top, under RGB, alpha float64) RGB {
	return RGB{top.R*alpha + under.R*(1-alpha), top.G*alpha + under.G*(1-alpha), top.B*alpha + under.B*(1-alpha)}
}

func both(a, b func(RGB) bool) func(RGB) bool { return func(c RGB) bool { return a(c) && b(c) } }

// white is the ink on colour: gofun, the paper's own white, never a screen's #ffffff.
var white = LCH{0.975, 0.011, 88}.RGB()

// Palette is one scheme's complete set of roles.
type Palette struct {
	Dark              bool                `json:"dark"`
	Material          string              `json:"material"`
	Surface           string              `json:"surface"`
	SurfaceHigh       string              `json:"surfaceHigh"`
	SurfaceHighest    string              `json:"surfaceHighest"`
	Text              string              `json:"text"`
	TextSecondary     string              `json:"textSecondary"`
	TextTertiary      string              `json:"textTertiary"`
	FillInk           string              `json:"fillInk"`
	Accent            string              `json:"accent"`
	OnAccent          string              `json:"onAccent"`
	AccentContainer   string              `json:"accentContainer"`
	OnAccentContainer string              `json:"onAccentContainer"`
	Highlight         string              `json:"highlight"`
	OnHighlight       string              `json:"onHighlight"`
	Success           string              `json:"success"`
	Warning           string              `json:"warning"`
	Danger            string              `json:"danger"`
	OnDanger          string              `json:"onDanger"`
	AccentFill        string              `json:"accentFill"`
	OnAccentFill      string              `json:"onAccentFill"`
	DangerFill        string              `json:"dangerFill"`
	OnDangerFill      string              `json:"onDangerFill"`
	HighlightFill     string              `json:"highlightFill"`
	OnHighlightFill   string              `json:"onHighlightFill"`
	Identity          map[string]string   `json:"identity"`
	Widgets           map[string][]string `json:"widgets"`
	Materials         map[string]string   `json:"materials"`
	Accents           map[string]string   `json:"accents"`
	Highlights        map[string]string   `json:"highlights"`
	Apps              map[string]string   `json:"apps"`
	Papers            map[string]string   `json:"papers,omitempty"` // paper schemes: each level's paper
}

type solver struct {
	lang    *Language
	s       spec
	req     Request
	ramp    Ramp
	grounds []RGB
	colour  float64
	widgets float64
}

// far is the hardest ground: the darkest on paper, the brightest at night.
func (v solver) far() RGB {
	best := v.grounds[0]
	for _, g := range v.grounds[1:] {
		if v.s.dark == (luminance(g) > luminance(best)) {
			best = g
		}
	}
	return best
}

// glassGrounds are what a paper body can become as glass: Lume lets the frost sit 0.1 (in gamma levels) under the
// paper over a dark region (IrisStyle.paperFloor), and a group sits on that. Colours are solved on those too.
func glassGrounds(paper RGB, ink RGB) []RGB {
	f := func(c float64) float64 { return math.Max(0, c-0.1) }
	frost := clamp(RGB{f(paper.R), f(paper.G), f(paper.B)})
	return []RGB{frost, clamp(over(ink, frost, 0.1))}
}

// accent solves a seed as the accent, which the shell both writes and fills with (toggles, buttons): a pigment that
// reads as text on the papers (4.5:1) and carries gofun ink, 3:1 over the glass frost (a backdrop, not a page) and
// 3.5:1 on its own wash. Holding 4.5 over the frost and the wash too sank it to near black (#4c0d08 on Ink).
func (v solver) accent(seed LCH) RGB {
	c := clampF(seed.C, v.s.accentC[0], v.s.accentC[1]) * v.colour
	papers := v.ramp.all()
	check := both(readsOn(readText, papers...), readsOn(readOverGlass, v.grounds...))
	if !v.s.dark {
		check = both(check, readsOn(readOn, v.lang.onColour))
	}
	far := papers[0]
	for _, g := range papers[1:] {
		if v.s.dark == (luminance(g) > luminance(far)) {
			far = g
		}
	}
	check = both(check, func(c RGB) bool { return contrast(c, over(c, far, 0.15)) >= readWash })
	return solve(v.s, seed.H, c, v.s.accentL, check)
}

// fill solves a seed as a filled shape (a badge, a button, an app's primary): a pigment that reads as text on the
// opaque papers and carries its own ink, without the glass and wash checks that sink the accent toward black.
// need is readText when the colour is also text (an app's primary), readShape for a shape (a badge).
func (v solver) fill(seed LCH, need float64) RGB {
	c := clampF(seed.C, v.lang.fillC[0], v.lang.fillC[1]) * math.Max(0.6, v.colour)
	if !v.s.dark {
		// A filled shape on paper is the loudest thing on it: a pigment, never a screen's saturated blue.
		c = math.Min(c, paperFillC)
	}
	from := v.lang.fillFrom[1]
	if v.s.dark {
		from = v.lang.fillFrom[0]
	}
	check := readsOn(need, v.ramp.all()...)
	if !v.s.dark {
		check = both(check, readsOn(readOn, v.lang.onColour))
	}
	return solve(v.s, seed.H, c, from, check)
}

// mark solves a seed as a figure or glyph: readMark on every ground.
func (v solver) mark(h, c, dl float64) RGB {
	return solve(v.s, h, c, v.s.markL+dl, readsOn(readMark, v.grounds...))
}

func (v solver) highlight(seed LCH) RGB {
	return v.mark(seed.H, clampF(seed.C, v.s.markC*0.7, v.s.markC*1.15)*v.colour, 0)
}

// onContainer is the ink on a tonal container, in its hue, on whichever side of it reads: a dark container takes a
// light ink that also reads on the papers (it labels them too), a light one a dark ink.
func (v solver) onContainer(cont RGB, h, c float64) RGB {
	side := spec{dark: cont.LCH().L < 0.6}
	check := readsOn(readOn, cont)
	if side.dark == v.s.dark {
		check = readsOn(readOn, cont, v.far())
	}
	return solve(side, h, c, map[bool]float64{true: 0.9, false: 0.32}[side.dark], check)
}

// onFill is the ink on a filled colour: the language's light ink or the dark of its hue, whichever reads.
func (v solver) onFill(fill RGB, need float64) RGB {
	fl := fill.LCH()
	light := v.lang.onColour
	dark := LCH{v.lang.darkOn[0], v.lang.darkOn[1], fl.H}.RGB()
	if v.lang.tonalOn {
		dark = solve(spec{}, fl.H, math.Min(v.lang.darkOn[1], fl.C), v.lang.darkOn[0], readsOn(need, fill))
	}
	if !v.s.dark && contrast(light, fill) >= need {
		return light
	}
	if contrast(dark, fill) >= contrast(light, fill) {
		return dark
	}
	return light
}

func (v solver) seedOf(choice string, hue float64, table map[string]string, fallback string) LCH {
	pick := func(hexes ...string) (LCH, bool) {
		for _, h := range hexes {
			if c, ok := seedLCH(h); ok && c.C >= 0.03 {
				return c, true
			}
		}
		return LCH{}, false
	}
	switch choice {
	case "custom":
		return hsl(hue, 0.7, 0.5).LCH()
	case "wallpaper":
		if c, ok := pick(v.req.Seeds.Wallpaper, v.req.Seeds.Primary); ok {
			return c
		}
	case "theme":
		if c, ok := pick(v.req.Seeds.Primary); ok {
			return c
		}
	case "wallpaperHighlight":
		if c, ok := pick(v.req.Seeds.Secondary, v.req.Seeds.Wallpaper, v.req.Seeds.Primary); ok {
			return LCH{c.L, math.Max(c.C, 0.12), c.H}
		}
	case "themeHighlight":
		if c, ok := pick(v.req.Seeds.Tertiary); ok {
			return LCH{c.L, math.Max(c.C, 0.12), c.H}
		}
	}
	if hex, ok := table[choice]; ok {
		c, _ := seedLCH(hex)
		return c
	}
	c, _ := seedLCH(table[fallback])
	return c
}

func hexes(cs ...RGB) []string {
	out := make([]string, len(cs))
	for i, c := range cs {
		out[i] = c.Hex()
	}
	return out
}

// schemeLanguage is the language one scheme is solved in: Ink is washi's paper unless the person lets it follow the
// style, so choosing Ink never needs a second choice to look like Ink.
func schemeLanguage(req Request, name string) *Language {
	if name == "ink" && req.InkStyle != "style" || name == "dark" && req.DarkStyle == "ink" {
		return &washi
	}
	return languageOf(req)
}

// paperOf is a material's paper in a scheme with the person's tone and warmth.
func paperOf(lang *Language, s spec, material string, req Request) LCH {
	t := req.Tune[s.name]
	return warm(s, lang.paper(s, material, req.Seeds, t.Tone), warmthOf(s.name, t))
}

func build(req Request, name string) Palette {
	lang := schemeLanguage(req, name)
	s := lang.specOf(name)
	tune := req.Tune[name]
	colour := 1.0
	if tune.Colour != nil {
		colour = clampF(*tune.Colour/100, 0, 1)
	}
	widgets := s.widgets
	if tune.Widgets != nil {
		widgets = clampF(*tune.Widgets/100, 0.4, 1.6)
	}
	material := req.Material
	if _, named := s.materials[material]; !named && material != "wallpaper" && material != "theme" {
		material = "black"
	}
	ramp := lang.ramp(s, paperOf(lang, s, material, req))
	v := solver{lang: lang, s: s, req: req, ramp: ramp, grounds: ramp.all(), colour: colour, widgets: widgets}
	p := Palette{Dark: s.dark, Material: material}
	p.Surface, p.SurfaceHigh, p.SurfaceHighest = v.grounds[0].Hex(), v.grounds[1].Hex(), v.grounds[2].Hex()

	// Ink: sumi in the paper's own hue (or paper white at night), readInk on the deepest group.
	pc := ramp.Surface
	if pc.C < 0.004 {
		pc.H = lang.neutralHue
	}
	inkC := lang.inkChroma(s, pc)
	text := solve(s, pc.H, inkC, s.inkL, readsOn(readInk, v.grounds...))
	if !s.dark {
		// The group on the frost is made of the ink: solve both together until they agree.
		paperGrounds := v.grounds
		for i := 0; i < 4; i++ {
			v.grounds = append(append([]RGB{}, paperGrounds...), glassGrounds(paperGrounds[0], text)...)
			next := solve(s, pc.H, inkC, s.inkL, readsOn(readInk, v.grounds...))
			if next == text {
				break
			}
			text = next
		}
		v.grounds = append(append([]RGB{}, paperGrounds...), glassGrounds(paperGrounds[0], text)...)
	}
	p.Text = text.Hex()
	p.FillInk = p.Text
	quiet := func(need, from float64) RGB {
		return solve(s, pc.H, inkC*1.5, ramp.Surface.L+(text.LCH().L-ramp.Surface.L)*from, readsOn(need, v.grounds...))
	}
	p.TextSecondary = quiet(readSecondary, 0.62).Hex()
	p.TextTertiary = quiet(readTertiary, 0.45).Hex()

	accentChoice := req.Accent
	if accentChoice == "" {
		accentChoice = "blue"
	}
	accentSeed := v.seedOf(accentChoice, req.AccentHue, lang.accentSeeds, "blue")
	accent := v.accent(accentSeed)
	al := accent.LCH()
	p.Accent, p.OnAccent = accent.Hex(), v.onFill(accent, readOn).Hex()
	cont := lang.container(s, pc, al).RGB()
	p.AccentContainer = cont.Hex()
	p.OnAccentContainer = v.onContainer(cont, al.H, math.Min(0.12, al.C)).Hex()

	highlightChoice := req.Highlight
	var highlight RGB
	switch highlightChoice {
	case "accent":
		highlight = accent
	case "wallpaper":
		highlight = v.highlight(v.seedOf("wallpaperHighlight", 0, lang.highlightSeeds, "orange"))
	case "theme":
		highlight = v.highlight(v.seedOf("themeHighlight", 0, lang.highlightSeeds, "orange"))
	case "custom":
		highlight = v.highlight(hsl(req.HighlightHue, 0.92, 0.58).LCH())
	default:
		highlight = v.highlight(v.seedOf(highlightChoice, 0, lang.highlightSeeds, "orange"))
	}
	p.Highlight, p.OnHighlight = highlight.Hex(), v.onFill(highlight, readOn).Hex()

	status := func(h, c float64, need float64, carriesInk bool) RGB {
		check := readsOn(need, v.grounds...)
		if carriesInk && !s.dark {
			check = both(check, readsOn(readOn, lang.onColour))
		}
		return solve(s, h, c*math.Max(0.6, colour), s.markL, check)
	}
	p.Success = status(150, 0.13, readText, false).Hex()
	p.Warning = status(72, 0.14, readMark, false).Hex()
	danger := status(27, 0.17, readText, true)
	p.Danger, p.OnDanger = danger.Hex(), v.onFill(danger, readOn).Hex()

	// Filled shapes: the same hues as pigments (bengara, ai, shu), each with its ink.
	accentFill := v.fill(accentSeed, readText)
	dangerFill := v.fill(LCH{0.55, 0.15, 33}, readShape)
	highlightFill := v.fill(LCH{0.6, math.Max(0.1, highlight.LCH().C), highlight.LCH().H}, readShape)
	if highlightChoice == "accent" {
		highlightFill = accentFill
	}
	p.AccentFill, p.OnAccentFill = accentFill.Hex(), v.onFill(accentFill, readOn).Hex()
	p.DangerFill, p.OnDangerFill = dangerFill.Hex(), v.onFill(dangerFill, readOn).Hex()
	p.HighlightFill, p.OnHighlightFill = highlightFill.Hex(), v.onFill(highlightFill, readOn).Hex()

	// Identity: one band of lightness and chroma for every hue, each turned a little toward the accent, so twelve
	// meanings read as one family on this paper. Never the colour slider: their meaning does not fade.
	p.Identity = map[string]string{}
	idC := s.markC * map[string]float64{"dark": 0.86, "ink": 0.8, "light": 0.86}[name]
	// A language that keeps its own colours (iRiS's system colours) solves each from where it is, softer on paper.
	for _, id := range lang.identityHex {
		c, _ := seedLCH(id.hex)
		k := map[string]float64{"dark": 1, "ink": 0.75, "light": 0.9}[name]
		p.Identity[id.name] = v.mark(c.H, c.C*k, c.L-s.markL).Hex()
	}
	for _, id := range lang.identity {
		if _, done := p.Identity[id.name]; done {
			continue
		}
		if id.hue < 0 {
			p.Identity[id.name] = solve(s, pc.H, 0.012, s.markL, readsOn(readMark, v.grounds...)).Hex()
			continue
		}
		h := id.hue
		if al.C >= 0.04 {
			h = hueToward(h, al.H, lang.identityPull)
		}
		p.Identity[id.name] = v.mark(h, idC+id.c, id.l).Hex()
	}

	// Data in widgets: three colours of one band, the widget colour and vibrance setting their strength.
	vib := clampF(req.Vibrance, 0, 1)
	k := widgets / s.widgets * (0.8 + 0.4*vib)
	// Stronger widget colour is a deeper pigment, never a dye past the band (160 % gave blood red on Ink).
	data := func(h, c, dl float64) RGB { return v.mark(h, math.Min(s.markC*1.3, c*k), dl) }
	hueOr := func(hex string, fallback float64) float64 {
		if c, ok := seedLCH(hex); ok && c.C >= 0.02 {
			return c.H
		}
		return fallback
	}
	ph := hueOr(req.Seeds.Primary, al.H)
	th := hueOr(req.Seeds.Tertiary, math.Mod(ph+60, 360))
	if hueDistance(th, ph) < 24 {
		// A wallpaper of one hue: the second series takes the mineral pigment farthest from it (gunjo, rokusho, ki).
		far := 0.0
		for _, h := range []float64{262, 160, 85} {
			if d := hueDistance(h, ph); d > far {
				far, th = d, h
			}
		}
	}
	sh := hueOr(req.Seeds.Secondary, ph)
	third := data(sh, s.markC*0.75, 0)
	if hueDistance(sh, ph) < 24 {
		third = data(ph, s.markC*0.6, map[bool]float64{true: 0.12, false: -0.14}[s.dark])
	}
	hl := highlight.LCH()
	idLCH := func(n string) LCH { c, _ := parseHex(p.Identity[n]); return c.LCH() }
	p.Widgets = map[string][]string{
		"wallpaper": hexes(data(ph, s.markC, 0), data(th, s.markC, 0), third),
		"system":    hexes(data(al.H, s.markC, 0), data(hl.H, s.markC, 0), data(150, s.markC*0.9, 0)),
		"spectrum":  hexes(data(idLCH("blue").H, s.markC, 0), data(idLCH("orange").H, s.markC, 0), data(idLCH("teal").H, s.markC, 0)),
		"mono": hexes(data(al.H, s.markC, 0), data(al.H, s.markC*0.7, map[bool]float64{true: 0.12, false: -0.16}[s.dark]),
			data(al.H, s.markC*0.5, map[bool]float64{true: -0.1, false: 0.1}[s.dark])),
	}

	// Swatches for Settings: each choice as it would be solved here.
	p.Materials = map[string]string{}
	for _, m := range lang.materialNames {
		p.Materials[m] = paperOf(lang, s, m, req).RGB().Hex()
	}
	// Each paper level as it would be with this material, for Settings' level tiles.
	if levels, ok := paperLevels[name]; ok {
		p.Papers = map[string]string{}
		for _, l := range levels {
			other := req
			other.Tune = map[string]Tune{}
			for k, t := range req.Tune {
				other.Tune[k] = t
			}
			t := other.Tune[name]
			t.Tone, t.Warmth = l.tone, &l.warmth
			other.Tune[name] = t
			other.DarkStyle = "ink" // a night paper is washi's, whatever Dark wears now
			p.Papers[l.name] = paperOf(schemeLanguage(other, name), s, material, other).RGB().Hex()
		}
	}
	p.Accents = map[string]string{}
	for n, hex := range lang.accentSeeds {
		c, _ := seedLCH(hex)
		p.Accents[n] = v.accent(c).Hex()
	}
	for _, n := range []string{"wallpaper", "theme", "custom"} {
		p.Accents[n] = v.accent(v.seedOf(n, req.AccentHue, lang.accentSeeds, "blue")).Hex()
	}
	p.Highlights = map[string]string{"accent": p.Accent}
	for n, hex := range lang.highlightSeeds {
		c, _ := seedLCH(hex)
		p.Highlights[n] = v.highlight(c).Hex()
	}
	p.Highlights["wallpaper"] = v.highlight(v.seedOf("wallpaperHighlight", 0, lang.highlightSeeds, "orange")).Hex()
	p.Highlights["theme"] = v.highlight(v.seedOf("themeHighlight", 0, lang.highlightSeeds, "orange")).Hex()
	p.Highlights["custom"] = v.highlight(hsl(req.HighlightHue, 0.92, 0.58).LCH()).Hex()
	p.Apps = v.apps(p, accent, highlight, danger, cont)
	return p
}

// apps is the same palette in Material's role names, for the app theme generator: apps wear the shell's paper,
// ink and accent, not a second interpretation of the wallpaper.
func (v solver) apps(p Palette, accent, highlight, danger, cont RGB) map[string]string {
	s, pc, neutral := v.s, v.ramp.Surface, v.lang.neutralHue
	if pc.C < 0.004 {
		pc.H = neutral
	}
	sign := 1.0
	if !s.dark {
		sign = -1
	}
	// A window is read for hours: at night it sits on a lifted ground (Material's tone 6, Apple's #1c1c1e family),
	// never the shell's black, and its planes step as far apart as Material's so containers and lines show.
	base := pc
	if s.dark && base.L < appsNightL {
		base = LCH{appsNightL, math.Max(base.C, 0.004), base.H}
	}
	if c, ok := seedLCH(v.req.Seeds.Wallpaper); ok && v.req.Glass && c.C >= 0.02 && s.name != "ink" {
		// Under glass the shell reads as frost over the wallpaper: a window beside it carries that frost's hue, not a
		// neutral that looks foreign next to it. Ink keeps its paper: that is what Ink is.
		frost := paperOf(v.lang, s, "wallpaper", v.req)
		base.H, base.C = frost.H, math.Max(base.C, math.Min(frost.C, map[bool]float64{true: 0.024, false: 0.018}[s.dark]))
		pc.H = frost.H
	}
	at := func(d, cScale float64) string {
		q := base
		if s.dark {
			d *= appsNightStep
		}
		q.L = clampF(q.L+sign*d, 0, 1)
		q.C = math.Min(0.05, q.C*cScale)
		return q.RGB().Hex()
	}
	al, hl, dl := accent.LCH(), highlight.LCH(), danger.LCH()
	deepest, _ := parseHex(at(0.105, 1.15))
	grounds := append([]RGB{deepest}, v.grounds...)
	accentFrom, textGrounds := s.accentL, grounds
	if !s.dark {
		// A window on paper has its own planes, not the shell's ink groups over frost: its colours read on those, from
		// the lightest tone that does (the shell's deep ink is the loud button the eye trips on). A fill reads 4.5:1 on
		// the window, its cards and wells; on the deepest container (a pressed tab) it keeps a shape's 3:1, as Material.
		lowest, _ := parseHex(at(-0.012, 0.8))
		ground, _ := parseHex(at(0, 1))
		card, _ := parseHex(at(0.04, 1.05))
		textGrounds = []RGB{lowest, ground, card}
		accentFrom = math.Max(accentFrom, appsPaperFromL)
	}
	// Secondary and tertiary are text in apps (captions, chips): they read on every app plane.
	appRamp := append([]RGB{deepest}, textGrounds...)
	reads := func(need float64) func(RGB) bool {
		if s.dark {
			return readsOn(need, grounds...)
		}
		return both(readsOn(need, textGrounds...), readsOn(math.Min(need, readShape), deepest))
	}
	sec := solve(s, al.H, math.Min(0.06, al.C*0.4), accentFrom, readsOn(readText, appRamp...))
	secCont := LCH{cont.LCH().L, math.Min(0.035, al.C*0.25), al.H}.RGB()
	// Apps paint tertiary on large marks (badges, chips, highlights): Material's band, not the shell's full highlight.
	ter := solve(s, hl.H, math.Min(hl.C, map[bool]float64{true: 0.11, false: 0.09}[s.dark]), accentFrom, readsOn(readText, appRamp...))
	terCont := LCH{cont.LCH().L, math.Min(0.07, hl.C*0.45), hl.H}.RGB()
	errCont := LCH{cont.LCH().L, math.Min(0.08, dl.C*0.45), dl.H}.RGB()
	onC := func(fill RGB, h, c float64) string {
		side := spec{dark: fill.LCH().L < 0.6}
		return solve(side, h, c, map[bool]float64{true: 0.9, false: 0.3}[side.dark], readsOn(readOn, fill)).Hex()
	}
	// A window fills large shapes with primary (buttons, switches, a selected tab) and badges with errorFill, read for
	// hours: the shell's pigment at full strength turns into a loud blue and red there. Same hue and start, less
	// colour, still text on every ground and carrying its own ink.
	appFill := func(hex string, need, paperC, nightC float64) RGB {
		src, _ := parseHex(hex)
		l := src.LCH()
		check := reads(need)
		from := l.L
		if !s.dark {
			check = both(check, readsOn(readOn, v.lang.onColour))
			from = math.Max(from, appsPaperFromL)
		}
		return solve(s, l.H, math.Min(l.C, map[bool]float64{true: nightC, false: paperC}[s.dark]), from, check)
	}
	primary := appFill(p.AccentFill, readText, appsFillC[0], appsFillC[1])
	errorFill := appFill(p.DangerFill, readShape, appsAlertC[0], appsAlertC[1])
	errorText := appFill(p.Danger, readText, appsAlertC[0], appsAlertC[1])
	text, _ := parseHex(p.Text)
	tl := text.LCH()
	variant := solve(s, pc.H, math.Min(0.02, pc.C*1.5+0.006), pc.L+(tl.L-pc.L)*0.62, readsOn(readSecondary, grounds...))
	outline := solve(s, pc.H, math.Min(0.02, pc.C*1.5+0.006), pc.L+(tl.L-pc.L)*0.4, readsOn(readTertiary, grounds...))
	onSurface := solve(s, tl.H, tl.C, tl.L, readsOn(readInk, grounds...)).Hex()
	inverse := map[bool]LCH{true: {0.93, 0.008, pc.H}, false: {0.27, 0.012, pc.H}}[s.dark].RGB()
	inversePrimary := solve(s, al.H, al.C, map[bool]float64{true: 0.5, false: 0.8}[s.dark], readsOn(readText, inverse))
	m := map[string]string{
		// Dim is darker and Bright lighter in both polarities (at moves toward the ink: darker on paper).
		"background": at(0, 1), "surface": at(0, 1), "surfaceDim": at(-0.03*sign, 1), "surfaceBright": at(0.035*sign, 1),
		"surfaceContainerLowest": at(-0.012, 0.8), "surfaceContainerLow": at(0.02, 1), "surfaceContainer": at(0.04, 1.05),
		"surfaceContainerHigh": at(0.065, 1.1), "surfaceContainerHighest": at(0.09, 1.15), "surfaceVariant": at(0.065, 1.2),
		"onBackground": onSurface, "onSurface": onSurface, "onSurfaceVariant": variant.Hex(), "outline": outline.Hex(),
		"outlineVariant": at(0.16, 1.2), "inverseSurface": inverse.Hex(), "inverseOnSurface": at(0, 1),
		// Apps fill with primary and error (buttons, badges, switches): the pigments, not the shell's text accent.
		"primary": primary.Hex(), "onPrimary": v.onFill(primary, readOn).Hex(), "primaryContainer": p.AccentContainer, "onPrimaryContainer": p.OnAccentContainer,
		"inversePrimary": inversePrimary.Hex(), "surfaceTint": primary.Hex(),
		"secondary": sec.Hex(), "onSecondary": v.onFill(sec, readOn).Hex(), "secondaryContainer": secCont.Hex(),
		"onSecondaryContainer": onC(secCont, al.H, 0.05),
		"tertiary":             ter.Hex(), "onTertiary": v.onFill(ter, readOn).Hex(), "tertiaryContainer": terCont.Hex(),
		"onTertiaryContainer": onC(terCont, hl.H, 0.1),
		"error":               errorText.Hex(), "onError": v.onFill(errorText, readOn).Hex(), "errorFill": errorFill.Hex(), "onErrorFill": v.onFill(errorFill, readOn).Hex(), "errorContainer": errCont.Hex(), "onErrorContainer": onC(errCont, dl.H, 0.12),
		"success": p.Success, "shadow": "#000000", "scrim": "#000000",
	}
	return m
}

// The most colour an app's filled primary and alert carry, on paper and at night (Material You's own primary sits
// near 0.07 on paper).
var appsFillC = [2]float64{0.085, 0.12}

// paperFillC is the most colour the shell's own filled shapes keep on paper.
const paperFillC = 0.12

var appsAlertC = [2]float64{0.11, 0.12}

// appsPaperFromL is the lightest an app's colour on paper starts from; appsNightL is the lowest ground a dark app
// window gets; appsNightStep widens the paper's plane steps at night, where OKLCH's small lightness steps vanish.
const (
	appsPaperFromL = 0.62
	appsNightL     = 0.18
	appsNightStep  = 1.45
)

// Output holds every scheme, so switching scheme in Settings needs no new solve.
type Output struct {
	Version int                `json:"version"`
	Request string             `json:"request"` // the request as the shell sent it: the shell compares it to know the file is current
	Schemes map[string]Palette `json:"schemes"`
	// Every style as it would look with the same choices, per scheme: Settings paints its style tiles with them.
	Styles map[string]map[string]StyleSwatch `json:"styles"`
}

// StyleSwatch is a style in a few colours: its paper, a raised group, its ink, its accent and three identities.
type StyleSwatch struct {
	Surface string   `json:"surface"`
	High    string   `json:"high"`
	Text    string   `json:"text"`
	Accent  string   `json:"accent"`
	Dots    []string `json:"dots"`
}

// styleIDs are the styles Settings offers, in its order: a language, or Material You with its variant.
func styleIDs() []string {
	out := []string{"iris", "washi"}
	for _, v := range variants {
		out = append(out, "material:"+v.name)
	}
	return out
}

// Version changes whenever a solve would give other colours for the same request; IrisWashi.qml asks again when it
// differs (TestShellKnowsVersion keeps the two equal).
const Version = 23

// solveSchemes is the palette alone, without the other styles' swatches.
func solveSchemes(req Request, key string) Output {
	out := Output{Version: Version, Request: key, Schemes: map[string]Palette{}}
	for _, s := range languageOf(req).schemes {
		out.Schemes[s.name] = build(req, s.name)
	}
	return out
}

func Solve(req Request, key string) Output {
	out := solveSchemes(req, key)
	out.Styles = map[string]map[string]StyleSwatch{}
	for _, id := range styleIDs() {
		other := req
		other.Language, other.Variant = id, ""
		// A tile shows the style itself: never Ink's washi or the ink night laid over it.
		other.InkStyle, other.DarkStyle = "style", "style"
		if strings.HasPrefix(id, "material:") {
			other.Language, other.Variant = "material", strings.TrimPrefix(id, "material:")
		}
		out.Styles[id] = map[string]StyleSwatch{}
		for _, s := range languageOf(other).schemes {
			p := out.Schemes[s.name]
			if schemeLanguage(other, s.name) != schemeLanguage(req, s.name) {
				p = build(other, s.name)
			}
			out.Styles[id][s.name] = StyleSwatch{Surface: p.Surface, High: p.SurfaceHigh, Text: p.Text, Accent: p.Accent,
				Dots: []string{p.Identity["blue"], p.Identity["green"], p.Identity["orange"]}}
		}
	}
	return out
}
