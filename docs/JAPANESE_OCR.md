# Japanese OCR study card

iNiR can read Japanese from any part of your screen: games, manga, images, PDFs and video. You draw a box around the text, and the words it finds are looked up in a dictionary that runs on your computer.

## Set it up

1. Open **Settings › Tools**.
2. Under **Snipping & OCR**, set **Text language** to **Japanese** for horizontal text, or **Japanese (vertical)** for vertical manga and books. **Japanese + English** is there for mixed text.
3. Under **Japanese study assistant**, press **Install Japanese dictionary (~37 MB)**. iNiR downloads and indexes the Jitendex dictionary for you. Lookups work offline after that.

If Tesseract is missing its Japanese data, iNiR uses the copy your system has. Otherwise it downloads the data once into `~/.local/share/inir/tessdata/`, without sudo.

## Look up text

1. Press **Super+Shift+X** and draw a tight box around a word, a phrase or a line. Leave out other text, since OCR works from the pixels.
2. A study card opens beside the box with the word it matched.

Short selections, under 140 pixels tall, are enlarged before OCR runs.

The card shows the matched word, its dictionary form and reading, romaji and short definitions. **Expand lookup** adds the full OCR text, more dictionary detail, **Translate selection** and the Anki actions. **Compact view** goes back to the small card. A copy button copies the text.

There is no hover lookup yet, so you always draw a box. Blurred, very stylised or tiny text may come out wrong.

**Translate selection** and the card's translation use translate-shell, so they need an internet connection. Dictionary lookups work offline.

Under **Japanese study assistant**, **More dictionary options** lets you import another Yomitan dictionary ZIP.

## Anki (optional)

You don't need Anki for OCR or lookups. To add cards, open Anki Desktop with the AnkiConnect add-on enabled. **Settings › Tools › Anki (optional)** shows whether Anki is missing, closed, running without AnkiConnect, or connected. **Install / check AnkiConnect** helps you set it up. **Show Anki actions in the study card** turns the card's Anki buttons on or off.

**Advanced Anki settings** holds the endpoint, deck, note type and field names, for setups that are not the defaults.

## Ready-made decks

**Ready-made Japanese study decks** lists Kaishi 1.5k, Manabi 2.7k and Niponismo. iNiR downloads the latest `.apkg` to your Downloads folder and opens it for import. The decks are not bundled with iNiR.
