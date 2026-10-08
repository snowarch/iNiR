package main

import (
	"math"
	"testing"
)

// Material reads like Material You: for a blue seed, Tonal spot lands near materialyoucolor's own roles (measured
// from scheme_tonal_spot, in OKLCH lightness), so iRiS in Material and the other families wear one palette.
func TestMaterialTracksM3(t *testing.T) {
	seeds := Seeds{Wallpaper: "#0a60d1", Primary: "#0a60d1", Secondary: "#565e71", Tertiary: "#705575", Background: "#111318"}
	req := Request{Language: "material", Variant: "tonalSpot", Material: "wallpaper", Accent: "wallpaper", Highlight: "theme", Seeds: seeds}
	l := func(hex string) LCH { c, _ := parseHex(hex); return c.LCH() }
	want := map[string]map[string]float64{
		"dark":  {"surface": 0.165, "surfaceHigh": 0.24, "text": 0.924, "accent": 0.828, "accentContainer": 0.441, "onAccentContainer": 0.918},
		"light": {"surface": 0.982, "surfaceHigh": 0.931, "text": 0.317, "accent": 0.486, "accentContainer": 0.847, "onAccentContainer": 0.387},
	}
	for scheme, roles := range want {
		p := build(req, scheme)
		got := map[string]string{"surface": p.Surface, "surfaceHigh": p.SurfaceHigh, "text": p.Text, "accent": p.Accent,
			"accentContainer": p.AccentContainer, "onAccentContainer": p.OnAccentContainer}
		for role, m3 := range roles {
			c := l(got[role])
			if math.Abs(c.L-m3) > 0.07 {
				t.Errorf("%s %s %s: L %.3f, Material You %.3f", scheme, role, got[role], c.L, m3)
			}
			if c.C > 0.03 && hueDistance(c.H, l(seeds.Primary).H) > 20 {
				t.Errorf("%s %s %s: hue %.0f strays from the seed", scheme, role, got[role], c.H)
			}
		}
	}
}

// Each variant keeps its character: Vibrant carries the most colour on its groups and accent, Monochrome none (a
// paper this close to white holds almost no chroma in sRGB, so the groups are what show it).
func TestVariantsDiffer(t *testing.T) {
	seeds := Seeds{Wallpaper: "#0a60d1", Primary: "#0a60d1", Background: "#111318"}
	chroma := func(variant, scheme, role string) float64 {
		p := build(Request{Language: "material", Variant: variant, Material: "wallpaper", Accent: "wallpaper", Seeds: seeds}, scheme)
		c, _ := parseHex(map[string]string{"surfaceHigh": p.SurfaceHigh, "accent": p.Accent}[role])
		return c.LCH().C
	}
	for _, scheme := range []string{"dark", "light"} {
		for _, role := range []string{"surfaceHigh", "accent"} {
			if v, s := chroma("vibrant", scheme, role), chroma("tonalSpot", scheme, role); v <= s {
				t.Errorf("%s %s: vibrant %.3f not above tonal spot %.3f", scheme, role, v, s)
			}
			if m := chroma("monochrome", scheme, role); m > 0.005 {
				t.Errorf("%s %s: monochrome keeps chroma %.3f", scheme, role, m)
			}
		}
	}
}

// Apps read Material's ladder by name in every language: Dim darker, Bright lighter, containers toward the ink.
func TestEveryLanguageKeepsAppOrder(t *testing.T) {
	l := func(hex string) float64 { c, _ := parseHex(hex); return c.LCH().L }
	for _, v := range append([]variant{{name: "iris"}}, variants...) {
		language := "material"
		if v.name == "iris" {
			language = "iris"
		}
		lang := languageOf(Request{Language: language, Variant: v.name})
		for _, s := range lang.schemes {
			for _, m := range lang.materialNames {
				req := Request{Language: language, Variant: v.name, Material: m, Seeds: Seeds{Wallpaper: "#7a4030", Primary: "#a8c7fa", Background: "#1a110f"}}
				a := build(req, s.name).Apps
				if l(a["surfaceDim"]) > l(a["surface"])+1e-6 || l(a["surfaceBright"]) < l(a["surface"])-1e-6 {
					t.Errorf("%s %s %s: dim %s / surface %s / bright %s", v.name, s.name, m, a["surfaceDim"], a["surface"], a["surfaceBright"])
				}
				ladder := []string{"surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest"}
				for i := 1; i < len(ladder); i++ {
					prev, next := l(a[ladder[i-1]]), l(a[ladder[i]])
					if s.dark && next < prev || !s.dark && next > prev {
						t.Errorf("%s %s %s: %s %s then %s %s", v.name, s.name, m, ladder[i-1], a[ladder[i-1]], ladder[i], a[ladder[i]])
					}
				}
			}
		}
	}
}
