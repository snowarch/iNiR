#!/usr/bin/env python3
"""Claude Code custom themes from the generated palette.

Writes four files into Claude Code's themes folder:
  inir.json, inir-soft.json                 follow the wallpaper: base dark-ansi / light-ansi, so the syntax colours of
                                            diffs and code blocks are the terminal's own slots 8, 10-14 (keyword 13, storage 14,
                                            number 12, string 10, function 11, comment 8), and every other token is either an
                                            ANSI name (follows the terminal at once) or a hex solved from the palette
  inir-monokai.json, inir-monokai-soft.json fixed retro palette: base dark, which makes Claude Code use Monokai Extended for
                                            syntax and draw red and green bars on diffs (ANSI themes get neither); in light
                                            mode the same families on paper, base light

Claude Code reads a theme file again when it changes, so a running session repaints.
"""
import argparse
import json
import pathlib
import sys

from materialyoucolor.hct import Hct


def to_hct(hex_color: str) -> Hct:
    return Hct.from_int(int("FF" + hex_color.lstrip("#"), 16))


def hct_hex(hue: float, chroma: float, tone: float) -> str:
    return "#%06X" % (Hct.from_hct(hue, max(0.0, chroma), max(0.0, min(100.0, tone))).to_int() & 0xFFFFFF)


def retone(hex_color: str, tone: float, chroma_scale: float = 1.0, min_chroma: float = 0.0) -> str:
    h = to_hct(hex_color)
    return hct_hex(h.hue, max(min_chroma, h.chroma * chroma_scale), tone)


ANSI = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")


def ansi(slot: int) -> str:
    return "ansi:" + (ANSI[slot] if slot < 8 else ANSI[slot - 8] + "Bright")


ROLE_SLOT = {
    "dark": dict(success=10, error=9, warning=11, permission=12, suggestion=12, remember=12, planMode=14, autoAccept=13,
                 skill=13, bashBorder=13, merged=13, ide=4),
    "light": dict(success=2, error=1, warning=3, permission=4, suggestion=4, remember=4, planMode=6, autoAccept=5,
                  skill=5, bashBorder=5, merged=5, ide=4),
}


def dynamic(name: str, soft: bool, term: dict, palette: dict, mode: str) -> dict:
    dark = mode != "light"
    bg = to_hct(term["term0"])
    t0 = bg.tone
    sign = 1 if dark else -1
    primary = to_hct(palette["primary"])
    ph = primary.hue

    accent = hct_hex(ph, 30 if soft else max(36.0, min(primary.chroma, 60.0)), (70 if dark else 46) if soft else (74 if dark else 42))
    accent_hi = retone(accent, 86 if dark else 55)
    slot = ROLE_SLOT["dark" if dark else "light"]

    o = {
        "text": term["term15"],
        "inverseText": term["term0"],
        "claude": accent,
        "claudeShimmer": accent_hi,
        "clawd_body": accent,
        "rate_limit_fill": accent,
        "rate_limit_empty": hct_hex(bg.hue, min(bg.chroma, 14), t0 + sign * 12),
        "promptBorder": hct_hex(ph, 10 if soft else 16, 48 if dark else 56),
        "promptBorderShimmer": hct_hex(ph, 14 if soft else 22, 62 if dark else 44),
        "subtle": hct_hex(bg.hue, min(bg.chroma, 8), 40 if dark else 72),
        "inactive": "ansi:blackBright",
        "inactiveShimmer": "ansi:white" if dark else "ansi:black",
        "professionalBlue": ansi(slot["ide"]),
        "userMessageBackground": hct_hex(ph, 10 if soft else 14, t0 + sign * 11),
        "userMessageBackgroundHover": hct_hex(ph, 12 if soft else 16, t0 + sign * 15),
        "composerSidebarBackground": hct_hex(bg.hue, min(bg.chroma, 12), t0 + sign * 5),
        "bashMessageBackgroundColor": hct_hex(to_hct(term["term5"]).hue, 14 if dark else 10, t0 + sign * 10),
        "memoryBackgroundColor": hct_hex(to_hct(term["term6"]).hue, 12 if dark else 9, t0 + sign * 10),
        "selectionBg": hct_hex(ph, 24 if dark else 18, 34 if dark else 84),
    }
    add_hue, del_hue = to_hct(term["term2"]).hue, to_hct(term["term1"]).hue
    # Red reads far more saturated than green at one chroma this dark: each takes the chroma that looks as strong as the other.
    for key, hue, strength in (("Added", add_hue, 1.0), ("Removed", del_hue, 0.7)):
        o[f"diff{key}"] = hct_hex(hue, (18 if dark else 14) * strength, t0 + sign * 8)
        o[f"diff{key}Word"] = hct_hex(hue, (30 if dark else 24) * strength, t0 + sign * 16)
        o[f"diff{key}Dimmed"] = hct_hex(hue, 8 * strength, t0 + sign * 5)
    if soft:
        fg = to_hct(term["term15"])
        text = hct_hex(fg.hue, fg.chroma, fg.tone - 4 if dark else fg.tone + 4)
        o["text"] = text
        for role, s in slot.items():
            n = s - 8 if s >= 9 else s
            o[role] = retone(term[f"term{n}"], to_hct(term[f"term{n}"]).tone + (0 if dark else 3), 0.8)
        o["professionalBlue"] = o["ide"]
        for shim, role in (("warningShimmer", "warning"), ("permissionShimmer", "permission")):
            o[shim] = retone(o[role], 84 if dark else 52)
    return {"name": name, "base": ("dark-ansi" if dark else "light-ansi"), "overrides": o}


