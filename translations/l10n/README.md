# Runtime localization

`en_US.json` is canonical. Other locales keep the same keys and translate only the values.

The localization helper does not call a translation service. It prepares contextual review batches and rejects unsafe results.

## Audit locales

```bash
python3 translations/tools/l10n.py audit-all
python3 translations/tools/l10n.py audit es_AR --strict-terms
```

The repository gate checks key parity plus placeholders and markup for every locale. A focused audit also reports untranslated values and protected product-name drift; `--strict-terms` turns those product-name warnings into errors for an actively reviewed locale. Commands, paths, codecs and common acronyms are excluded through `glossary.json`.

## Prepare a review batch

```bash
python3 translations/tools/l10n.py extract es_AR /tmp/es_AR-001.json --limit 200
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
python3 translations/tools/l10n.py apply /tmp/es_AR-001.json
bash scripts/verify-docs.sh
```

The apply command refuses unknown or duplicate keys, changed English source text, modified placeholders or markup such as `%1`, `{0}`, `<i>` and `</i>`, and translations that rename protected product terms.

## Rules

- Keep product names and commands unchanged.
- Use natural desktop terminology, not literal machine translation.
- Keep labels short enough for the UI.
- Adapt dry jokes instead of translating them word for word.
- Finish and validate one locale before moving to the next.
