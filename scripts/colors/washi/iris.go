package main

import "math"

// irisHue is the cool grey of iRiS's neutrals (Apple's systemGray family): its ink and groups where a material has no
// hue of its own.
const irisHue = 286.0

// The system colours iRiS was drawn with, as people know them: every identity keeps its own lightness and colour
// instead of washi's shared band, so Settings, the Control Center and the widgets read vivid.
var irisIdentityHex = []namedHex{
	{"blue", "#0a84ff"}, {"sky", "#64d2ff"}, {"teal", "#30b0c7"}, {"green", "#34c759"}, {"yellow", "#e0a800"},
	{"orange", "#ff9f0a"}, {"red", "#ff453a"}, {"pink", "#ff375f"}, {"indigo", "#5e5ce6"}, {"purple", "#bf5af2"},
	{"lavender", "#b4a0ff"}, {"gray", "#8e8e93"},
}

// irisLanguage is iRiS's own look from before washi: Apple's black, greys and white, pastel accents at night and
// deep ones by day, Ink as a khaki paper, and the system colours at full strength. The contracts are washi's, so a
// colour that would not read on its ground is moved until it does.
var irisLanguage = &Language{
	name: "iris",
	schemes: []spec{
		{
			name: "dark", dark: true,
			materials: map[string]LCH{"black": {0, 0, 0}, "graphite": {0.192, 0.004, irisHue}, "midnight": {0.161, 0.022, 271}},
			paperL:    0.19, paperC: 0.045, steps: [2]float64{0.035, 0.1}, inkL: 0.97,
			accentL: 0.82, accentC: [2]float64{0.06, 0.1}, markL: 0.76, markC: 0.16, widgets: 1,
		},
		{
			// Ink: the khaki paper iRiS had before washi, with warm sumi.
			name:      "ink",
			materials: map[string]LCH{"black": {0.88, 0.018, 89}, "graphite": {0.827, 0.02, 91}, "midnight": {0.843, 0.009, 248}},
			paperL:    0.85, paperC: 0.04, steps: [2]float64{-0.044, -0.081}, inkL: 0.26,
			accentL: 0.48, accentC: [2]float64{0.06, 0.1}, markL: 0.58, markC: 0.14, widgets: 1,
		},
		{
			name:      "light",
			materials: map[string]LCH{"black": {1, 0, irisHue}, "graphite": {0.935, 0.007, irisHue}, "midnight": {0.938, 0.018, 258}},
			paperL:    0.95, paperC: 0.03, steps: [2]float64{-0.037, -0.077}, inkL: 0.23,
			accentL: 0.51, accentC: [2]float64{0.09, 0.13}, markL: 0.62, markC: 0.17, widgets: 1,
		},
	},
	materialNames: []string{"black", "graphite", "midnight", "wallpaper", "theme"},
	accentSeeds:   accentSeeds, highlightSeeds: highlightSeeds, identity: identitySeeds, identityHex: irisIdentityHex,
	neutralHue: irisHue, onColour: RGB{1, 1, 1}, darkOn: [2]float64{0.23, 0.004},
	fillFrom: [2]float64{0.7, 0.56}, fillC: [2]float64{0.1, 0.16},
}

func init() {
	irisLanguage.paper = func(s spec, name string, seeds Seeds, tone float64) LCH {
		p := paper(s, name, seeds, tone)
		if name == "wallpaper" || name == "theme" {
			// A seed's material keeps more of its colour than washi's fibre: iRiS's wallpaper material was a tinted night.
			if c, ok := seedLCH(seeds.Wallpaper); ok && name == "wallpaper" && c.C >= 0.02 {
				p.C = math.Min(s.paperC, c.C*0.45)
			}
		}
		return p
	}
	irisLanguage.ramp = func(s spec, p LCH) Ramp {
		step := func(i int) LCH {
			switch {
			case s.dark && p.L < 0.05:
				// Black's groups are Apple's systemGray6 and 5.
				return LCH{[2]float64{0.227, 0.294}[i], 0.004, irisHue}
			case !s.dark && p.L > 0.995:
				return LCH{[2]float64{0.963, 0.923}[i], 0.007, irisHue}
			}
			return LCH{clampF(p.L+s.steps[i], 0, 1), p.C, p.H}
		}
		return Ramp{p, step(0), step(1)}
	}
	// The accent laid over its surface at about a fifth, as iRiS mixed it.
	irisLanguage.container = func(s spec, pc, al LCH) LCH {
		if s.dark {
			return LCH{math.Max(0.3, pc.L+0.13), math.Min(0.07, al.C*0.6), al.H}
		}
		return LCH{pc.L - 0.08, math.Min(0.06, al.C*0.35), al.H}
	}
	irisLanguage.inkChroma = func(s spec, pc LCH) float64 {
		if s.name == "ink" {
			return 0.012
		}
		return 0.003
	}
	languages["iris"] = irisLanguage
}
