package main

import "math"

// variant is one of Material You's schemes, measured from materialyoucolor (the generator the other families use)
// and written in OKLCH: how much of the seed the neutrals keep, where the primary and its container sit and how much
// colour they carry. [2] pairs are night, then paper.
type variant struct {
	name       string
	neutralC   [2]float64 // chroma of the surfaces, from the seed's hue
	accentC    [2]float64 // the primary's chroma, least and most
	accentL    [2]float64 // the primary's tone (80 at night, 40 on paper)
	containerL [2]float64 // primaryContainer's tone
	containerC float64
	markC      float64 // the band of marks: identity, highlight, data
}

var variants = []variant{
	{name: "tonalSpot", neutralC: [2]float64{0.012, 0.01}, accentC: [2]float64{0.05, 0.085}, accentL: [2]float64{0.83, 0.48},
		containerL: [2]float64{0.44, 0.87}, containerC: 0.075, markC: 0.1},
	{name: "vibrant", neutralC: [2]float64{0.06, 0.03}, accentC: [2]float64{0.1, 0.18}, accentL: [2]float64{0.77, 0.48},
		containerL: [2]float64{0.75, 0.76}, containerC: 0.17, markC: 0.14},
	{name: "expressive", neutralC: [2]float64{0.03, 0.016}, accentC: [2]float64{0.07, 0.13}, accentL: [2]float64{0.86, 0.49},
		containerL: [2]float64{0.82, 0.83}, containerC: 0.11, markC: 0.12},
	{name: "fidelity", neutralC: [2]float64{0.015, 0.012}, accentC: [2]float64{0.02, 0.2}, accentL: [2]float64{0.83, 0.45},
		containerL: [2]float64{0.55, 0.55}, containerC: 0.2, markC: 0.12},
	{name: "monochrome", neutralC: [2]float64{0, 0}, accentC: [2]float64{0, 0}, accentL: [2]float64{0.99, 0.02},
		containerL: [2]float64{0.87, 0.35}, containerC: 0, markC: 0.07},
}

// materialHue is the hue Material's neutrals take when no seed has one (a grey wallpaper): its own cool grey.
const materialHue = 250.0

// materialLanguage is Material You: surfaces in the seed's own neutral, a primary at tone 80 or 40, containers that
// carry the colour, white on colour. The contracts are the same as washi's, so where M3's nominal tone would not read
// on the real ground the solve moves it until it does.
func materialLanguage(v variant) *Language {
	at := func(dark bool, pair [2]float64) float64 {
		if dark {
			return pair[0]
		}
		return pair[1]
	}
	scheme := func(name string, dark bool, paperL, inkL, markL float64, steps [2]float64) spec {
		return spec{
			name: name, dark: dark, paperL: paperL, paperC: at(dark, v.neutralC), steps: steps, inkL: inkL,
			accentL: at(dark, v.accentL), accentC: v.accentC, markL: markL, markC: v.markC, widgets: 1,
			// Named so the request's material resolves; paper below decides what each one is.
			materials: map[string]LCH{"black": {}, "graphite": {}, "midnight": {}},
		}
	}
	l := &Language{
		name: "material:" + v.name,
		schemes: []spec{
			scheme("dark", true, 0.165, 0.924, 0.8, [2]float64{0.05, 0.104}),
			// Ink in Material is its paper dimmed (surfaceDim): calmer than white, no fibre.
			scheme("ink", false, 0.915, 0.3, 0.55, [2]float64{-0.035, -0.07}),
			scheme("light", false, 0.982, 0.317, 0.55, [2]float64{-0.033, -0.067}),
		},
		materialNames: []string{"black", "graphite", "midnight", "wallpaper", "theme"},
		accentSeeds:   accentSeeds, highlightSeeds: highlightSeeds, identity: identitySeeds, identityPull: 15,
		neutralHue: materialHue, onColour: RGB{1, 1, 1}, darkOn: [2]float64{0.37, 0.06}, tonalOn: true,
		fillFrom: [2]float64{v.accentL[0], v.accentL[1]}, fillC: [2]float64{math.Max(0.02, v.accentC[0]), math.Max(0.02, v.accentC[1])},
	}
	if v.name == "monochrome" {
		l.fillC = [2]float64{0, 0}
	}
	l.paper = func(s spec, name string, seeds Seeds, tone float64) LCH {
		h := materialHue
		for _, hex := range []string{seeds.Wallpaper, seeds.Primary} {
			if c, ok := seedLCH(hex); ok && c.C >= 0.02 {
				h = c.H
				break
			}
		}
		var p LCH
		switch name {
		case "black":
			// Black stays black at night (the Island melts into the screen edge); by day it is Material's brightest
			// surface. Both keep the seed's hue for the groups and the ink.
			p = LCH{0, s.paperC, h}
			if !s.dark {
				p = LCH{s.paperL, s.paperC * 0.6, h}
			}
		case "graphite":
			// Material's Neutral: the seed's hue, almost no colour.
			p = LCH{s.paperL, s.paperC * 0.35, h}
			if !s.dark {
				p.L = s.paperL - 0.033
			}
		case "midnight":
			p = map[bool]LCH{true: {0.187, 0.03, 262}, false: {s.paperL - 0.012, 0.016, 245}}[s.dark]
		case "theme":
			if bg, good := seedLCH(seeds.Background); good && (s.dark && bg.L < 0.36 || !s.dark && bg.L > 0.8) {
				p = LCH{bg.L, math.Min(bg.C, 0.06), bg.H}
				if !s.dark {
					p.L = math.Max(bg.L, s.paperL-0.05)
				}
				break
			}
			fallthrough
		default:
			// The wallpaper: Material You itself, the surface in the seed's neutral at the variant's chroma.
			p = LCH{s.paperL, s.paperC, h}
		}
		if s.dark {
			p.L = clampF(p.L+tone/100*0.4, 0, 0.3)
		} else {
			p.L = clampF(p.L+tone/100*0.3, map[string]float64{"ink": 0.83, "light": 0.89}[s.name], 1)
		}
		return p
	}
	l.ramp = func(s spec, p LCH) Ramp {
		c := math.Min(0.09, math.Max(p.C, s.paperC*0.35)*1.2)
		step := func(i int) LCH {
			if s.dark && p.L < 0.05 {
				return LCH{[2]float64{0.214, 0.269}[i], c, p.H}
			}
			return LCH{clampF(p.L+s.steps[i], 0, 1), c, p.H}
		}
		return Ramp{p, step(0), step(1)}
	}
	l.container = func(s spec, pc, al LCH) LCH {
		// M3's tone 30 / 90, held off the paper it sits on: a dimmed or toned paper keeps its container below it by
		// day and above it at night, never a lit patch.
		L := math.Max(at(true, v.containerL), pc.L+0.16)
		if !s.dark {
			L = math.Min(at(false, v.containerL), pc.L-0.075)
		}
		return LCH{L, math.Min(v.containerC, math.Max(al.C, v.accentC[0])), al.H}
	}
	l.inkChroma = func(s spec, pc LCH) float64 { return math.Min(0.04, 0.008+pc.C*0.45) }
	return l
}
