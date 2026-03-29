package themegencommon

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"regexp"
	"strings"
)

func ReadStringMapJSON(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, err
	}
	out := map[string]string{}
	for k, v := range raw {
		if s, ok := v.(string); ok {
			out[k] = s
		}
	}
	return out, nil
}

func ParseSCSS(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	re := regexp.MustCompile(`\$(\w+):\s*(#[A-Fa-f0-9]{6}|True|False);`)
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		match := re.FindStringSubmatch(strings.TrimSpace(line))
		if len(match) == 3 {
			out[match[1]] = match[2]
		}
	}
	return out, nil
}

func MergeStringMaps(base map[string]string, overlays ...map[string]string) map[string]string {
	out := map[string]string{}
	for k, v := range base {
		out[k] = v
	}
	for _, overlay := range overlays {
		for k, v := range overlay {
			out[k] = v
		}
	}
	return out
}

func Pick(m map[string]string, key, fallback string) string {
	if v, ok := m[key]; ok && v != "" {
		return v
	}
	return fallback
}

func HexByte(s string) int {
	var v int
	fmt.Sscanf(s, "%x", &v)
	return v
}

func ClampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func Clamp255(v float64) int {
	return ClampInt(int(math.Round(v)), 0, 255)
}

func HexToRGB(color string) (int, int, int) {
	color = strings.TrimPrefix(color, "#")
	if len(color) < 6 {
		return 0, 0, 0
	}
	return HexByte(color[0:2]), HexByte(color[2:4]), HexByte(color[4:6])
}

func RGBToHex(r, g, b int) string {
	return fmt.Sprintf("#%02x%02x%02x", ClampInt(r, 0, 255), ClampInt(g, 0, 255), ClampInt(b, 0, 255))
}

func Blend(color1, color2 string, factor float64) string {
	r1, g1, b1 := HexToRGB(color1)
	r2, g2, b2 := HexToRGB(color2)
	r := int(float64(r1) + (float64(r2-r1) * factor))
	g := int(float64(g1) + (float64(g2-g1) * factor))
	b := int(float64(b1) + (float64(b2-b1) * factor))
	return RGBToHex(r, g, b)
}

func AdjustLightnessScale(color string, factor float64) string {
	r, g, b := HexToRGB(color)
	if factor > 1 {
		r = min(255, int(float64(r)+float64(255-r)*(factor-1)))
		g = min(255, int(float64(g)+float64(255-g)*(factor-1)))
		b = min(255, int(float64(b)+float64(255-b)*(factor-1)))
	} else {
		r = max(0, int(float64(r)*factor))
		g = max(0, int(float64(g)*factor))
		b = max(0, int(float64(b)*factor))
	}
	return RGBToHex(r, g, b)
}

func WithAlpha(color, alpha string) string {
	return color + alpha
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
