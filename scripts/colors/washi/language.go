package main

// The contrasts every role is held to, in every language: what reads is not a matter of style. A language decides
// where a role starts and how much colour it carries; solve keeps it from going under these.
const (
	readInk       = 7.0 // body text, on every ground
	readSecondary = 4.5 // secondary text
	readTertiary  = 3.0 // tertiary text, a line that has to be seen
	readMark      = 3.0 // a glyph or a figure: highlight, identity, widget data, warning
	readText      = 4.5 // a colour that is also text: the accent on paper, success, danger, an app's primary
	readOverGlass = 3.0 // the accent over the glass frost (a backdrop, not a page)
	readWash      = 3.5 // the accent on its own 15 % wash
	readShape     = 3.0 // a filled shape that is not text (a badge)
	readOn        = 4.5 // ink on a filled colour, and a colour that carries the language's own ink
)

// namedHex is a colour by the name a choice or a meaning goes by.
type namedHex struct{ name, hex string }

type identitySeed struct {
	name string
	hue  float64 // OKLCH hue; below zero is the neutral, in the paper's own hue
	l, c float64 // offsets from the mark band
}

// Language is an aesthetic: its schemes' grounds and bands, the seeds its named choices start from, and how it
// builds a ground, a container and the ink on colour. Everything else (the contracts, the solve, the roles) is shared,
// so any language reads as well as any other.
type Language struct {
	name           string
	schemes        []spec
	materialNames  []string // the materials Settings offers, swatched for each scheme
	accentSeeds    map[string]string
	highlightSeeds map[string]string
	identity       []identitySeed
	identityPull   float64    // the most degrees an identity hue turns toward the accent
	identityHex    []namedHex // identities kept as these colours (their own lightness and chroma) instead of one band
	neutralHue     float64    // the warmth of ink and greys where the ground has no hue of its own
	onColour       RGB        // the light ink on a filled colour
	darkOn         [2]float64 // the dark ink on a filled colour: lightness and most chroma, in the fill's hue
	tonalOn        bool       // the dark ink is the fill's own tone, solved to read (Material's onPrimary), not a fixed sumi
	fillFrom       [2]float64 // where a filled shape starts, at night and on paper
	fillC          [2]float64 // the chroma a filled shape keeps
	paper          func(s spec, name string, seeds Seeds, tone float64) LCH
	ramp           func(s spec, p LCH) Ramp
	container      func(s spec, paper, accent LCH) LCH // the accent's tonal container on this ground
	inkChroma      func(s spec, paper LCH) float64     // how much of the paper's hue the ink keeps
}

func (l *Language) specOf(name string) spec {
	for _, s := range l.schemes {
		if s.name == name {
			return s
		}
	}
	return l.schemes[0]
}

var languages = map[string]*Language{"washi": &washi}

func init() {
	for _, v := range variants {
		languages["material:"+v.name] = materialLanguage(v)
	}
}

// languageOf resolves a request's language; an unknown or empty one is washi, the shell's own. Material without a
// known variant is Tonal spot, Material You's own default.
func languageOf(req Request) *Language {
	if req.Language == "material" {
		if l, ok := languages["material:"+req.Variant]; ok {
			return l
		}
		return languages["material:tonalSpot"]
	}
	if l, ok := languages[req.Language]; ok {
		return l
	}
	return &washi
}
