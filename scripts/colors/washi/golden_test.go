package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"testing"
)

// goldenSum is the fingerprint of every scheme goldenMatrix solves (the colours alone, not the version or the other
// styles' swatches). A refactor keeps it; a change that gives other colours updates it together with Version.
const goldenSum = "3ecb810abddce4a8b68d09dfa36cb0c741daa83231bd95d2a5756f910d928ba1"

func goldenMatrix() []Request {
	seedSets := []Seeds{
		{Wallpaper: "#7a7a7a", Primary: "#a8c7fa", Secondary: "#bec6dc", Tertiary: "#dcbce0", Background: "#111318"},
		{Wallpaper: "#d0201a", Primary: "#ffb4a8", Secondary: "#e7bdb6", Tertiary: "#dfc38c", Background: "#1a110f"},
		{Wallpaper: "#ffdd88", Primary: "#835514", Secondary: "#725b41", Tertiary: "#5c6330", Background: "#fff8f4"},
		{},
	}
	f := func(v float64) *float64 { return &v }
	var out []Request
	highlights := []string{"orange", "accent", "wallpaper", "theme", "custom", "pink"}
	for _, seeds := range seedSets {
		for mi, material := range []string{"black", "graphite", "midnight", "wallpaper", "theme"} {
			for ai, accent := range []string{"blue", "rose", "wallpaper", "theme", "custom"} {
				for ti, tone := range []float64{-30, 0, 30} {
					req := Request{Material: material, Accent: accent, AccentHue: float64(40 + ai*70),
						Highlight: highlights[(mi+ai+ti)%len(highlights)], HighlightHue: 32, Vibrance: float64(ti) * 0.5,
						Seeds: seeds, Tune: map[string]Tune{}}
					for _, s := range schemes {
						req.Tune[s.name] = Tune{Tone: tone, Colour: f(100 - float64(ti)*40), Widgets: f(60 + float64(ti)*50)}
					}
					out = append(out, req)
				}
			}
		}
	}
	// The fresh install's choices in washi: the golden is washi's, whatever language a fresh install starts in.
	washiDefault := defaultRequest()
	washiDefault.Language = ""
	return append(out, washiDefault)
}

func goldenFingerprint(t *testing.T) string {
	h := sha256.New()
	for i, req := range goldenMatrix() {
		data, err := json.Marshal(solveSchemes(req, fmt.Sprint(i)).Schemes)
		if err != nil {
			t.Fatal(err)
		}
		h.Write(data)
	}
	return hex.EncodeToString(h.Sum(nil))
}

func TestPalettesUnchanged(t *testing.T) {
	if got := goldenFingerprint(t); got != goldenSum {
		t.Errorf("the solve gives other colours: fingerprint %s, want %s (bump Version and goldenSum if intended)", got, goldenSum)
	}
}
