#!/usr/bin/env python3
"""Local Yomitan-compatible Japanese dictionary index for iNiR.

The runtime deliberately imports user-provided dictionary ZIPs instead of
shipping a network-bound dictionary service. It accepts the stable Yomitan v3
term, term-meta, and kanji bank shapes and stores the useful fields in SQLite.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import zipfile
import urllib.request
import urllib.error
from pathlib import Path
from typing import Any, Iterable

BANK_PATTERNS = {
    "term": re.compile(r"(?:^|/)term_bank_(\d+)\.json$"),
    "term_meta": re.compile(r"(?:^|/)term_meta_bank_(\d+)\.json$"),
    "kanji": re.compile(r"(?:^|/)kanji_bank_(\d+)\.json$"),
}


def data_home() -> Path:
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return base / "inir"


def default_db_path() -> Path:
    return data_home() / "japanese-dictionaries.sqlite3"


def emit(payload: Any, *, pretty: bool = False) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2 if pretty else None)
    sys.stdout.write("\n")


def connect(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS dictionaries (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL UNIQUE,
            revision TEXT NOT NULL DEFAULT '',
            format INTEGER,
            source_path TEXT NOT NULL DEFAULT '',
            imported_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS terms (
            id INTEGER PRIMARY KEY,
            dictionary_id INTEGER NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
            expression TEXT NOT NULL,
            reading TEXT NOT NULL DEFAULT '',
            definition_tags TEXT NOT NULL DEFAULT '',
            rules TEXT NOT NULL DEFAULT '',
            score REAL NOT NULL DEFAULT 0,
            glossary_json TEXT NOT NULL,
            sequence INTEGER NOT NULL DEFAULT -1,
            term_tags TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS terms_expression_idx ON terms(expression);
        CREATE INDEX IF NOT EXISTS terms_reading_idx ON terms(reading);
        CREATE TABLE IF NOT EXISTS term_meta (
            id INTEGER PRIMARY KEY,
            dictionary_id INTEGER NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
            expression TEXT NOT NULL,
            meta_type TEXT NOT NULL,
            data_json TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS term_meta_expression_idx ON term_meta(expression, meta_type);
        CREATE TABLE IF NOT EXISTS kanji (
            id INTEGER PRIMARY KEY,
            dictionary_id INTEGER NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
            character TEXT NOT NULL,
            onyomi TEXT NOT NULL DEFAULT '',
            kunyomi TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '',
            meanings_json TEXT NOT NULL,
            stats_json TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS kanji_character_idx ON kanji(character);
        """
    )
    return db


def _json_from_zip(archive: zipfile.ZipFile, name: str) -> Any:
    try:
        raw = archive.read(name)
    except KeyError as exc:
        raise ValueError(f"dictionary archive is missing {name}") from exc
    try:
        return json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid JSON in {name}: {exc}") from exc


def _find_index_name(archive: zipfile.ZipFile) -> str:
    candidates = [n for n in archive.namelist() if n == "index.json" or n.endswith("/index.json")]
    if not candidates:
        raise ValueError("not a Yomitan dictionary: index.json is missing")
    candidates.sort(key=lambda n: (n.count("/"), len(n)))
    return candidates[0]


def _bank_names(archive: zipfile.ZipFile, kind: str) -> list[str]:
    pattern = BANK_PATTERNS[kind]
    matched: list[tuple[int, str]] = []
    for name in archive.namelist():
        match = pattern.search(name)
        if match:
            matched.append((int(match.group(1)), name))
    return [name for _, name in sorted(matched)]


def _require_list(entry: Any, size: int, source: str) -> list[Any]:
    if not isinstance(entry, list) or len(entry) < size:
        raise ValueError(f"malformed entry in {source}")
    return entry


