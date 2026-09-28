#!/usr/bin/env python3
"""Audit and prepare iNiR runtime translations.

English is canonical. This tool never translates text by itself. It prepares
contextual review batches and rejects structural, placeholder, markup, and
protected product-name regressions before writing a locale file.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TRANSLATIONS = ROOT / "translations"
L10N = TRANSLATIONS / "l10n"
SOURCE = TRANSLATIONS / "en_US.json"

LOCALE_RE = re.compile(r"^[A-Za-z]{2,3}_(?:[A-Za-z]{2,3}|\d{3})$")
MARKDOWN_URL_RE = re.compile(r"\]\([^\n)]*https?://[^\n)]*\)")
URL_RE = re.compile(r"https?://[^\s)]+")
TOKEN_RE = re.compile(r"%[1-9]\d?(?!\d)|%n|\{\d+\}|<[^<>]+>")
COMMENT_MARKER_RE = re.compile(r"/\*[^*]*\*/")
KEEP_MARKER = "/*keep*/"
WORD_RE = re.compile(r"[A-Za-z]{3,}")
SOURCE_TRANSLATION_PATTERNS = [
    re.compile(r'Translation\.tr\s*\(\s*(["\'])(((?!\1)[^\\]|\\.)*)(\1)\s*\)', re.MULTILINE | re.DOTALL),
    re.compile(r'Translation\.tr\s*\(\s*`([^`]*(?:\\.[^`]*)*?)`\s*\)', re.MULTILINE | re.DOTALL),
]
SOURCE_IGNORED_DIRS = {
    ".git", ".agents", ".agents-backups", ".cache", "node_modules",
    "build", "dist", "__pycache__",
}

# These keys are rendered in one-line gauges, OSDs, bar surfaces or similarly
# constrained controls. A translation can be linguistically correct and still
# be unusable there, so keep a visual-width budget independent of prose labels.
COMPACT_LABEL_LIMITS = {
    "CPU": 6,
    "RAM": 6,
    "GPU": 6,
    "CPU temp": 12,
    "GPU temp": 12,
    "Caps Lock on": 20,
    "Caps Lock off": 20,
    "Num Lock on": 20,
    "Num Lock off": 20,
    "Caps Lock: On": 20,
    "Num Lock: On": 20,
    "Media": 16,
    "No media": 20,
    "Hotspot": 18,
    "Task Manager": 24,
    "Agenda": 18,
    "No apps found": 20,
    "No devices found": 20,
    "No apps playing audio": 32,
    "Shuffle On": 20,
    "Shuffle Off": 20,
    "No coins configured": 22,
    "Launcher": 18,
    "Unmute": 18,
    "On AC": 16,
    "On AC · Full": 24,
}


def load_json(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in data.items()
    ):
        raise ValueError(f"{path} must contain a string-to-string JSON object")
    return data


def locale_path(locale: str) -> Path:
    if not LOCALE_RE.fullmatch(locale):
        raise ValueError(f"invalid locale name: {locale!r}")
    path = TRANSLATIONS / f"{locale}.json"
    if not path.is_file():
        raise ValueError(f"unknown locale: {locale}")
    return path


def available_locales() -> list[str]:
    return sorted(
        path.stem
        for path in TRANSLATIONS.glob("*.json")
        if path.name != SOURCE.name and LOCALE_RE.fullmatch(path.stem)
    )


def placeholders(text: str) -> list[str]:
    # URL percent escapes such as %20 and %2C are data, not Qt placeholders.
    # Remove complete Markdown destinations first because malformed historical
    # translations may contain literal spaces inside an otherwise encoded URL.
    without_urls = MARKDOWN_URL_RE.sub("]()", text)
    without_urls = URL_RE.sub("", without_urls)
    return sorted(TOKEN_RE.findall(without_urls))


def translation_placeholders_match(source: str, target: str) -> bool:
    """Compare Qt placeholders while allowing locale-native percent notation.

    English writes literal percentages as ``50%`` while locales such as Turkish
    conventionally write ``%50``. A raw ``%50`` token is otherwise
    indistinguishable from a Qt positional placeholder, so only suppress it
    when the canonical source proves that exact number is a literal percentage.
    """
    source_tokens = placeholders(source)
    target_without_urls = MARKDOWN_URL_RE.sub("]()", target)
    target_without_urls = URL_RE.sub("", target_without_urls)
    literal_percent_values = set(re.findall(r"(?<![%\d])(\d{1,3})%(?!\d)", source))
    for value in literal_percent_values:
        target_without_urls = re.sub(rf"%{re.escape(value)}(?!\d)", "", target_without_urls)
    target_tokens = sorted(TOKEN_RE.findall(target_without_urls))
    return source_tokens == target_tokens


def url_errors(source: str, target: str) -> list[str]:
    """Require literal URLs to survive localization byte-for-byte."""
    source_urls = URL_RE.findall(source)
    target_urls = URL_RE.findall(target)
    missing: list[str] = []
    for url in source_urls:
        if target_urls.count(url) < source_urls.count(url):
            missing.append(url)
    return sorted(set(missing))


def load_config() -> tuple[set[str], list[re.Pattern[str]]]:
    glossary = json.loads((L10N / "glossary.json").read_text(encoding="utf-8"))
    exact = {
        term for term in glossary.get("preserve", [])
        if isinstance(term, str) and term
    }
    patterns = [
        re.compile(pattern)
        for pattern in glossary.get("patterns", [])
        if isinstance(pattern, str) and pattern
    ]
    return exact, patterns


def term_pattern(term: str) -> re.Pattern[str]:
    return re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(term)}(?![A-Za-z0-9])"
    )


def protected_term_errors(
    source: str,
    target: str,
    protected_terms: set[str],
) -> list[str]:
    missing: list[str] = []
    for term in sorted(protected_terms, key=lambda value: (-len(value), value)):
        pattern = term_pattern(term)
        source_count = len(pattern.findall(source))
        target_count = len(pattern.findall(target))
        required_count = source_count if term in {"awww", "AWWW"} else min(source_count, 1)
        if required_count > target_count:
            missing.append(term)
    return missing


def marker_errors(target: str) -> list[str]:
    """Return translated/internal comment markers that would leak into the UI."""
    return sorted({
        marker
        for marker in COMMENT_MARKER_RE.findall(target)
        if marker != KEEP_MARKER
    })


def display_width(text: str) -> int:
    """Approximate terminal/UI columns without counting combining marks."""
    clean = text.removesuffix(KEEP_MARKER).strip()
    width = 0
    for char in clean:
        if unicodedata.combining(char):
            continue
        width += 2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1
    return width


def compact_label_errors(target: dict[str, str]) -> dict[str, dict[str, int]]:
    errors: dict[str, dict[str, int]] = {}
    for key, limit in COMPACT_LABEL_LIMITS.items():
        value = target.get(key)
        if value is None:
            continue
        width = display_width(value)
        if width > limit:
            errors[key] = {"width": width, "limit": limit}
    return errors


def semantic_term_errors(locale: str, source: str, target: str) -> list[str]:
    """Reject known technically-wrong literal translations for locale-specific UI terms."""
    # MaterialShape.ClamShell is a literal shape name, not the desktop-shell
    # concept covered by the technical `shell` glossary rule below.
    if source == "Clam Shell":
        return []
    source_lower = source.casefold()
    target_lower = target.casefold()
    errors: list[str] = []
    checks_by_locale = {
        "es_419": (
            (r"\bshell\b", ("concha", "carcasa", "caparazón"), "shell"),
            (r"\bdock\b", ("muelle",), "Dock"),
            (r"\bcommits?\b", ("confirmación", "confirmaciones"), "commit"),
            (r"\bcheckout\b", ("compra", "caja"), "checkout"),
        ),
        "de_DE": (
            (r"\bwallpapers?\b", ("tapete", "tapeten"), "wallpaper"),
            (r"\bdashboard\b", ("armaturenbrett",), "dashboard"),
            (r"\bhotspot\b", ("aktiver bereich",), "hotspot"),
            (r"\bagenda\b", ("tagesordnung",), "agenda"),
            (r"\bmatches?\b", ("streichholz", "streichhölzer"), "match"),
            (r"\brecorder\b", ("blockflöte",), "recorder"),
            (r"\bapplications?\b", ("bewerbung", "bewerbungen"), "application"),
            (r"\bshell\b", ("muschel", "schale"), "shell"),
            (r"\bpills?\b", ("pille", "pillen"), "pill"),
        ),
        "fr_FR": (
            (r"\bdock\b", ("quai",), "dock"),
            (r"\bshell\b", ("coque",), "shell"),
            (r"\bpills?\b", ("pilule", "pilules"), "pill"),
            (r"\bapply\b", ("postuler",), "apply"),
            (r"\bmarkdown\b", ("démarque",), "markdown"),
            (r"\bapplications?\b", ("candidature",), "application"),
            (r"\bmatches?\b", ("matchs",), "match"),
            (r"\bagenda\b", ("ordre du jour",), "agenda"),
        ),
        "pt_BR": (
            (r"\bdock\b", ("doca",), "dock"),
            (r"\bshell\b", ("concha", "casca"), "shell"),
            (r"\bpills?\b", ("pílula", "pílulas", "comprimido", "comprimidos"), "pill"),
            (r"\baccent\b", ("sotaque",), "accent"),
            (r"\bmarkdown\b", ("redução",), "markdown"),
            (r"\bmatches?\b", ("partidas",), "match"),
            (r"\bapplications?\b", ("candidatura",), "application"),
        ),
        "ru_RU": (
            (r"\bbars?\b", ("бары",), "bar"),
            (r"\bshell\b", ("ракушка", "корпус"), "shell"),
            (r"\bpills?\b", ("таблетка", "таблетки"), "pill"),
            (r"\bscroll\b", ("свиток",), "scroll"),
            (r"\bmatches?\b", ("спички",), "match"),
            (r"\bmedia\b", ("сми",), "media"),
            (r"\bagenda\b", ("повестка дня",), "agenda"),
        ),
        "tr_TR": (
            (r"\bpills?\b", ("hap", "haplar"), "pill"),
            (r"\bcommits?\b", ("taahhüt", "taahhütler"), "commit"),
        ),
        "ar_SA": (
            (r"\bwallpapers?\b", ("ورق جدران",), "wallpaper"),
            (r"\bdashboard\b", ("لوحة القيادة",), "dashboard"),
            (r"\bdock\b", ("قفص الاتهام", "الرصيف"), "dock"),
            (r"\bshell\b", ("الصدفة", "القشرة"), "shell"),
            (r"\bpills?\b", ("حبوب", "الحبة"), "pill"),
            (r"\bcommits?\b", ("الالتزام",), "commit"),
            (r"\bmatches?\b", ("مباريات",), "match"),
            (r"\bvolume\b", ("الحجم",), "volume"),
            (r"\bmedia\b", ("وسائل الإعلام",), "media"),
        ),
        "he_HE": (
            (r"\bdock\b", ("מזח",), "dock"),
            (r"\bpills?\b", ("גלולה", "גלולות"), "pill"),
            (r"\bcommits?\b", ("התחייבות",), "commit"),
        ),
        "hi_IN": (
            (r"\bpills?\b", ("गोली", "गोलियाँ"), "pill"),
            (r"\bcommits?\b", ("प्रतिबद्धता",), "commit"),
            (r"\bmatches?\b", ("मैच",), "match"),
            (r"\bapplications?\b", ("आवेदन",), "application"),
            (r"\bvolume\b", ("आयतन",), "volume"),
            (r"\bdisabled?\b", ("विकलांग",), "disabled"),
            (r"\baccent\b", ("उच्चारण",), "accent"),
        ),
        "it_IT": (
            (r"\bpills?\b", ("pillola", "pillole"), "pill"),
            (r"\bapplications?\b", ("domanda",), "application"),
            (r"\bhotspot\b", ("area sensibile",), "hotspot"),
        ),
        "ja_JP": (
            (r"\bpills?\b", ("錠剤", "丸薬"), "pill"),
            (r"\bapply\b", ("申し込む",), "apply"),
            (r"\bwindow(?:s)?\b", ("窓",), "window"),
            (r"\bdisabled?\b", ("障害者",), "disabled"),
        ),
        "ko_KR": (
            (r"\bpills?\b", ("알약",), "pill"),
            (r"\bwindow(?:s)?\b", ("창문",), "window"),
            (r"\bmatches?\b", ("성냥",), "match"),
            (r"\bdisabled?\b", ("장애인",), "disabled"),
        ),
        "uk_UA": (
            (r"\bdashboard\b", ("приладова панель",), "dashboard"),
            (r"\bbars?\b", ("бари",), "bar"),
            (r"\bpills?\b", ("таблетка", "таблетки", "пігулка", "пігулки"), "pill"),
            (r"\bscroll\b", ("сувій",), "scroll"),
            (r"\bmatches?\b", ("сірники",), "match"),
            (r"\bagenda\b", ("порядок денний",), "agenda"),
        ),
        "vi_VN": (
            (r"\bbars?\b", ("quầy bar",), "bar"),
            (r"\bdock\b", ("bến tàu",), "dock"),
            (r"\bshell\b", ("vỏ",), "shell"),
            (r"\bpills?\b", ("thuốc viên", "viên thuốc"), "pill"),
            (r"\bcommits?\b", ("cam kết",), "commit"),
            (r"\bmatches?\b", ("trận đấu",), "match"),
            (r"\baccent\b", ("giọng",), "accent"),
        ),
        "zh_CN": (
            (r"\bbars?\b", ("酒吧",), "bar"),
            (r"\bdock\b", ("码头", "坞站"), "dock"),
            (r"\bshell\b", ("外壳",), "shell"),
            (r"\bpills?\b", ("药丸",), "pill"),
            (r"\bcommits?\b", ("承诺",), "commit"),
            (r"\bmatches?\b", ("比赛",), "match"),
            (r"\baccent\b", ("口音",), "accent"),
            (r"\bapplications?\b", ("申请",), "application"),
            (r"\bdisabled?\b", ("残疾人",), "disabled"),
        ),
    }
    checks = checks_by_locale.get(locale, ())
    for source_pattern, forbidden, label in checks:
        if re.search(source_pattern, source_lower) and any(word in target_lower for word in forbidden):
            errors.append(label)
    return errors


def should_preserve(
    text: str,
    exact: set[str],
    patterns: list[re.Pattern[str]],
) -> bool:
    if text in exact:
        return True
    return any(pattern.search(text) for pattern in patterns)


def suspicious(
    source: str,
    target: str,
    exact: set[str],
    patterns: list[re.Pattern[str]],
) -> bool:
    if not target.strip():
        return True
    if source != target:
        return False
    if should_preserve(source, exact, patterns):
        return False
    return bool(WORD_RE.search(source))


def _decode_source_literal(text: str) -> str:
    try:
        if "\\u" in text or "\\x" in text:
            return bytes(text, "utf-8").decode("unicode_escape").strip()
    except UnicodeDecodeError:
        pass
    return (
        text.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\r", "\r")
        .replace('\\"', '"')
        .replace("\\'", "'")
        .replace("\\f", "\f")
        .replace("\\b", "\b")
        .replace("\\\\", "\\")
        .strip()
    )


def source_translation_keys() -> set[str]:
    keys: set[str] = set()
    for suffix in ("*.qml", "*.js"):
        for path in ROOT.rglob(suffix):
            relative = path.relative_to(ROOT)
            if any(part in SOURCE_IGNORED_DIRS for part in relative.parts[:-1]):
                continue
            try:
                content = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for pattern in SOURCE_TRANSLATION_PATTERNS:
                for match in pattern.findall(content):
                    if isinstance(match, tuple):
                        text = match[1] if len(match) >= 3 else (match[0] if match else "")
                    else:
                        text = match
                    decoded = _decode_source_literal(text)
                    if decoded:
                        keys.add(decoded)
    return keys


def build_source_report() -> dict[str, Any]:
    catalog = load_json(SOURCE)
    live = source_translation_keys()
    catalog_keys = set(catalog)
    return {
        "sourceLiteralKeys": len(live),
        "catalogKeys": len(catalog_keys),
        "missingFromCatalog": sorted(live - catalog_keys),
        # Catalog-only entries can be legitimate dynamic/runtime keys. Report them
        # for maintenance, but only missing live literals fail this coverage gate.
        "catalogOnly": sorted(catalog_keys - live),
    }


def audit_source(as_json: bool) -> int:
    report = build_source_report()
    if as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"source literals: {report['sourceLiteralKeys']}")
        print(f"canonical keys: {report['catalogKeys']}")
        print(f"missing from canonical: {len(report['missingFromCatalog'])}")
        print(f"catalog-only/dynamic candidates: {len(report['catalogOnly'])}")
        for key in report["missingFromCatalog"][:20]:
            print(f"  missing: {key}")
        if len(report["missingFromCatalog"]) > 20:
            print(f"  ... and {len(report['missingFromCatalog']) - 20} more")
    return 0 if not report["missingFromCatalog"] else 1


def source_locations(text: str, limit: int = 5) -> list[str]:
    needle_variants = {text, text.replace("\n", "\\n")}
    found: list[str] = []
    for base in (ROOT / "modules", ROOT / "services"):
        if not base.exists():
            continue
        for path in base.rglob("*.qml"):
            try:
                content = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            if not any(needle in content for needle in needle_variants):
                continue
            found.append(str(path.relative_to(ROOT)))
            if len(found) >= limit:
                return found
    return found


def build_report(locale: str) -> dict[str, Any]:
    source = load_json(SOURCE)
    target = load_json(locale_path(locale))
    exact, patterns = load_config()
    common_keys = source.keys() & target.keys()

    placeholder_errors = [
        key for key in common_keys
        if not translation_placeholders_match(source[key], target[key])
    ]
    invalid_urls = {
        key: errors
        for key in common_keys
        if (errors := url_errors(source[key], target[key]))
    }
    internal_marker_errors = {
        key: errors
        for key in common_keys
        if (errors := marker_errors(target[key]))
    }
    protected_errors = {
        key: missing
        for key in common_keys
        if (missing := protected_term_errors(source[key], target[key], exact))
    }
    semantic_errors = {
        key: errors
        for key in common_keys
        if (errors := semantic_term_errors(locale, source[key], target[key]))
    }
    compact_errors = compact_label_errors(target)
    suspect = [
        key for key in common_keys
        if suspicious(source[key], target[key], exact, patterns)
    ]

    return {
        "locale": locale,
        "keys": len(target),
        "missing": sorted(set(source) - set(target)),
        "extra": sorted(set(target) - set(source)),
        "placeholderErrors": sorted(placeholder_errors),
        "urlErrors": dict(sorted(invalid_urls.items())),
        "markerErrors": dict(sorted(internal_marker_errors.items())),
        "protectedTermErrors": dict(sorted(protected_errors.items())),
        "semanticTermErrors": dict(sorted(semantic_errors.items())),
        "compactLabelErrors": dict(sorted(compact_errors.items())),
        "suspectedUntranslated": sorted(suspect),
    }


def report_is_structurally_valid(report: dict[str, Any]) -> bool:
    return not (
        report["missing"]
        or report["extra"]
        or report["placeholderErrors"]
        or report["urlErrors"]
        or report["markerErrors"]
        or report["protectedTermErrors"]
        or report["semanticTermErrors"]
        or report["compactLabelErrors"]
    )


def print_report(report: dict[str, Any]) -> None:
    print(f"{report['locale']}: {report['keys']} keys")
    print(f"  missing: {len(report['missing'])}")
    print(f"  extra: {len(report['extra'])}")
    print(f"  placeholder errors: {len(report['placeholderErrors'])}")
    print(f"  URL errors: {len(report['urlErrors'])}")
    print(f"  internal marker errors: {len(report['markerErrors'])}")
    print(f"  protected term errors: {len(report['protectedTermErrors'])}")
    print(f"  semantic term errors: {len(report['semanticTermErrors'])}")
    print(f"  compact label errors: {len(report['compactLabelErrors'])}")
    print(f"  suspected untranslated: {len(report['suspectedUntranslated'])}")


def audit(locale: str, as_json: bool, strict_terms: bool) -> int:
    report = build_report(locale)
    if as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_report(report)
    valid = report_is_structurally_valid(report)
    if strict_terms and report["protectedTermErrors"]:
        valid = False
    return 0 if valid else 1


def audit_all(as_json: bool) -> int:
    reports = [build_report(locale) for locale in available_locales()]
    if as_json:
        print(json.dumps(reports, ensure_ascii=False, indent=2))
    else:
        for report in reports:
            print_report(report)
    return 0 if all(report_is_structurally_valid(report) for report in reports) else 1


def audit_guides(as_json: bool) -> int:
    guides = json.loads((L10N / "locale-guides.json").read_text(encoding="utf-8"))
    if not isinstance(guides, dict):
        raise ValueError("locale-guides.json must contain an object")
    locales = set(available_locales())
    guide_locales = {key for key, value in guides.items() if isinstance(key, str) and isinstance(value, str) and value.strip()}
    report = {
        "missingGuides": sorted(locales - guide_locales),
        "staleGuides": sorted(guide_locales - locales),
    }
    if as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"missing locale guides: {len(report['missingGuides'])}")
        for locale in report["missingGuides"]:
            print(f"  missing: {locale}")
        print(f"stale locale guides: {len(report['staleGuides'])}")
        for locale in report["staleGuides"]:
            print(f"  stale: {locale}")
    return 0 if not report["missingGuides"] and not report["staleGuides"] else 1


def extract(locale: str, output: Path, limit: int) -> int:
    source = load_json(SOURCE)
    target = load_json(locale_path(locale))
    guides = json.loads((L10N / "locale-guides.json").read_text(encoding="utf-8"))
    exact, patterns = load_config()

    keys = [
        key for key in source.keys() & target.keys()
        if suspicious(source[key], target[key], exact, patterns)
    ]
    keys.sort(key=lambda key: (-len(source[key]), key.casefold()))
    if limit > 0:
        keys = keys[:limit]

    batch = {
        "locale": locale,
        "guide": guides.get(locale, "Natural concise desktop UI language."),
        "instructions": [
            "Translate only the value in translated.",
            "Keep key and source unchanged.",
            "Preserve placeholders, commands, paths, markup and product names.",
            "Never translate internal /*keep*/ markers; omit the marker from translated prose or keep it exactly as /*keep*/.",
            "Use concise natural desktop UI language, not literal machine translation.",
            "When compactLimit is set, keep the translated label within that display-width budget.",
        ],
        "entries": [
            {
                "key": key,
                "source": source[key],
                "current": target[key],
                "translated": "",
                "compactLimit": COMPACT_LABEL_LIMITS.get(key),
                "locations": source_locations(source[key]),
            }
            for key in keys
        ],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(batch, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(keys)} entries to {output}")
    return 0


def apply_batch(batch_path: Path) -> int:
    batch = json.loads(batch_path.read_text(encoding="utf-8"))
    locale = batch.get("locale")
    if not isinstance(locale, str):
        raise ValueError("batch locale is missing")

    target_path = locale_path(locale)
    source_catalog = load_json(SOURCE)
    target = load_json(target_path)
    protected_terms, _ = load_config()
    entries = batch.get("entries")
    if not isinstance(entries, list):
        raise ValueError("batch entries must be a list")

    updates: dict[str, str] = {}
    seen: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("batch entries must be objects")
        key = entry.get("key")
        source = entry.get("source")
        translated = entry.get("translated")
        if not isinstance(key, str) or key not in source_catalog:
            raise ValueError(f"unknown translation key: {key!r}")
        if key in seen:
            raise ValueError(f"duplicate translation key: {key!r}")
        seen.add(key)
        if source != source_catalog[key]:
            raise ValueError(f"source changed for {key!r}; regenerate the batch")
        if not isinstance(translated, str) or not translated.strip():
            continue
        if not translation_placeholders_match(source, translated):
            raise ValueError(f"placeholder or markup mismatch for {key!r}")
        invalid_urls = url_errors(source, translated)
        if invalid_urls:
            raise ValueError(
                f"URL mismatch for {key!r}: {', '.join(invalid_urls)}"
            )
        bad_markers = marker_errors(translated)
        if bad_markers:
            raise ValueError(
                f"internal marker mismatch for {key!r}: {', '.join(bad_markers)}"
            )
        missing_terms = protected_term_errors(source, translated, protected_terms)
        if missing_terms:
            raise ValueError(
                f"protected term mismatch for {key!r}: {', '.join(missing_terms)}"
            )
        semantic_errors = semantic_term_errors(locale, source, translated)
        if semantic_errors:
            raise ValueError(
                f"semantic term mismatch for {key!r}: {', '.join(semantic_errors)}"
            )
        compact_limit = COMPACT_LABEL_LIMITS.get(key)
        if compact_limit is not None and display_width(translated) > compact_limit:
            raise ValueError(
                f"compact label too wide for {key!r}: "
                f"{display_width(translated)} columns (limit {compact_limit})"
            )
        updates[key] = translated

    if not updates:
        print("No reviewed translations to apply")
        return 0

    target.update(updates)
    target_path.write_text(
        json.dumps(target, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Applied {len(updates)} translations to {target_path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    audit_parser = sub.add_parser(
        "audit",
        help="report structural, placeholder, product-name and untranslated-string problems",
    )
    audit_parser.add_argument("locale")
    audit_parser.add_argument("--json", action="store_true", dest="as_json")
    audit_parser.add_argument("--strict-terms", action="store_true")

    audit_all_parser = sub.add_parser(
        "audit-all",
        help="validate every runtime locale against English",
    )
    audit_all_parser.add_argument("--json", action="store_true", dest="as_json")

    audit_source_parser = sub.add_parser(
        "audit-source",
        help="validate literal Translation.tr source coverage in the canonical English catalog",
    )
    audit_source_parser.add_argument("--json", action="store_true", dest="as_json")

    audit_guides_parser = sub.add_parser(
        "audit-guides",
        help="validate that every supported runtime locale has one review guide",
    )
    audit_guides_parser.add_argument("--json", action="store_true", dest="as_json")

    extract_parser = sub.add_parser("extract", help="create a contextual review batch")
    extract_parser.add_argument("locale")
    extract_parser.add_argument("output", type=Path)
    extract_parser.add_argument("--limit", type=int, default=200)

    apply_parser = sub.add_parser("apply", help="validate and apply a reviewed batch")
    apply_parser.add_argument("batch", type=Path)

    args = parser.parse_args()
    if args.command == "audit":
        return audit(args.locale, args.as_json, args.strict_terms)
    if args.command == "audit-all":
        return audit_all(args.as_json)
    if args.command == "audit-source":
        return audit_source(args.as_json)
    if args.command == "audit-guides":
        return audit_guides(args.as_json)
    if args.command == "extract":
        return extract(args.locale, args.output, args.limit)
    if args.command == "apply":
        return apply_batch(args.batch)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"l10n: {exc}", file=sys.stderr)
        raise SystemExit(2)
