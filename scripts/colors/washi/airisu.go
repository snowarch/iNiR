package main

import "math"

// AIRISU's palette (modules/iris/AIRISU.md): the traditional Japanese colours of a tuning shop at night. Lacquer black
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

var airisuLanguage = &Language{
	name: "airisu", whole: true, pigments: true,
	schemes: []spec{
		{
			// Night: shikkoku lacquer at the screen edge, sumi and tetsu for its groups, gofun ink.
			name: "dark", dark: true,
			materials: map[string]LCH{"black": hexLCH("#0b0b0c"), "graphite": hexLCH("#1c1c1e"), "midnight": {0.19, 0.028, 258}},
			paperL:    0.18, paperC: 0.03, steps: [2]float64{0.05, 0.1}, inkL: hexLCH("#e9e6df").L,
			accentL: 0.62, accentC: [2]float64{0.14, 0.22}, markL: 0.74, markC: 0.15, widgets: 1,
		},
		{
			// Ink: gofun, the shell white the shop's stickers are printed on, with shikkoku ink.
			name:      "ink",
			materials: map[string]LCH{"black": hexLCH("#e9e6df"), "graphite": {0.86, 0.012, airisuHue}, "midnight": {0.89, 0.014, 232}},
			paperL:    0.9, paperC: 0.03, steps: [2]float64{-0.04, -0.075}, inkL: 0.2,
			accentL: 0.56, accentC: [2]float64{0.13, 0.2}, markL: 0.6, markC: 0.14, widgets: 1,
		},
		{
			// Light: gofun bleached toward the page, the same pigments a step deeper.
			name:      "light",
			materials: map[string]LCH{"black": {0.97, 0.005, airisuHue}, "graphite": {0.93, 0.006, airisuHue}, "midnight": {0.95, 0.014, 240}},
			paperL:    0.965, paperC: 0.025, steps: [2]float64{-0.035, -0.07}, inkL: 0.17,
			accentL: 0.58, accentC: [2]float64{0.13, 0.2}, markL: 0.64, markC: 0.15, widgets: 1.1,
		},
	},
	materialNames: []string{"black", "graphite", "midnight", "wallpaper", "theme"},
	accentSeeds:   airisuAccentSeeds, highlightSeeds: airisuHighlightSeeds, identity: identitySeeds, identityHex: airisuIdentityHex,
	neutralHue: airisuHue, onColour: hexLCH("#e9e6df").RGB(), darkOn: [2]float64{0.15, 0.004},
	fillFrom: [2]float64{0.6, 0.56}, fillC: [2]float64{0.12, 0.24},
}

func init() {
	airisuLanguage.paper = paper
	airisuLanguage.ramp = func(s spec, p LCH) Ramp {
		step := func(i int) LCH {
			if s.dark && p.L < 0.2 && p.C < 0.006 {
				// Lacquer's groups are sumi and the iron between it and tetsu: neutral, the faintest gofun warmth.
				return LCH{[2]float64{0.205, 0.26}[i] + math.Max(0, p.L-0.137), 0.003, airisuHue}
			}
			return LCH{clampF(p.L+s.steps[i], 0, 1), p.C, p.H}
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
