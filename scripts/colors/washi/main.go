// inir-washi solves iRiS's palette: every role of every scheme (dark, ink, light) from what the person chose and
// the seeds the wallpaper and the colour theme give. The shell and the app themes both read its output, so they
// wear one set of colours.
//
//	inir-washi --request '<json>' [--out file]
//	inir-washi --default            (the palette of a fresh install, for defaults/iris-washi.json)
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func defaultRequest() Request {
	// Light's fresh paper is Soft (defaults/config.json tune.light), so a first start is not a blank white.
	soft := 38.0
	return Request{Language: "iris", Material: "black", Accent: "blue", AccentHue: 212, Highlight: "orange", HighlightHue: 32, Vibrance: 0.85,
		Tune: map[string]Tune{"light": {Tone: -8, Warmth: &soft}}}
}

func main() {
	request := flag.String("request", "", "request as JSON")
	out := flag.String("out", "", "write the palette here (atomically) as well as to stdout")
	def := flag.Bool("default", false, "solve a fresh install's palette")
	flag.Parse()

	req := defaultRequest()
	raw := []byte(*request)
	if !*def {
		if len(raw) == 0 {
			fmt.Fprintln(os.Stderr, "inir-washi: --request or --default")
			os.Exit(2)
		}
		if err := json.Unmarshal(raw, &req); err != nil {
			fmt.Fprintln(os.Stderr, "inir-washi:", err)
			os.Exit(2)
		}
	} else {
		raw, _ = json.Marshal(req)
	}
	data, err := json.Marshal(Solve(req, string(raw)))
	if err != nil {
		fmt.Fprintln(os.Stderr, "inir-washi:", err)
		os.Exit(1)
	}
	if *out != "" {
		tmp := filepath.Join(filepath.Dir(*out), "."+filepath.Base(*out)+".tmp")
		if err := os.WriteFile(tmp, data, 0o644); err == nil {
			err = os.Rename(tmp, *out)
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, "inir-washi:", err)
		}
	}
	os.Stdout.Write(data)
}
