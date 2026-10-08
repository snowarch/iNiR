package main

import (
	"fmt"
	"os"
	"strings"
	"testing"
)

func TestShellKnowsVersion(t *testing.T) {
	qml, err := os.ReadFile("../../../modules/iris/style/IrisWashi.qml")
	if err != nil {
		t.Fatal(err)
	}
	if want := fmt.Sprintf("readonly property int version: %d", Version); !strings.Contains(string(qml), want) {
		t.Errorf("IrisWashi.qml must declare %q", want)
	}
}

// Settings' paper tiles write the same tone and warmth the solver swatches them with.
func TestShellKnowsPaperLevels(t *testing.T) {
	qml, err := os.ReadFile("../../../modules/iris/settings/IrisOptions.qml")
	if err != nil {
		t.Fatal(err)
	}
	for _, levels := range paperLevels {
		for _, l := range levels {
			want := fmt.Sprintf("\"%s\", %g, %g]", l.name, l.tone, l.warmth)
			if !strings.Contains(string(qml), want) {
				t.Errorf("IrisOptions.paperChoices must carry %s", want)
			}
		}
	}
}

// Paper levels keep the language's paper at its own warmth, read on every level, and Ink wears washi unless asked.
func TestPaperLevels(t *testing.T) {
	for _, lang := range []string{"iris", "washi", "material"} {
		for scheme, levels := range paperLevels {
			plain := build(Request{Language: lang, Material: "black"}, scheme)
			own := ownWarmth[scheme]
			same := build(Request{Language: lang, Material: "black", Tune: map[string]Tune{scheme: {Warmth: &own}}}, scheme)
			if plain.Surface != same.Surface {
				t.Errorf("%s %s: own warmth moved the paper %s -> %s", lang, scheme, plain.Surface, same.Surface)
			}
			for _, l := range levels {
				w := l.warmth
				p := build(Request{Language: lang, Material: "black", Tune: map[string]Tune{scheme: {Tone: l.tone, Warmth: &w}}}, scheme)
				text, _ := parseHex(p.Text)
				for _, g := range []string{p.Surface, p.SurfaceHigh, p.SurfaceHighest} {
					ground, _ := parseHex(g)
					if contrast(text, ground) < readInk {
						t.Errorf("%s %s %s: ink %s on %s", lang, scheme, l.name, p.Text, g)
					}
				}
			}
		}
	}
	washiInk := build(Request{Language: "washi", Material: "black"}, "ink").Surface
	if got := build(Request{Language: "iris", Material: "black"}, "ink").Surface; got != washiInk {
		t.Errorf("Ink under iRiS wears %s, want washi's %s", got, washiInk)
	}
	if got := build(Request{Language: "iris", Material: "black", InkStyle: "style"}, "ink").Surface; got == washiInk {
		t.Errorf("Ink following the style still wears washi's %s", got)
	}
}

// Every combination Settings can make must read: each language and variant, scheme, material, accent, highlight,
// tone and colour strength, over seeds from a grey, a vivid and a pale wallpaper and a dark and a light colour theme.
// Washi runs every accent; each Material variant every third, in parallel.
func TestEveryCombinationReads(t *testing.T) {
	type lang struct{ name, variant string }
	langs := []lang{{"washi", ""}, {"iris", ""}}
	for _, v := range variants {
		langs = append(langs, lang{"material", v.name})
	}
	for _, l := range langs {
		t.Run(l.name+":"+l.variant, func(t *testing.T) {
			t.Parallel()
			everyCombinationReads(t, l.name, l.variant)
		})
	}
}

