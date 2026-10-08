# Runtime localization

`en_US.json` is canonical. Other locales keep the same keys and translate only the values.

The localization helper does not call a translation service. It prepares contextual review batches and rejects unsafe results.

## Audit locales

```bash
python3 translations/tools/l10n.py audit-guides
python3 translations/tools/l10n.py audit-source
python3 translations/tools/l10n.py audit-all
python3 translations/tools/l10n.py audit es_419
```

The repository gate requires one writing guide for every supported locale, source coverage in canonical `en_US.json`, locale key parity, placeholders/markup, protected product names and locale-specific semantic terminology guards. Suspected untranslated values are reported for review but are not automatically errors because product names and established technical terms can legitimately remain unchanged. Commands, paths, codecs and common acronyms are excluded through `glossary.json`.

## Prepare a review batch

```bash
python3 translations/tools/l10n.py extract es_419 /tmp/es_419-001.json --limit 200
```

Each entry contains:

- the stable translation key
- the English source
- the current value
- a blank `translated` field
- QML locations when they can be found
- the locale writing guide

Translate only `translated`. Keep the other fields unchanged.

## Apply a reviewed batch

```bash
python3 translations/tools/l10n.py apply /tmp/es_419-001.json
bash scripts/verify-docs.sh
```

The apply command refuses unknown or duplicate keys, changed English source text, modified placeholders or markup such as `%1`, `{0}`, `<i>` and `</i>`, and translations that rename protected product terms.

## Rules

- Keep product names and commands unchanged.
- Use natural desktop terminology, not literal machine translation.
- Translate for the surface, not for dictionary equivalence. A compact status
  label may need a standard abbreviation even when the long form is correct.
- Keep gauges, bar labels, OSD text, pills and chips on one readable line. Do
  not expand CPU/RAM/GPU or turn a lock/media state into a sentence.
- Adapt dry jokes instead of translating them word for word.
- Finish and validate one locale before moving to the next.
