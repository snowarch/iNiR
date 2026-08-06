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
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TRANSLATIONS = ROOT / "translations"
L10N = TRANSLATIONS / "l10n"
SOURCE = TRANSLATIONS / "en_US.json"

LOCALE_RE = re.compile(r"^[A-Za-z]{2,3}_[A-Za-z]{2,3}$")
MARKDOWN_URL_RE = re.compile(r"\]\([^\n)]*https?://[^\n)]*\)")
URL_RE = re.compile(r"https?://[^\s)]+")
TOKEN_RE = re.compile(r"%[1-9]\d?|%n|\{\d+\}|<[^<>]+>")
WORD_RE = re.compile(r"[A-Za-z]{3,}")


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
        if pattern.search(source) and not pattern.search(target):
            missing.append(term)
    return missing


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
        if placeholders(source[key]) != placeholders(target[key])
    ]
    protected_errors = {
        key: missing
        for key in common_keys
        if (missing := protected_term_errors(source[key], target[key], exact))
    }
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
        "protectedTermErrors": dict(sorted(protected_errors.items())),
        "suspectedUntranslated": sorted(suspect),
    }


def report_is_structurally_valid(report: dict[str, Any]) -> bool:
    return not (
        report["missing"]
        or report["extra"]
        or report["placeholderErrors"]
    )


def print_report(report: dict[str, Any]) -> None:
    print(f"{report['locale']}: {report['keys']} keys")
    print(f"  missing: {len(report['missing'])}")
    print(f"  extra: {len(report['extra'])}")
    print(f"  placeholder errors: {len(report['placeholderErrors'])}")
    print(f"  protected term warnings: {len(report['protectedTermErrors'])}")
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
            "Use concise natural desktop UI language, not literal machine translation.",
        ],
        "entries": [
            {
                "key": key,
                "source": source[key],
                "current": target[key],
                "translated": "",
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
        if placeholders(source) != placeholders(translated):
            raise ValueError(f"placeholder or markup mismatch for {key!r}")
        missing_terms = protected_term_errors(source, translated, protected_terms)
        if missing_terms:
            raise ValueError(
                f"protected term mismatch for {key!r}: {', '.join(missing_terms)}"
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