VIVID = dict(
    text="#F8F8F2", inverse="#1C1A17", amber="#FFA23A", amber_hi="#FFC57A", cyan="#66D9EF", cyan_hi="#A6EAF6",
    green="#A6E22E", green_hi="#C8F26B", red="#FF5C73", red_hi="#FF9AA8", yellow="#FFD04A", yellow_hi="#FFE58F",
    purple="#AE81FF", purple_hi="#CDB4FF", pink="#F92672", pink_hi="#FF73A6", teal="#5FD7AF", blue="#82A0FF",
    violet="#D78AFF", inactive="#A39B86", inactive_hi="#C9C1AA", subtle="#6E685A", border="#8C8570", border_hi="#B5AD94",
    umsg="#3D3631", umsg_hover="#4A423B", side="#2C2723", bash="#442B38", memory="#2B3D40", select="#5A4B3A",
    add_bg="#1F5A2B", add_word="#27682F", add_dim="#2A3A2D", del_bg="#6A2230", del_word="#8E2F45", del_dim="#3E2A2E",
    rl_empty="#4F4333", fast="#FF7A1A", fast_hi="#FFAA55",
)
MONOKAI_SOFT = dict(
    VIVID, text="#DDD6C6", amber="#E8A060", amber_hi="#F2C494", cyan="#7FC8D8", cyan_hi="#B1DCE6", green="#A7CC6B",
    green_hi="#C4DD9A", red="#E5707F", red_hi="#EFA2AB", yellow="#E6C675", yellow_hi="#F0D9A0", purple="#A890DC",
    purple_hi="#C6B6E8", pink="#DB6F98", pink_hi="#E8A1BC", teal="#74C2A4", blue="#91A6E6", violet="#C595E0",
    inactive="#968F7C", inactive_hi="#B8B19D", subtle="#645F53", border="#7C7662", border_hi="#A39C86", umsg="#37312D",
    umsg_hover="#423B36", side="#29251F", bash="#3C2A34", memory="#2A383A", select="#52463A", add_bg="#23472B",
    add_word="#337043", add_dim="#2A352C", del_bg="#552A33", del_word="#8F4252", del_dim="#392C2F", rl_empty="#473E31",
    fast="#E58A3A", fast_hi="#EFAE72",
)


# Paper variants: inks deep enough to read on a light terminal; base light so code blocks use a light syntax theme.
PAPER = dict(
    text="#2A241E", inverse="#F6F1E7", amber="#A8480A", amber_hi="#C8661E", cyan="#0B6A80", cyan_hi="#1A88A0",
    green="#4A720C", green_hi="#5E8C1A", red="#B02640", red_hi="#CC4A60", yellow="#7F5A00", yellow_hi="#9C7210",
    purple="#6440B8", purple_hi="#7E5CD0", pink="#AE1758", pink_hi="#C83E78", teal="#0C7058", blue="#2C50B0",
    violet="#8438AE", inactive="#6E6656", inactive_hi="#4F483B", subtle="#8E8673", border="#9A927D", border_hi="#6E6656",
    fast="#B8520C", fast_hi="#D2701E",
)
PAPER_SOFT = dict(
    PAPER, text="#3A332B", amber="#9A5524", cyan="#2A6B78", green="#557236", red="#A0414F", yellow="#77602A",
    purple="#6A5598", pink="#9C3C64", teal="#2E6A58", blue="#40589C", violet="#7C4C98",
)


def paper_backgrounds(p: dict, term: dict) -> dict:
    bg = to_hct(term["term0"])
    t0 = bg.tone
    neutral = lambda dt, c=10: hct_hex(bg.hue, min(bg.chroma, c), t0 + dt)
    add, rem = to_hct(term["term2"]).hue, to_hct(term["term1"]).hue
    return dict(p, umsg=neutral(-7), umsg_hover=neutral(-11), side=neutral(-4), select=hct_hex(to_hct(p["amber"]).hue, 20, t0 - 12),
        bash=hct_hex(to_hct(p["pink"]).hue, 10, t0 - 8), memory=hct_hex(to_hct(p["teal"]).hue, 10, t0 - 8),
        add_bg=hct_hex(add, 18, t0 - 8), add_word=hct_hex(add, 28, t0 - 16), add_dim=hct_hex(add, 8, t0 - 4),
        del_bg=hct_hex(rem, 14, t0 - 8), del_word=hct_hex(rem, 22, t0 - 16), del_dim=hct_hex(rem, 6, t0 - 4),
        rl_empty=neutral(-12, 14))


