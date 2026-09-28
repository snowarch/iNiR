# Japanese OCR study assistant

iNiR can turn Japanese pixels from any Wayland surface into a local dictionary lookup. It is designed for games, manga, images, PDFs, video and applications where the shell cannot inspect a browser DOM or native text node.

## Normal user flow

1. Open **Settings → Tools → Snipping** and choose the expected OCR language. For Japanese use **Japanese** for normal horizontal writing or **Japanese (vertical)** for vertical manga/book text.
2. Use the normal region selector and draw a tight box around a word, short phrase or line. OCR works from pixels, so excluding unrelated text gives the recognizer a much easier job. Small selections are enlarged automatically before Tesseract runs.
3. If the required Tesseract language data is missing, iNiR first reuses distro-installed data and can otherwise provision the missing model once in `~/.local/share/inir/tessdata/` without sudo.
4. Japanese OCR copies the full recognized text and opens a compact study card beside the captured region.
5. On first use, choose **Install Japanese dictionary**. iNiR downloads and indexes Jitendex automatically; normal users do not need to find a Yomitan ZIP. After indexing, dictionary lookup is local/offline.
6. The compact card shows the useful matched term, canonical headword/reading, romaji and concise definitions. **Expand** shows the complete OCR selection, extra dictionary information, translation and study actions.

## What the matcher does

Japanese has no required spaces between words, while OCR can insert spaces between individual glyphs. The lookup backend therefore:

- collapses OCR-only spaces between Japanese characters;
- scans Japanese runs even when bullets, romaji or translated text surround them;
- checks both written forms and dictionary readings (`どこ` can resolve `何処`);
- prefers useful multi-character terms and dictionary priority over accidental one-kana matches;
- deinflects common polite, negative, past/te, passive, causative, godan, `する`/`来る` and i-adjective forms;
- validates generated base forms against Yomitan rule tags before accepting them.

A tight capture is still important. OCR cannot recover characters that are visually ambiguous, heavily stylized, occluded or too low resolution.

## Dictionary and translation

The recommended dictionary is **Jitendex**, downloaded on demand rather than bundled in the repository. iNiR accepts Yomitan v3 `term_bank_*`, `term_meta_bank_*` and `kanji_bank_*` archives for advanced users who want additional dictionaries. Pitch/frequency/IPA metadata is used when the imported dictionary provides it.

Dictionary lookup itself is offline after installation. **Translate** is separate and reuses iNiR's existing `translate-shell` integration, so translation requires network access to the configured translation engine. The compact card translates the matched term; the expanded card can translate the complete OCR selection.

## Anki

Anki is optional. OCR, dictionary lookup and translation do not depend on it.

To save flashcards, Anki Desktop must be running with the **AnkiConnect** add-on enabled. Settings reports whether Anki is missing, closed, running without an AnkiConnect listener, or connected. Advanced endpoint/deck/model/field options remain available for non-default Anki setups.

Settings also provides a small catalog of ready-made Japanese decks. iNiR resolves the current upstream release, downloads the `.apkg` to the user's Downloads folder and opens it for import; third-party deck bytes are not bundled with iNiR.

## Current boundary

This implementation is region-OCR-first. It does **not** yet provide browser-extension-style “hold a modifier and inspect the exact word under the cursor” behavior. A compositor-wide cursor lookup would need its own fast capture/word-localization layer because Wayland deliberately does not expose arbitrary application text to the shell. The current compact/expandable card and local dictionary backend are designed so that interaction can be added later without replacing the data layer.
