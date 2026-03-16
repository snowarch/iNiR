---
trigger: model_decision
description: Pull when adding translatable strings, updating language files, or working on the Translation service and i18n tooling.
---

# iNiR Translation & i18n System (Verified from source code)

## Architecture

JSON key-value. No Qt Linguist, no .ts, no gettext. English string = key. 260 dependents.

### Lookup: `Translation.tr(text)`
```
1. translations[key]           — bundled (highest priority)
2. generatedTranslations[key]  — user AI-generated
3. key itself                  — English passthrough (never crashes, never empty)
```

### File locations
```
Bundled:   runtime shell dir + `/translations/<lang>.json` (e.g. `~/.config/quickshell/inir/translations/<lang>.json`)
Generated: ~/.config/illogical-impulse/translations/<lang>.json  (survives updates; legacy config namespace)
```

### Language detection
```qml
languageCode = Config.options?.language?.ui ?? "auto"
// "auto" → Qt.locale().name (e.g. "zh_CN")
// explicit code → loads that language file
// Live switching — no restart needed
```

## Usage Pattern

```qml
// Static
text: Translation.tr("Settings")

// With params — Qt .arg() chaining
text: Translation.tr("Up %1").arg(DateTime.uptime)
text: Translation.tr("%1 characters").arg(count)
```

## File Format

Plain UTF-8 JSON. Key = exact English string (including whitespace, newlines, punctuation).
```json
{
  "Settings": "设置",
  "Volume": "音量",
  "%1 characters": "%1 个字符",
  "Mo": "月/*keep*/"
}
```

### `/*keep*/` Marker
Appended to VALUE to prevent tooling cleanup. Stripped by `tr()` before returning. Used for short strings that equal their English key (day abbreviations).

## Adding New Translatable String

1. Wrap in QML: `Translation.tr("Your new string")`
2. Add to `en_US.json`: `"Your new string": "Your new string"`
3. Sync: `cd translations/tools && ./manage-translations.sh sync`

## Adding New Language

```bash
cp translations/en_US.json translations/fr_FR.json
# Translate values (keys stay English)
# Auto-discovered on next shell restart
# Or: Settings → General → Generate with Gemini AI
```

## Tooling (`translations/tools/`)

```bash
./manage-translations.sh status     # count keys per language
./manage-translations.sh extract    # extract all tr() calls from source
./manage-translations.sh sync       # add missing keys from en_US to all others
./manage-translations.sh clean      # remove keys not in source (respects /*keep*/)
./manage-translations.sh update -l zh_CN  # interactive add/remove for one language
```

AI generation: `scripts/ai/gemini-translate.sh` — sends en_US.json to Gemini, saves to user config dir.

## Available Languages

en_US (~870 keys), es_AR (~584), zh_CN (~470), he_HE (~503), ja_JP (~430), ru_RU (~388), vi_VN (~369), it_IT (~359), uk_UA (~339). All incomplete — missing keys fall back to English silently.
