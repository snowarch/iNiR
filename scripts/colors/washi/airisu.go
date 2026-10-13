package main

import (
	"math"
	"sort"
)

// AIRISU's palette: the traditional Japanese colours of a tuning shop at night. Lacquer black
// (漆黒 shikkoku) and ink black (墨 sumi) for the grounds, shell white (胡粉 gofun) for the ink, the vermilion seal
// (朱 shu) for what is live and kerria amber (山吹 yamabuki) for the glanced detail. The contracts are washi's, so a
// colour that would not read on its ground is moved until it does; the seal keeps its pigment as a fill.
const airisuHue = 85.0 // the warmth of gofun and of the sumi greys

// airisuIdentityHex are the identities as traditional colours: 群青 gunjō, 空色 sorairo, 浅葱 asagi, 若竹 wakatake,
// 山吹 yamabuki, 橙 daidai, 朱 shu, 撫子 nadeshiko, 藍 ai, 菫 sumire, 藤 fuji, 鼠 nezumi.
var airisuIdentityHex = []namedHex{
	{"blue", "#4c6cb3"}, {"sky", "#a0d8ef"}, {"teal", "#00a3af"}, {"green", "#68be8d"}, {"yellow", "#f8b500"},
	{"orange", "#ee7800"}, {"red", "#e5341b"}, {"pink", "#eebbcb"}, {"indigo", "#165e83"}, {"purple", "#7058a3"},
	{"lavender", "#bbbcde"}, {"gray", "#949495"},
}

// The named choices in AIRISU's own colours. "design" is the Design's seal and its amber; the others are the
// variants of the Theme (Gunjō, Asagi, Wakaba) and the nearest traditional colour to each iRiS name.
var airisuAccentSeeds = map[string]string{
	"design": "#e5341b", "blue": "#4c6cb3", "mint": "#00a3af", "rose": "#d0576b", "lilac": "#a59aca", "green": "#b9d08b",
}
var airisuHighlightSeeds = map[string]string{
	"design": "#f8b500", "orange": "#ee7800", "yellow": "#f8b500", "red": "#e5341b", "pink": "#eebbcb", "green": "#b9d08b",
}

func hexLCH(hex string) LCH { c, _ := seedLCH(hex); return c }

// The ladder of the night, from the board: shikkoku lacquer for the canvas, sumi for what is laid on it (+0.058, a
// breath over the board's 0.042 so a group still reads at 1.1:1), tetsu iron for rules and tracks (+0.139). The greys
// are cool and the ink is warm gofun: lacquer and shell, never a screen's grey on grey. A material only gives the
// lacquer its hue; the ladder is AIRISU's own.
var airisuSteps = map[string][2]float64{"dark": {0.058, 0.139}, "ink": {-0.04, -0.09}, "light": {-0.035, -0.08}}

var airisuLanguage = &Language{
	name: "airisu", whole: true, pigments: true, fixedInk: true, dangerSeed: "#f8b500", // red means "live", never "wrong"
	schemes: []spec{
		{
			// Night: shikkoku lacquer, sumi and tetsu, gofun ink. Graphite starts the ladder at sumi, midnight is kon
			// (紺), the lacquer's indigo.
			name: "dark", dark: true,
			materials: map[string]LCH{"black": hexLCH("#0b0b0c"), "graphite": hexLCH("#18181b"), "midnight": {0.165, 0.024, 262}},
			paperL:    0.165, paperC: 0.022, steps: airisuSteps["dark"], inkL: hexLCH("#e9e6df").L,
			accentL: 0.62, accentC: [2]float64{0.14, 0.22}, markL: 0.74, markC: 0.15, widgets: 1,
		},
		{
			// Ink: gofun, the shell white the shop's stickers are printed on, with sumi ink.
			name:      "ink",
			materials: map[string]LCH{"black": hexLCH("#e9e6df"), "graphite": {0.87, 0.012, airisuHue}, "midnight": {0.9, 0.016, 250}},
			paperL:    0.91, paperC: 0.02, steps: airisuSteps["ink"], inkL: hexLCH("#141414").L,
			accentL: 0.56, accentC: [2]float64{0.13, 0.2}, markL: 0.6, markC: 0.14, widgets: 1,
		},
		{
			// Light: gofun bleached toward the page, the same pigments.
			name:      "light",
			materials: map[string]LCH{"black": {0.97, 0.006, airisuHue}, "graphite": {0.935, 0.005, airisuHue}, "midnight": {0.955, 0.012, 250}},
			paperL:    0.962, paperC: 0.012, steps: airisuSteps["light"], inkL: 0.17,
			accentL: 0.58, accentC: [2]float64{0.13, 0.2}, markL: 0.64, markC: 0.15, widgets: 1.1,
		},
	},
	materialNames: []string{"black", "graphite", "midnight", "wallpaper", "theme"},
	accentSeeds:   airisuAccentSeeds, highlightSeeds: airisuHighlightSeeds, identity: identitySeeds, identityHex: airisuIdentityHex,
	neutralHue: airisuHue, onColour: hexLCH("#e9e6df").RGB(), darkOn: [2]float64{0.14, 0.002},
	fillFrom: [2]float64{0.6, 0.56}, fillC: [2]float64{0.09, 0.24},
	wheel: airisuWheel(),
}