func everyCombinationReads(t *testing.T, language, variant string) {
	seedSets := []Seeds{
		{Wallpaper: "#7a7a7a", Primary: "#a8c7fa", Secondary: "#bec6dc", Tertiary: "#dcbce0", Background: "#111318"},
		{Wallpaper: "#d0201a", Primary: "#ffb4a8", Secondary: "#e7bdb6", Tertiary: "#dfc38c", Background: "#1a110f"},
		{Wallpaper: "#ffdd88", Primary: "#835514", Secondary: "#725b41", Tertiary: "#5c6330", Background: "#fff8f4"},
		{Wallpaper: "#20e030", Primary: "#006e1c", Secondary: "#52634f", Tertiary: "#38656a", Background: "#f7fbf1"},
		{},
	}
	accents := []string{"blue", "mint", "rose", "lilac", "wallpaper", "theme"}
	for h := 0; h < 360; h += 30 {
		accents = append(accents, fmt.Sprintf("custom:%d", h))
	}
	highlights := []string{"orange", "yellow", "red", "pink", "green", "accent", "wallpaper", "theme", "custom"}
	f := func(v float64) *float64 { return &v }
	ratio := func(a, b string) float64 {
		x, _ := parseHex(a)
		y, _ := parseHex(b)
		return contrast(x, y)
	}
	failures := 0
	check := func(where, what, fg string, grounds []string, need float64) {
		for _, g := range grounds {
			if r := ratio(fg, g); r < need-0.02 {
				failures++
				if failures <= 400 {
					t.Errorf("%s: %s %s on %s is %.2f < %.1f", where, what, fg, g, r, need)
				}
			}
		}
	}
	for si, seeds := range seedSets {
		for _, material := range []string{"black", "graphite", "midnight", "wallpaper", "theme"} {
			for ai, accent := range accents {
				if language != "washi" && ai%3 != 0 {
					continue
				}
				for hi := 0; hi < 3; hi++ {
					highlight := highlights[(len(accent)+hi*4)%len(highlights)]
					for _, tone := range []float64{-30, 0, 30} {
						for _, colour := range []float64{0, 60, 100} {
							req := Request{Language: language, Variant: variant, Material: material, Accent: accent, Highlight: highlight,
								HighlightHue: 40, Vibrance: 1, Seeds: seeds}
							if len(accent) > 7 && accent[:7] == "custom:" {
								fmt.Sscanf(accent[7:], "%f", &req.AccentHue)
								req.Accent = "custom"
							}
							req.Tune = map[string]Tune{}
							for _, s := range schemes {
								req.Tune[s.name] = Tune{Tone: tone, Colour: f(colour), Widgets: f(160)}
							}
							out := solveSchemes(req, "")
							for name, p := range out.Schemes {
								where := fmt.Sprintf("%s:%s seeds %d %s %s/%s/%s tone %.0f colour %.0f", language, variant, si, name, material, accent, highlight, tone, colour)
								grounds := []string{p.Surface, p.SurfaceHigh, p.SurfaceHighest}
								if !p.Dark {
									paperRGB, _ := parseHex(p.Surface)
									inkRGB, _ := parseHex(p.Text)
									for _, g := range glassGrounds(paperRGB, inkRGB) {
										grounds = append(grounds, g.Hex())
									}
								}
								check(where, "text", p.Text, grounds, 7)
								check(where, "textSecondary", p.TextSecondary, grounds, 4.5)
								check(where, "textTertiary", p.TextTertiary, grounds, 3)
								papers := []string{p.Surface, p.SurfaceHigh, p.SurfaceHighest}
								check(where, "accent", p.Accent, papers, 4.5)
								check(where, "accentOverGlass", p.Accent, grounds, 3)
								check(where, "onAccent", p.OnAccent, []string{p.Accent}, 4.5)
								ac, _ := parseHex(p.Accent)
								far, _ := parseHex(papers[0])
								for _, g := range papers {
									gc, _ := parseHex(g)
									if p.Dark == (luminance(gc) > luminance(far)) {
										far = gc
									}
								}
								check(where, "accentOnWash", p.Accent, []string{over(ac, far, 0.15).Hex()}, 3.4)
								check(where, "onAccentContainer", p.OnAccentContainer, []string{p.AccentContainer}, 4.5)
								check(where, "highlight", p.Highlight, grounds, 3)
								check(where, "success", p.Success, grounds, 4.5)
								check(where, "warning", p.Warning, grounds, 3)
								check(where, "danger", p.Danger, grounds, 4.5)
								check(where, "onDanger", p.OnDanger, []string{p.Danger}, 4.5)
								for id, c := range p.Identity {
									check(where, "identity."+id, c, grounds, 3)
								}
								for set, cs := range p.Widgets {
									for i, c := range cs {
										check(where, fmt.Sprintf("widgets.%s[%d]", set, i), c, grounds, 3)
									}
								}
								a := p.Apps
								ramp := []string{a["background"], a["surfaceContainerLowest"], a["surfaceContainerLow"], a["surfaceContainer"],
									a["surfaceContainerHigh"], a["surfaceContainerHighest"]}
								check(where, "apps.onSurface", a["onSurface"], ramp, 7)
								check(where, "apps.onSurfaceVariant", a["onSurfaceVariant"], ramp, 4.5)
								check(where, "apps.primary", a["primary"], ramp, 3)
								check(where, "apps.secondary", a["secondary"], ramp, 4.5)
								check(where, "apps.tertiary", a["tertiary"], ramp, 4.5)
								check(where, "apps.outline", a["outline"], ramp, 3)
								for _, pair := range [][2]string{{"onPrimary", "primary"}, {"onSecondary", "secondary"}, {"onTertiary", "tertiary"},
									{"onError", "error"}, {"onPrimaryContainer", "primaryContainer"}, {"onSecondaryContainer", "secondaryContainer"},
									{"onTertiaryContainer", "tertiaryContainer"}, {"onErrorContainer", "errorContainer"}, {"inversePrimary", "inverseSurface"},
									{"inverseOnSurface", "inverseSurface"}} {
									check(where, "apps."+pair[0], a[pair[0]], []string{a[pair[1]]}, 4.5)
								}
							}
						}
					}
				}
			}
		}
	}
	if failures > 0 {
		t.Fatalf("%d checks failed", failures)
	}
}

