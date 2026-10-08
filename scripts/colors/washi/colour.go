package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

// RGB is gamma-encoded sRGB, 0..1.
type RGB struct{ R, G, B float64 }

// LCH is OKLCH: perceptual lightness 0..1, chroma, hue in degrees.
type LCH struct{ L, C, H float64 }

func parseHex(s string) (RGB, bool) {
	s = strings.TrimPrefix(strings.TrimSpace(s), "#")
	if len(s) == 8 {
		s = s[2:] // #AARRGGBB as Qt prints it
	}
	if len(s) != 6 {
		return RGB{}, false
	}
	v, err := strconv.ParseUint(s, 16, 32)
	if err != nil {
		return RGB{}, false
	}
	return RGB{float64(v>>16&0xff) / 255, float64(v>>8&0xff) / 255, float64(v&0xff) / 255}, true
}

func (c RGB) Hex() string {
	b := func(v float64) int { return int(math.Round(math.Max(0, math.Min(1, v)) * 255)) }
	return fmt.Sprintf("#%02x%02x%02x", b(c.R), b(c.G), b(c.B))
}

func toLinear(v float64) float64 {
	if v <= 0.04045 {
		return v / 12.92
	}
	return math.Pow((v+0.055)/1.055, 2.4)
}

func toGamma(v float64) float64 {
	if v <= 0.0031308 {
		return 12.92 * v
	}
	return 1.055*math.Pow(v, 1/2.4) - 0.055
}

func (c RGB) lab() (float64, float64, float64) {
	r, g, b := toLinear(c.R), toLinear(c.G), toLinear(c.B)
	l := math.Cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b)
	m := math.Cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b)
	s := math.Cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b)
	return 0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
		1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
		0.0259040371*l + 0.7827717662*m - 0.8086757660*s
}

func fromLab(L, a, b float64) RGB {
	l := L + 0.3963377774*a + 0.2158037573*b
	m := L - 0.1055613458*a - 0.0638541728*b
	s := L - 0.0894841775*a - 1.2914855480*b
	l, m, s = l*l*l, m*m*m, s*s*s
	return RGB{
		toGamma(4.0767416621*l - 3.3077115913*m + 0.2309699292*s),
		toGamma(-1.2684380046*l + 2.6097574011*m - 0.3413193965*s),
		toGamma(-0.0041960863*l - 0.7034186147*m + 1.7076147010*s),
	}
}

func (c RGB) LCH() LCH {
	L, a, b := c.lab()
	h := math.Atan2(b, a) * 180 / math.Pi
	if h < 0 {
		h += 360
	}
	return LCH{L, math.Hypot(a, b), h}
}

func (p LCH) raw() RGB {
	r := p.H * math.Pi / 180
	return fromLab(p.L, p.C*math.Cos(r), p.C*math.Sin(r))
}

func inGamut(c RGB) bool {
	const e = 1e-4
	return c.R >= -e && c.R <= 1+e && c.G >= -e && c.G <= 1+e && c.B >= -e && c.B <= 1+e
}

// maxChroma is the most chroma sRGB holds at this lightness and hue.
func maxChroma(L, H float64) float64 {
	lo, hi := 0.0, 0.4
	for i := 0; i < 24; i++ {
		mid := (lo + hi) / 2
		if inGamut(LCH{L, mid, H}.raw()) {
			lo = mid
		} else {
			hi = mid
		}
	}
	return lo
}

// RGB maps into sRGB by giving up chroma, never lightness or hue.
func (p LCH) RGB() RGB {
	p.L = math.Max(0, math.Min(1, p.L))
	if c := p.raw(); inGamut(c) {
		return clamp(c)
	}
	p.C = maxChroma(p.L, p.H)
	return clamp(p.raw())
}

// clamp also quantizes to 8 bits: a contrast is solved on the colour that will be written, not a finer one.
func clamp(c RGB) RGB {
	f := func(v float64) float64 { return math.Round(math.Max(0, math.Min(1, v))*255) / 255 }
	return RGB{f(c.R), f(c.G), f(c.B)}
}

func luminance(c RGB) float64 {
	return 0.2126*toLinear(c.R) + 0.7152*toLinear(c.G) + 0.0722*toLinear(c.B)
}

func contrast(a, b RGB) float64 {
	x, y := luminance(a), luminance(b)
	if x < y {
		x, y = y, x
	}
	return (x + 0.05) / (y + 0.05)
}

func hsl(h, s, l float64) RGB {
	h = math.Mod(math.Mod(h, 360)+360, 360) / 360
	q := l + s - l*s
	if l < 0.5 {
		q = l * (1 + s)
	}
	p := 2*l - q
	f := func(t float64) float64 {
		t = math.Mod(t+1, 1)
		switch {
		case t < 1.0/6:
			return p + (q-p)*6*t
		case t < 0.5:
			return q
		case t < 2.0/3:
			return p + (q-p)*(2.0/3-t)*6
		}
		return p
	}
	return RGB{f(h + 1.0/3), f(h), f(h - 1.0/3)}
}

// hueToward turns h toward target by half the distance, at most limit degrees (Material's harmonize).
func hueToward(h, target, limit float64) float64 {
	d := math.Mod(target-h+540, 360) - 180
	step := math.Min(math.Abs(d)*0.5, limit)
	if d < 0 {
		step = -step
	}
	return math.Mod(h+step+360, 360)
}

func hueDistance(a, b float64) float64 {
	d := math.Abs(math.Mod(a-b+360, 360))
	return math.Min(d, 360-d)
}