// airisuWheel is every hue as a traditional pigment: a colour that comes from outside (a custom hue, the wallpaper,
// the theme) keeps its hue and takes the lightness and chroma of the pigments beside it, so a Material blue becomes
// a gunjō and never stays a screen's blue. Named pigments are the wheel's stops and come out as themselves.
func airisuWheel() []LCH {
	stops := []string{
		"#d0576b", // 今様 imayō
		"#e5341b", // 朱 shu
		"#ee7800", // 橙 daidai
		"#f8b500", // 山吹 yamabuki
		"#d7cf3a", // 鶸 hiwa
		"#b9d08b", // 若葉 wakaba
		"#68be8d", // 若竹 wakatake
		"#00a3af", // 浅葱 asagi
		"#2a83a2", // 縹 hanada
		"#4c6cb3", // 群青 gunjō
		"#7058a3", // 菫 sumire
		"#e95295", // 躑躅 tsutsuji
	}
	out := make([]LCH, len(stops))
	for i, h := range stops {
		out[i] = hexLCH(h)
	}
	sort.Slice(out, func(a, b int) bool { return out[a].H < out[b].H })
	return out
}

func init() {
	airisuLanguage.paper = airisuPaper
	airisuLanguage.ramp = func(s spec, p LCH) Ramp {
		// Each rung keeps the lacquer's hue, a little more of it as it rises (sumi and tetsu are cooler than the black).
		step := func(i int) LCH {
			return LCH{clampF(p.L+s.steps[i], 0, 1), math.Min(0.032, math.Max(p.C, 0.003)*[2]float64{1.3, 1.8}[i]), p.H}
		}
		return Ramp{p, step(0), step(1)}
	}
	// The seal's wash: the pigment laid thin on lacquer or on gofun, more colour than washi's (a sticker, not a stain).
	airisuLanguage.container = func(s spec, pc, al LCH) LCH {
		if s.dark {
			return LCH{math.Max(0.3, pc.L+0.15), math.Min(0.08, al.C*0.45), al.H}
		}
		return LCH{pc.L - 0.08, math.Min(0.06, al.C*0.35), al.H}
	}
	airisuLanguage.inkChroma = func(s spec, pc LCH) float64 {
		if s.dark {
			return 0.009 // gofun
		}
		return 0.004 // shikkoku
	}
	languages["airisu"] = airisuLanguage
}

// airisuPaper is a material as lacquer: the three named ones are the ladder's own; the wallpaper and the theme only
// lend their hue, at a lacquer's chroma, so neither can turn the canvas into a coloured card.
func airisuPaper(s spec, name string, seeds Seeds, tone float64) LCH {
	p, ok := s.materials[name]
	hueOf := func(hexes ...string) bool {
		for _, h := range hexes {
			if c, good := seedLCH(h); good && c.C >= 0.02 {
				p, ok = LCH{s.paperL, math.Min(s.paperC, c.C*0.3), c.H}, true
				return true
			}
		}
		return false
	}
	switch name {
	case "wallpaper":
		hueOf(seeds.Wallpaper, seeds.Primary)
	case "theme":
		hueOf(seeds.Background, seeds.Primary)
	}
	if !ok {
		p = s.materials["black"]
	}
	if s.dark {
		p.L = clampF(p.L+tone/100*0.4, 0.1, 0.3)
	} else {
		p.L = clampF(p.L+tone/100*0.3, map[string]float64{"ink": 0.83, "light": 0.89}[s.name], 1)
	}
	return p
}

// pigmentOf is a seed on the wheel: its hue, and the lightness and chroma of the stops on either side, eased by how
// far it sits between them. Within a few degrees of a stop it is that pigment.
func pigmentOf(wheel []LCH, seed LCH) LCH {
	n := len(wheel)
	for i := 0; i < n; i++ {
		a, b := wheel[i], wheel[(i+1)%n]
		span := math.Mod(b.H-a.H+360, 360)
		at := math.Mod(seed.H-a.H+360, 360)
		if at > span {
			continue
		}
		if at < 4 {
			return a
		}
		if span-at < 4 {
			return b
		}
		t := at / span
		t = t * t * (3 - 2*t)
		L := a.L + (b.L-a.L)*t
		return LCH{L, math.Min(a.C+(b.C-a.C)*t, maxChroma(L, seed.H)), seed.H}
	}
	return seed
}