// A paper is a ground: never a colour, never off its scheme's polarity.
func TestPapersStayPapers(t *testing.T) {
	for _, seeds := range []Seeds{{Wallpaper: "#ff0000", Primary: "#ff0000", Background: "#ff0000"}, {Wallpaper: "#00ff00", Background: "#000000"}} {
		for _, s := range schemes {
			for _, m := range []string{"black", "graphite", "midnight", "wallpaper", "theme"} {
				for _, tone := range []float64{-30, 0, 30} {
					p := paper(s, m, seeds, tone)
					if p.C > 0.05 {
						t.Errorf("%s %s: paper chroma %.3f", s.name, m, p.C)
					}
					if s.dark && p.L > 0.36 || !s.dark && p.L < 0.7 {
						t.Errorf("%s %s tone %.0f: paper lightness %.2f", s.name, m, tone, p.L)
					}
				}
			}
		}
	}
}

// Apps read Material's ladder by name: Dim darker, Bright lighter, containers stepping toward the ink, in every
// scheme and material (Bright came out darker on paper once).
func TestAppSurfacesKeepTheirOrder(t *testing.T) {
	l := func(hex string) float64 { c, _ := parseHex(hex); return c.LCH().L }
	for _, s := range schemes {
		for _, m := range []string{"black", "graphite", "midnight", "wallpaper", "theme"} {
			a := build(Request{Material: m, Seeds: Seeds{Wallpaper: "#7a4030", Primary: "#a8c7fa", Background: "#1a110f"}}, s.name).Apps
			surface := l(a["surface"])
			if l(a["surfaceDim"]) > surface+1e-6 || l(a["surfaceBright"]) < surface-1e-6 {
				t.Errorf("%s %s: dim %s / surface %s / bright %s", s.name, m, a["surfaceDim"], a["surface"], a["surfaceBright"])
			}
			// A dark window on the black material once came out #000000 in every plane: it sits lifted, and its
			// planes stand apart.
			if s.dark && (surface < appsNightL-0.01 || l(a["surfaceContainerHighest"])-surface < 0.1) {
				t.Errorf("%s %s: surface %s, highest %s", s.name, m, a["surface"], a["surfaceContainerHighest"])
			}
			ladder := []string{"surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest"}
			for i := 1; i < len(ladder); i++ {
				prev, next := l(a[ladder[i-1]]), l(a[ladder[i]])
				if s.dark && next < prev || !s.dark && next > prev {
					t.Errorf("%s %s: %s %s then %s %s", s.name, m, ladder[i-1], a[ladder[i-1]], ladder[i], a[ladder[i]])
				}
			}
		}
	}
}

// Filled shapes are pigments with their own ink: never sunk toward black (the badges once came out #750007 on Ink),
// never a screen's pure white on them.
func TestFillsArePigments(t *testing.T) {
	for _, s := range schemes {
		for _, tone := range []float64{-30, 0, 30} {
			for _, accent := range []string{"blue", "rose", "wallpaper", "theme"} {
				req := Request{Material: "black", Accent: accent, Highlight: "orange",
					Tune:  map[string]Tune{s.name: {Tone: tone}},
					Seeds: Seeds{Wallpaper: "#432f2c", Primary: "#834037", Secondary: "#6c4c47", Tertiary: "#6e4d1d", Background: "#ccc7ba"}}
				p := build(req, s.name)
				for _, pair := range [][2]string{{p.AccentFill, p.OnAccentFill}, {p.DangerFill, p.OnDangerFill}, {p.HighlightFill, p.OnHighlightFill}} {
					fill, _ := parseHex(pair[0])
					ink, _ := parseHex(pair[1])
					if contrast(fill, ink) < 4.5 {
						t.Errorf("%s tone %.0f %s: ink %s on %s reads %.2f", s.name, tone, accent, pair[1], pair[0], contrast(fill, ink))
					}
					if pair[1] == "#ffffff" {
						t.Errorf("%s %s: pure white ink on %s", s.name, accent, pair[0])
					}
					if l := fill.LCH().L; l < 0.36 {
						t.Errorf("%s tone %.0f %s: fill %s sinks to L %.2f", s.name, tone, accent, pair[0], l)
					}
				}
			}
		}
	}
}

func TestRoundTrip(t *testing.T) {
	for _, hex := range []string{"#000000", "#ffffff", "#0a60d1", "#ff9f0a", "#26231f"} {
		c, _ := parseHex(hex)
		if got := c.LCH().RGB().Hex(); got != hex {
			t.Errorf("%s -> %s", hex, got)
		}
	}
}