def monokai(name: str, p: dict, base: str = "dark") -> dict:
    o = {
        "autoAccept": p["purple"], "skill": p["purple"], "bashBorder": p["pink"],
        "claude": p["amber"], "claudeShimmer": p["amber_hi"],
        "claudeBlue_FOR_SYSTEM_SPINNER": p["cyan"], "claudeBlueShimmer_FOR_SYSTEM_SPINNER": p["cyan_hi"],
        "permission": p["cyan"], "permissionShimmer": p["cyan_hi"], "planMode": p["teal"], "ide": p["blue"],
        "promptBorder": p["border"], "promptBorderShimmer": p["border_hi"],
        "text": p["text"], "inverseText": p["inverse"],
        "inactive": p["inactive"], "inactiveShimmer": p["inactive_hi"], "subtle": p["subtle"],
        "suggestion": p["cyan"], "remember": p["cyan"], "background": p["teal"],
        "success": p["green"], "error": p["red"], "warning": p["yellow"], "merged": p["purple"],
        "warningShimmer": p["yellow_hi"],
        "diffAdded": p["add_bg"], "diffRemoved": p["del_bg"], "diffAddedDimmed": p["add_dim"],
        "diffRemovedDimmed": p["del_dim"], "diffAddedWord": p["add_word"], "diffRemovedWord": p["del_word"],
        "red_FOR_SUBAGENTS_ONLY": p["red"], "blue_FOR_SUBAGENTS_ONLY": p["blue"],
        "green_FOR_SUBAGENTS_ONLY": p["green"], "yellow_FOR_SUBAGENTS_ONLY": p["yellow"],
        "purple_FOR_SUBAGENTS_ONLY": p["purple"], "orange_FOR_SUBAGENTS_ONLY": p["amber"],
        "pink_FOR_SUBAGENTS_ONLY": p["pink_hi"], "cyan_FOR_SUBAGENTS_ONLY": p["cyan"],
        "professionalBlue": p["blue"], "chromeYellow": p["yellow"],
        "userMessageBackground": p["umsg"], "userMessageBackgroundHover": p["umsg_hover"],
        "composerSidebarBackground": p["side"], "selectionBg": p["select"],
        "bashMessageBackgroundColor": p["bash"], "memoryBackgroundColor": p["memory"],
        "rate_limit_fill": p["amber"], "rate_limit_empty": p["rl_empty"],
        "fastMode": p["fast"], "fastModeShimmer": p["fast_hi"], "effortUltra": p["purple"],
        "briefLabelYou": p["cyan"], "briefLabelClaude": p["amber"],
        "rainbow_red": p["red"], "rainbow_orange": p["amber"], "rainbow_yellow": p["yellow"],
        "rainbow_green": p["green"], "rainbow_blue": p["cyan"], "rainbow_indigo": p["blue"],
        "rainbow_violet": p["violet"], "rainbow_red_shimmer": p["red_hi"], "rainbow_orange_shimmer": p["amber_hi"],
        "rainbow_yellow_shimmer": p["yellow_hi"], "rainbow_green_shimmer": p["green_hi"],
        "rainbow_blue_shimmer": p["cyan_hi"], "rainbow_indigo_shimmer": "#B4C4FF", "rainbow_violet_shimmer": p["purple_hi"],
    }
    return {"name": name, "base": base, "overrides": o}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--terminal", required=True, help="generated terminal.json")
    ap.add_argument("--palette", required=True, help="generated palette.json")
    ap.add_argument("--mode", choices=["dark", "light"], default="dark")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--print", action="store_true", help="print the files instead of writing them")
    args = ap.parse_args()

    term = json.load(open(args.terminal))
    palette = json.load(open(args.palette))
    files = {
        "inir.json": dynamic("iNiR", False, term, palette, args.mode),
        "inir-soft.json": dynamic("iNiR Soft", True, term, palette, args.mode),
        "inir-monokai.json": monokai("iNiR Monokai", VIVID) if args.mode != "light"
            else monokai("iNiR Monokai", paper_backgrounds(PAPER, term), "light"),
        "inir-monokai-soft.json": monokai("iNiR Monokai Soft", MONOKAI_SOFT) if args.mode != "light"
            else monokai("iNiR Monokai Soft", paper_backgrounds(PAPER_SOFT, term), "light"),
    }
    out = pathlib.Path(args.out_dir)
    changed = []
    for fn, theme in files.items():
        text = json.dumps(theme, indent=2) + "\n"
        if args.print:
            print(fn, text)
            continue
        out.mkdir(parents=True, exist_ok=True)
        path = out / fn
        if path.exists() and path.read_text() == text:
            continue
        path.write_text(text)
        changed.append(fn)
    print("\n".join(files) if not changed else "changed: " + " ".join(changed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