def import_dictionary(db: sqlite3.Connection, archive_path: Path) -> dict[str, Any]:
    if not archive_path.is_file():
        raise ValueError(f"dictionary archive does not exist: {archive_path}")

    with zipfile.ZipFile(archive_path) as archive:
        index_name = _find_index_name(archive)
        index = _json_from_zip(archive, index_name)
        if not isinstance(index, dict):
            raise ValueError("dictionary index must be a JSON object")
        title = str(index.get("title") or "").strip()
        if not title:
            raise ValueError("dictionary index has no title")
        revision = str(index.get("revision") or "")
        fmt = index.get("format", index.get("version"))
        if fmt is not None and not isinstance(fmt, int):
            fmt = None

        term_names = _bank_names(archive, "term")
        meta_names = _bank_names(archive, "term_meta")
        kanji_names = _bank_names(archive, "kanji")
        if not term_names and not kanji_names and not meta_names:
            raise ValueError("dictionary archive contains no supported Yomitan banks")

        imported_at = dt.datetime.now(dt.timezone.utc).isoformat()
        term_count = meta_count = kanji_count = 0

        with db:
            old = db.execute("SELECT id FROM dictionaries WHERE title = ?", (title,)).fetchone()
            if old:
                db.execute("DELETE FROM dictionaries WHERE id = ?", (old["id"],))
            cur = db.execute(
                "INSERT INTO dictionaries(title, revision, format, source_path, imported_at) VALUES (?, ?, ?, ?, ?)",
                (title, revision, fmt, str(archive_path.resolve()), imported_at),
            )
            dictionary_id = int(cur.lastrowid)

            for name in term_names:
                bank = _json_from_zip(archive, name)
                if not isinstance(bank, list):
                    raise ValueError(f"{name} is not a term bank array")
                rows = []
                for raw in bank:
                    row = _require_list(raw, 8, name)
                    expression, reading, def_tags, rules, score, glossary, sequence, term_tags = row[:8]
                    if not isinstance(expression, str) or not isinstance(reading, str) or not isinstance(glossary, list):
                        raise ValueError(f"malformed term entry in {name}")
                    rows.append(
                        (
                            dictionary_id,
                            expression,
                            reading,
                            str(def_tags or ""),
                            str(rules or ""),
                            float(score or 0),
                            json.dumps(glossary, ensure_ascii=False, separators=(",", ":")),
                            int(sequence) if isinstance(sequence, int) else -1,
                            str(term_tags or ""),
                        )
                    )
                db.executemany(
                    """INSERT INTO terms(
                        dictionary_id, expression, reading, definition_tags, rules,
                        score, glossary_json, sequence, term_tags
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    rows,
                )
                term_count += len(rows)

            for name in meta_names:
                bank = _json_from_zip(archive, name)
                if not isinstance(bank, list):
                    raise ValueError(f"{name} is not a term metadata bank array")
                rows = []
                for raw in bank:
                    row = _require_list(raw, 3, name)
                    expression, meta_type, data = row[:3]
                    if not isinstance(expression, str) or meta_type not in {"freq", "pitch", "ipa"}:
                        continue
                    rows.append(
                        (
                            dictionary_id,
                            expression,
                            meta_type,
                            json.dumps(data, ensure_ascii=False, separators=(",", ":")),
                        )
                    )
                db.executemany(
                    "INSERT INTO term_meta(dictionary_id, expression, meta_type, data_json) VALUES (?, ?, ?, ?)",
                    rows,
                )
                meta_count += len(rows)

            for name in kanji_names:
                bank = _json_from_zip(archive, name)
                if not isinstance(bank, list):
                    raise ValueError(f"{name} is not a kanji bank array")
                rows = []
                for raw in bank:
                    row = _require_list(raw, 6, name)
                    character, onyomi, kunyomi, tags, meanings, stats = row[:6]
                    if not isinstance(character, str) or not isinstance(meanings, list) or not isinstance(stats, dict):
                        raise ValueError(f"malformed kanji entry in {name}")
                    rows.append(
                        (
                            dictionary_id,
                            character,
                            str(onyomi or ""),
                            str(kunyomi or ""),
                            str(tags or ""),
                            json.dumps(meanings, ensure_ascii=False, separators=(",", ":")),
                            json.dumps(stats, ensure_ascii=False, separators=(",", ":")),
                        )
                    )
                db.executemany(
                    """INSERT INTO kanji(
                        dictionary_id, character, onyomi, kunyomi, tags, meanings_json, stats_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    rows,
                )
                kanji_count += len(rows)

    return {
        "ok": True,
        "title": title,
        "revision": revision,
        "terms": term_count,
        "metadata": meta_count,
        "kanji": kanji_count,
    }



KANA_ROMAJI = {
    "あ":"a","い":"i","う":"u","え":"e","お":"o","か":"ka","き":"ki","く":"ku","け":"ke","こ":"ko",
    "さ":"sa","し":"shi","す":"su","せ":"se","そ":"so","た":"ta","ち":"chi","つ":"tsu","て":"te","と":"to",
    "な":"na","に":"ni","ぬ":"nu","ね":"ne","の":"no","は":"ha","ひ":"hi","ふ":"fu","へ":"he","ほ":"ho",
    "ま":"ma","み":"mi","む":"mu","め":"me","も":"mo","や":"ya","ゆ":"yu","よ":"yo",
    "ら":"ra","り":"ri","る":"ru","れ":"re","ろ":"ro","わ":"wa","を":"o","ん":"n",
    "が":"ga","ぎ":"gi","ぐ":"gu","げ":"ge","ご":"go","ざ":"za","じ":"ji","ず":"zu","ぜ":"ze","ぞ":"zo",
    "だ":"da","ぢ":"ji","づ":"zu","で":"de","ど":"do","ば":"ba","び":"bi","ぶ":"bu","べ":"be","ぼ":"bo",
    "ぱ":"pa","ぴ":"pi","ぷ":"pu","ぺ":"pe","ぽ":"po",
    "きゃ":"kya","きゅ":"kyu","きょ":"kyo","しゃ":"sha","しゅ":"shu","しょ":"sho","ちゃ":"cha","ちゅ":"chu","ちょ":"cho",
    "にゃ":"nya","にゅ":"nyu","にょ":"nyo","ひゃ":"hya","ひゅ":"hyu","ひょ":"hyo","みゃ":"mya","みゅ":"myu","みょ":"myo",
    "りゃ":"rya","りゅ":"ryu","りょ":"ryo","ぎゃ":"gya","ぎゅ":"gyu","ぎょ":"gyo","じゃ":"ja","じゅ":"ju","じょ":"jo",
    "びゃ":"bya","びゅ":"byu","びょ":"byo","ぴゃ":"pya","ぴゅ":"pyu","ぴょ":"pyo",
}

def _kata_to_hira(text: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)

def romanize_kana(text: str) -> str:
    text = _kata_to_hira(text)
    out: list[str] = []
    geminate = False
    i = 0
    while i < len(text):
        c = text[i]
        if c == "っ":
            geminate = True
            i += 1
            continue
        pair = text[i:i+2]
        roma = KANA_ROMAJI.get(pair)
        if roma:
            i += 2
        else:
            roma = KANA_ROMAJI.get(c, c)
            i += 1
        if geminate and roma and roma[0].isalpha():
            roma = roma[0] + roma
            geminate = False
        out.append(roma)
    return "".join(out)

# Compact deinflector for the forms OCR most commonly sees. Candidate rules are
# validated against Yomitan term rule tags, so ambiguous transforms do not win
# unless the dictionary confirms the resulting lexical class.
DEINFLECT_SUFFIX_RULES = [
    ("ませんでした", "る", "polite negative past", {"v1"}), ("ません", "る", "polite negative", {"v1"}),
    ("ました", "る", "polite past", {"v1"}), ("ます", "る", "polite", {"v1"}),
    ("なかった", "る", "negative past", {"v1"}), ("ない", "る", "negative", {"v1"}),
    ("られた", "る", "potential/passive past", {"v1"}), ("られる", "る", "potential/passive", {"v1"}),
    ("させた", "る", "causative past", {"v1"}), ("させる", "る", "causative", {"v1"}),
    ("て", "る", "te-form", {"v1"}), ("た", "る", "past", {"v1"}),
    ("くなかった", "い", "negative past", {"adj-i"}), ("くない", "い", "negative", {"adj-i"}),
    ("かった", "い", "past", {"adj-i"}),
]

_GODAN_MASU = {"いました":"う","きました":"く","ぎました":"ぐ","しました":"す","ちました":"つ","にました":"ぬ","びました":"ぶ","みました":"む","りました":"る",
               "います":"う","きます":"く","ぎます":"ぐ","します":"す","ちます":"つ","にます":"ぬ","びます":"ぶ","みます":"む","ります":"る"}
_GODAN_NEG = {"わなかった":"う","かなかった":"く","がなかった":"ぐ","さなかった":"す","たなかった":"つ","ななかった":"ぬ","ばなかった":"ぶ","まなかった":"む","らなかった":"る",
              "わない":"う","かない":"く","がない":"ぐ","さない":"す","たない":"つ","なない":"ぬ","ばない":"ぶ","まない":"む","らない":"る"}
_GODAN_PAST = {"った":["う","つ","る"],"いた":["く"],"いだ":["ぐ"],"した":["す"],"んだ":["ぬ","ぶ","む"],
               "って":["う","つ","る"],"いて":["く"],"いで":["ぐ"],"して":["す"],"んで":["ぬ","ぶ","む"]}

def _term_accepts(term: dict[str, Any], expected: set[str]) -> bool:
    if not expected:
        return True
    rules = set(term.get("rules") or [])
    return bool(rules & expected)

def deinflection_candidates(text: str) -> list[tuple[str, str, set[str]]]:
    seen = {text}
    out: list[tuple[str, str, set[str]]] = [(text, "", set())]
    def add(base: str, reason: str, expected: set[str]):
        if base and base not in seen:
            seen.add(base); out.append((base, reason, expected))
    for old, new, reason, expected in DEINFLECT_SUFFIX_RULES:
        if text.endswith(old) and len(text) > len(old): add(text[:-len(old)] + new, reason, expected)
    for table, reason in ((_GODAN_MASU, "polite"), (_GODAN_NEG, "negative")):
        for old, new in table.items():
            if text.endswith(old) and len(text) > len(old): add(text[:-len(old)] + new, reason, {"v5"})
    for old, endings in _GODAN_PAST.items():
        if text.endswith(old) and len(text) > len(old):
            for ending in endings: add(text[:-len(old)] + ending, "past/te-form", {"v5"})
    irregular = {"しました":"する","します":"する","して":"する","した":"する","しない":"する","しなかった":"する",
                 "きました":"来る","きます":"来る","きた":"来る","きて":"来る","こない":"来る","来ました":"来る","来ます":"来る","来た":"来る","来て":"来る","来ない":"来る"}
    if text in irregular: add(irregular[text], "irregular", set())
    return out

def _smart_surface_match(db: sqlite3.Connection, surface: str, limit: int) -> tuple[str, str, list[dict[str, Any]]] | None:
    for base, reason, expected in deinflection_candidates(surface):
        # OCR frequently yields kana while the dictionary headword is kanji
        # (どこ -> 何処). Reading lookup is therefore required here. Re-sort by
        # dictionary priority so a high-priority reading can beat an unrelated
        # low-priority kana spelling (いくら: 幾ら "how much" vs salmon roe).
        terms = term_rows(db, base, limit, reading_too=True)
        accepted = [t for t in terms if _term_accepts(t, expected)]
        accepted.sort(key=lambda t: float(t.get("score") or 0), reverse=True)
        if accepted:
            return base, reason, accepted
    return None


def smart_scan(db: sqlite3.Connection, text: str, limit: int, max_chars: int) -> dict[str, Any]:
    # OCR often includes bullets, romaji and an English translation around the
    # Japanese phrase. Scan Japanese runs rather than only shrinking a prefix
    # from byte/character zero; otherwise a valid one-kana entry such as ま can
    # win simply because noise precedes the actual phrase (e.g. またね).
    # Tesseract can insert spaces between Japanese glyphs (ま た ね). Japanese
    # prose normally has no word-separating spaces, so collapse horizontal
    # whitespace only when both neighbours are Japanese. Keep newlines intact
    # so separate OCR lines remain separate candidate runs.
    jp_char = r"ぁ-ゖァ-ヺー一-龯々〆ヵヶ"
    normalized = re.sub(rf"(?<=[{jp_char}])[ \t]+(?=[{jp_char}])", "", text)
    japanese_runs = re.findall(rf"[{jp_char}]+", normalized)
    if not japanese_runs:
        fallback = re.sub(r"^[\s\u3000、。！？!?「」『』（）()【】]+", "", text.strip())
        japanese_runs = [fallback] if fallback else []

    best: tuple[tuple[int, int, float, int, int], dict[str, Any]] | None = None
    for run_index, raw_run in enumerate(japanese_runs):
        run = raw_run[:max_chars]
        for start in range(len(run)):
            tail = run[start:]
            for size in range(len(tail), 0, -1):
                surface = tail[:size]
                match = _smart_surface_match(db, surface, limit)
                if match is None:
                    continue
                base, reason, accepted = match
                top_score = max(float(term.get("score") or 0) for term in accepted)
                # Multi-character expressions are overwhelmingly more useful
                # for OCR lookup than isolated kana. Length outranks dictionary
                # frequency; score and earlier position break ties.
                rank = (1 if len(surface) > 1 else 0, -run_index, -start, len(surface), top_score)
                reading = accepted[0].get("reading") or base
                payload = {
                    "query": text, "surface": surface, "matched": base, "consumed": len(surface),
                    "deinflection": reason, "reading": reading, "romaji": romanize_kana(reading),
                    "terms": accepted, "metadata": _metadata_for(db, base),
                    "kanji": kanji_lookup(db, base).get("kanji", []),
                    "segment": run, "segmentOffset": start,
                }
                if best is None or rank > best[0]:
                    best = (rank, payload)
                break

    if best is not None:
        return best[1]
    return {"query": text, "surface": "", "matched": "", "consumed": 0, "deinflection": "", "reading": "", "romaji": "",
            "terms": [], "metadata": {"pitch": [], "frequency": [], "ipa": []}, "kanji": []}

def _decode_json(value: str, fallback: Any) -> Any:
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return fallback


def _metadata_for(db: sqlite3.Connection, expression: str) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {"pitch": [], "frequency": [], "ipa": []}
    rows = db.execute(
        """SELECT m.meta_type, m.data_json, d.title AS dictionary
           FROM term_meta m JOIN dictionaries d ON d.id = m.dictionary_id
           WHERE m.expression = ?""",
        (expression,),
    )
    for row in rows:
        item = {"dictionary": row["dictionary"], "data": _decode_json(row["data_json"], None)}
        if row["meta_type"] == "freq":
            result["frequency"].append(item)
        else:
            result[row["meta_type"]].append(item)
    return result


def _plain_structured_text(node: Any, *, include_ruby_reading: bool = False) -> str:
    """Flatten Yomitan structured content without leaking its JSON schema to UI."""
    if node is None:
        return ""
    if isinstance(node, str):
        return node.strip()
    if isinstance(node, (int, float, bool)):
        return str(node)
    if isinstance(node, list):
        parts = [_plain_structured_text(item, include_ruby_reading=include_ruby_reading) for item in node]
        return " ".join(part for part in parts if part).strip()
    if not isinstance(node, dict):
        return ""

    # ruby content normally contains [surface, {tag: rt, content: reading}].
    # The popup already shows a canonical reading, so don't duplicate furigana.
    if node.get("tag") == "rt" and not include_ruby_reading:
        return ""
    return _plain_structured_text(node.get("content"), include_ruby_reading=include_ruby_reading)


def _find_structured_by_role(node: Any, role: str) -> list[Any]:
    found: list[Any] = []
    if isinstance(node, list):
        for item in node:
            found.extend(_find_structured_by_role(item, role))
        return found
    if not isinstance(node, dict):
        return found
    data = node.get("data")
    if isinstance(data, dict) and data.get("content") == role:
        found.append(node.get("content"))
        return found
    found.extend(_find_structured_by_role(node.get("content"), role))
    return found


def display_definitions(glossary: Any) -> list[str]:
    """Return compact human-readable senses from simple or structured Yomitan glossaries."""
    if not isinstance(glossary, list):
        glossary = [glossary]
    out: list[str] = []
    seen: set[str] = set()

    def add(text: str) -> None:
        text = re.sub(r"\s+", " ", text).strip(" \n\t·•")
        if text and text not in seen:
            seen.add(text)
            out.append(text)

    for entry in glossary:
        if isinstance(entry, str):
            add(entry)
            continue
        if isinstance(entry, dict) and entry.get("type") == "structured-content":
            # Jitendex marks actual dictionary senses as glossary nodes. Keep
            # examples/tags/HTML decoration out of the compact OCR popup.
            gloss_nodes = _find_structured_by_role(entry.get("content"), "glossary")
            for node in gloss_nodes:
                add(_plain_structured_text(node))
            # A concise literal gloss is useful for idioms when present.
            literal_nodes = _find_structured_by_role(entry.get("content"), "info-gloss-content")
            for node in literal_nodes[:1]:
                literal = _plain_structured_text(node)
                if literal:
                    add(f"Literally: {literal}")
            continue
        add(_plain_structured_text(entry))
    return out[:8]


def term_rows(db: sqlite3.Connection, expression: str, limit: int, *, reading_too: bool = True) -> list[dict[str, Any]]:
    if reading_too:
        query = """SELECT t.*, d.title AS dictionary
                   FROM terms t JOIN dictionaries d ON d.id = t.dictionary_id
                   WHERE t.expression = ? OR t.reading = ?
                   ORDER BY CASE WHEN t.expression = ? THEN 0 ELSE 1 END, t.score DESC, t.id
                   LIMIT ?"""
        params = (expression, expression, expression, limit)
    else:
        query = """SELECT t.*, d.title AS dictionary
                   FROM terms t JOIN dictionaries d ON d.id = t.dictionary_id
                   WHERE t.expression = ?
                   ORDER BY t.score DESC, t.id LIMIT ?"""
        params = (expression, limit)
    result = []
    for row in db.execute(query, params):
        result.append(
            {
                "expression": row["expression"],
                "reading": row["reading"] or row["expression"],
                "definitionTags": row["definition_tags"].split() if row["definition_tags"] else [],
                "rules": row["rules"].split() if row["rules"] else [],
                "score": row["score"],
                "definitions": _decode_json(row["glossary_json"], []),
                "displayDefinitions": display_definitions(_decode_json(row["glossary_json"], [])),
                "sequence": None if row["sequence"] < 0 else row["sequence"],
                "termTags": row["term_tags"].split() if row["term_tags"] else [],
                "dictionary": row["dictionary"],
            }
        )
    return result


def lookup(db: sqlite3.Connection, text: str, limit: int) -> dict[str, Any]:
    terms = term_rows(db, text, limit)
    return {"query": text, "terms": terms, "metadata": _metadata_for(db, text)}


def scan_prefix(db: sqlite3.Connection, text: str, limit: int, max_chars: int) -> dict[str, Any]:
    # Japanese has no mandatory whitespace. Matching longest dictionary prefixes
    # gives OCR text a useful first lookup without making tokenizer choice part of
    # the dictionary storage contract. A morphology layer can add deinflection on
    # top later without changing this API.
    candidate = text.strip()[:max_chars]
    matched = ""
    terms: list[dict[str, Any]] = []
    for size in range(len(candidate), 0, -1):
        prefix = candidate[:size]
        terms = term_rows(db, prefix, limit, reading_too=False)
        if terms:
            matched = prefix
            break
    return {
        "query": text,
        "matched": matched,
        "consumed": len(matched),
        "terms": terms,
        "metadata": _metadata_for(db, matched) if matched else {"pitch": [], "frequency": [], "ipa": []},
    }


def kanji_lookup(db: sqlite3.Connection, text: str) -> dict[str, Any]:
    seen: set[str] = set()
    chars = [c for c in text if not (c in seen or seen.add(c))]
    rows: list[dict[str, Any]] = []
    for char in chars:
        matches = db.execute(
            """SELECT k.*, d.title AS dictionary
               FROM kanji k JOIN dictionaries d ON d.id = k.dictionary_id
               WHERE k.character = ? ORDER BY k.id""",
            (char,),
        )
        for row in matches:
            rows.append(
                {
                    "character": row["character"],
                    "onyomi": row["onyomi"].split() if row["onyomi"] else [],
                    "kunyomi": row["kunyomi"].split() if row["kunyomi"] else [],
                    "tags": row["tags"].split() if row["tags"] else [],
                    "meanings": _decode_json(row["meanings_json"], []),
                    "stats": _decode_json(row["stats_json"], {}),
                    "dictionary": row["dictionary"],
                }
            )
    return {"query": text, "kanji": rows}


def list_dictionaries(db: sqlite3.Connection) -> dict[str, Any]:
    dictionaries = []
    for row in db.execute(
        """SELECT d.*,
           (SELECT COUNT(*) FROM terms t WHERE t.dictionary_id = d.id) AS terms,
           (SELECT COUNT(*) FROM term_meta m WHERE m.dictionary_id = d.id) AS metadata,
           (SELECT COUNT(*) FROM kanji k WHERE k.dictionary_id = d.id) AS kanji
           FROM dictionaries d ORDER BY d.title COLLATE NOCASE"""
    ):
        dictionaries.append(dict(row))
    return {"dictionaries": dictionaries}


def remove_dictionary(db: sqlite3.Connection, title: str) -> dict[str, Any]:
    with db:
        cur = db.execute("DELETE FROM dictionaries WHERE title = ?", (title,))
    return {"ok": cur.rowcount > 0, "removed": title if cur.rowcount else ""}



def anki_request(endpoint: str, action: str, params: dict[str, Any]) -> Any:
    payload = json.dumps({"action": action, "version": 6, "params": params}).encode("utf-8")
    req = urllib.request.Request(endpoint, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=3) as response:
            data = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise ValueError(f"AnkiConnect unavailable: {exc}") from exc
    if data.get("error"):
        raise ValueError(str(data["error"]))
    return data.get("result")

def _anki_launcher() -> list[str]:
    native = shutil.which("anki")
    if native:
        return [native]
    flatpak = shutil.which("flatpak")
    if flatpak:
        try:
            probe = subprocess.run(
                [flatpak, "info", "net.ankiweb.Anki"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2,
            )
            if probe.returncode == 0:
                return [flatpak, "run", "net.ankiweb.Anki"]
        except (OSError, subprocess.TimeoutExpired):
            pass
    return []


def _anki_process_running() -> bool:
    proc = Path("/proc")
    try:
        entries = list(proc.iterdir())
    except OSError:
        return False
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            comm = (entry / "comm").read_text(errors="ignore").strip().lower()
            exe = os.path.basename(os.readlink(entry / "exe")).lower()
            argv0 = (entry / "cmdline").read_bytes().split(b"\0", 1)[0].decode(errors="ignore")
            argv0 = os.path.basename(argv0).lower()
        except OSError:
            continue
        if comm == "anki" or argv0 == "anki" or exe == "anki" or exe.startswith("anki-"):
            return True
    return False


def anki_status(endpoint: str) -> dict[str, Any]:
    launcher = _anki_launcher()
    running = _anki_process_running()
    try:
        version = anki_request(endpoint, "version", {})
        return {
            "ok": True, "available": True, "state": "connected", "version": version,
            "installed": bool(launcher) or running, "running": True,
        }
    except ValueError as exc:
        if running:
            state = "connect_unavailable"
        elif launcher:
            state = "app_closed"
        else:
            state = "not_installed"
        return {
            "ok": True, "available": False, "state": state,
            "installed": bool(launcher), "running": running,
            "error": str(exc),
        }


def anki_launch() -> dict[str, Any]:
    launcher = _anki_launcher()
    if not launcher:
        return {"ok": False, "error": "Anki desktop is not installed", "state": "not_installed"}
    try:
        subprocess.Popen(launcher, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as exc:
        return {"ok": False, "error": f"Could not launch Anki: {exc}"}
    return {"ok": True, "launched": True}

def anki_add(endpoint: str, deck: str, model: str, front_field: str, back_field: str, expression: str, reading: str, definitions: str) -> dict[str, Any]:
    front = expression + (f"<br><small>{reading}</small>" if reading and reading != expression else "")
    note = {
        "deckName": deck, "modelName": model,
        "fields": {front_field: front, back_field: definitions},
        "options": {"allowDuplicate": False}, "tags": ["inir", "japanese-ocr"],
    }
    note_id = anki_request(endpoint, "addNote", {"note": note})
    return {"ok": True, "noteId": note_id}

def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="iNiR local Yomitan-compatible Japanese dictionary index")
    p.add_argument("--db", type=Path, default=default_db_path(), help="override SQLite database path")
    p.add_argument("--pretty", action="store_true", help="pretty-print JSON output")
    sub = p.add_subparsers(dest="command", required=True)

    imp = sub.add_parser("import", help="import or replace one Yomitan dictionary ZIP")
    imp.add_argument("archive", type=Path)

    sub.add_parser("list", help="list imported dictionaries")

    look = sub.add_parser("lookup", help="exact term/reading lookup")
    look.add_argument("text")
    look.add_argument("--limit", type=int, default=16)

    scan = sub.add_parser("scan", help="longest dictionary prefix at the start of OCR text")
    scan.add_argument("text")
    scan.add_argument("--limit", type=int, default=16)
    scan.add_argument("--max-chars", type=int, default=32)

    smart = sub.add_parser("scan-smart", help="OCR lookup with Japanese deinflection")
    smart.add_argument("text")
    smart.add_argument("--limit", type=int, default=16)
    smart.add_argument("--max-chars", type=int, default=32)

    kj = sub.add_parser("kanji", help="lookup kanji information for characters in text")
    kj.add_argument("text")

    rm = sub.add_parser("remove", help="remove an imported dictionary by exact title")
    rm.add_argument("title")

    anki_status_cmd = sub.add_parser("anki-status", help="check local AnkiConnect availability")
    anki_status_cmd.add_argument("--endpoint", default="http://127.0.0.1:8765")

    sub.add_parser("anki-launch", help="launch the locally installed Anki desktop app")

    anki = sub.add_parser("anki-add", help="add one lookup result through local AnkiConnect")
    anki.add_argument("expression")
    anki.add_argument("reading")
    anki.add_argument("definitions")
    anki.add_argument("--endpoint", default="http://127.0.0.1:8765")
    anki.add_argument("--deck", default="Default")
    anki.add_argument("--model", default="Basic")
    anki.add_argument("--front-field", default="Front")
    anki.add_argument("--back-field", default="Back")
    return p


def main() -> int:
    args = parser().parse_args()
    try:
        db = connect(args.db)
        if args.command == "import":
            payload = import_dictionary(db, args.archive)
        elif args.command == "list":
            payload = list_dictionaries(db)
        elif args.command == "lookup":
            payload = lookup(db, args.text, max(1, min(args.limit, 100)))
        elif args.command == "scan":
            payload = scan_prefix(db, args.text, max(1, min(args.limit, 100)), max(1, min(args.max_chars, 128)))
        elif args.command == "scan-smart":
            payload = smart_scan(db, args.text, max(1, min(args.limit, 100)), max(1, min(args.max_chars, 128)))
        elif args.command == "kanji":
            payload = kanji_lookup(db, args.text)
        elif args.command == "remove":
            payload = remove_dictionary(db, args.title)
        elif args.command == "anki-status":
            payload = anki_status(args.endpoint)
        elif args.command == "anki-launch":
            payload = anki_launch()
        elif args.command == "anki-add":
            payload = anki_add(args.endpoint, args.deck, args.model, args.front_field, args.back_field, args.expression, args.reading, args.definitions)
        else:
            raise AssertionError(args.command)
        emit(payload, pretty=args.pretty)
        return 0
    except (ValueError, OSError, sqlite3.Error, zipfile.BadZipFile) as exc:
        emit({"ok": False, "error": str(exc)}, pretty=args.pretty)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
