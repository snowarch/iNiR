<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Una shell desktop completa per Niri, costruita con Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">Installazione</a> &bull;
  <a href="../KEYBINDS.md">Scorciatoie</a> &bull;
  <a href="../IPC.md">Riferimento IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuire</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Sulla traduzione:** Traduzione della community. In caso di dubbi, consulta la [versione inglese](../../README.md).

---

<details>
<summary><b>🤔 Prima volta qui? Clicca se non capisci cos'è</b></summary>

### Cos'è questo?

iNiR è tutto il tuo desktop. La barra in alto, il dock, notifiche, impostazioni, sfondi, tutto. Non è un tema, non sono dotfiles da copiare. È una shell completa che gira su Linux.

### Cosa serve per farlo girare?

Un compositor. È quello che gestisce le finestre e mette i pixel sullo schermo. iNiR è fatto per [Niri](https://github.com/YaLTeR/niri) (un compositor Wayland a tiling). C'è del vecchio codice Hyprland da quando era un fork dei dots di end-4, ma Niri è quello che testo e uso davvero.

La shell gira su [Quickshell](https://quickshell.outfoxxed.me/), un framework per costruire shell in QML (il linguaggio UI di Qt). Non serve saperlo per usarla, tutto si configura dalla GUI o un file JSON.

### Come si collega tutto

```
le tue app
   ↓
iNiR (shell: barra, sidebar, dock, notifiche, impostazioni...)
   ↓
Quickshell (fa girare shell QML)
   ↓
Niri (compositor: finestre, rendering)
   ↓
Wayland → GPU
```

### È stabile?

È un progetto personale che mi è sfuggito di mano. Lo uso ogni giorno, tanta gente su Discord anche. Ma a volte si rompe, il codice è disordinato in posti, imparo mentre faccio.

Se qualcosa non funziona, `inir doctor` sistema la maggior parte. Se non basta, Discord è attivo. Non aspettarti software rifinito, questo è il rice di una persona che è piaciuto ad altri.

### Perché esiste?

Volevo che il mio desktop avesse un certo aspetto e funzionasse in un certo modo, e nient'altro lo faceva esattamente. Iniziato come i dots Hyprland di end-4, diventato una riscrittura completa per Niri con molte più feature.

### Parole che vedrai

- **Shell**: il layer UI (barra, pannelli, overlay)
- **Compositor**: gestisce finestre, disegna sullo schermo (Niri, Hyprland, Sway...)
- **Wayland**: protocollo display di Linux (il nuovo, sostituisce X11)
- **QML**: linguaggio UI dichiarativo di Qt, iNiR è scritto in questo
- **Material You**: sistema colori Google che genera palette da immagini (così funziona l'auto-theming)
- **ii / waffle**: i due stili di pannello. ii = vibes Material Design, waffle = vibes Windows 11. `Super+Shift+W` per cambiare

</details>

---

## Screenshot

<details open>
<summary><b>Material ii</b> — barra flottante, barre laterali, estetica Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — barra delle applicazioni in basso, centro azioni, stile Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Funzionalità

**Due famiglie di pannelli**, commutabili al volo con `Super+Shift+W`:
- **Material ii** — barra flottante, barre laterali, dock, 5 stili visivi (material, cards, aurora, inir, angel)
- **Waffle** — barra delle applicazioni stile Windows 11, menu start, centro azioni, centro notifiche

**Tematizzazione automatica** — scegli uno sfondo e tutto si adatta:
- Colori della shell via Material You, propagati a GTK3/4, Qt, terminali, Firefox, Discord, SDDM
- 10 strumenti terminale auto-tematizzati (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Preset di temi: Gruvbox, Catppuccin, Rosé Pine, e personalizzati

**Compositor** — costruito per Niri.

<details>
<summary><b>Lista completa delle funzionalità</b></summary>

### Temi e aspetto

Scegli uno sfondo e l'intero sistema segue — shell, app GTK/Qt, terminali, Firefox, Discord, schermata di login SDDM. Tutto automatico.

- **5 stili visivi** — Material (pieno), Cards, Aurora (sfocatura vetro), iNiR (ispirato TUI), Angel (neo-brutalismo)
- **Colori dinamici dallo sfondo** via Material You — propagati a tutto il sistema
- **10 strumenti terminale auto-tematizzati** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **Tematizzazione app** — GTK3/4, Qt (via plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Preset di temi** — Gruvbox, Catppuccin, Rosé Pine, e altri — o crea il tuo
- **Sfondi video** — mp4/webm/gif con sfocatura opzionale, o primo frame congelato per le prestazioni
- **Tema SDDM di login** — colori Material You sincronizzati con lo sfondo
- **Widget desktop** — orologio (più stili), meteo, controlli multimediali sul livello sfondo

### Barre laterali e widget (Material ii)

Barra laterale sinistra (cassetto app):
- **Chat IA** — Gemini, Mistral, OpenRouter, o modelli locali via Ollama
- **YT Music** — lettore completo con ricerca, coda e controlli
- **Browser Wallhaven** — cerca e applica sfondi direttamente
- **Anime tracker** — integrazione AniList con vista del palinsesto
- **Feed Reddit** — sfoglia subreddit inline
- **Traduttore** — via Gemini o translate-shell
- **Widget trascinabili** — crypto, lettore multimediale, note rapide, anelli di stato, calendario settimanale

Barra laterale destra:
- **Calendario** con integrazione eventi
- **Centro notifiche**
- **Toggle rapidi** — WiFi, Bluetooth, luce notturna, DND, profili energetici, WARP VPN, EasyEffects
- **Mixer volume** — controllo per applicazione
- **Bluetooth e WiFi** — gestione dispositivi
- **Timer pomodoro**, **lista attività**, **calcolatrice**, **blocco note**
- **Monitor di sistema** — CPU, RAM, temperatura

### Strumenti

- **Panoramica workspace** — adattata al modello di scorrimento di Niri, con ricerca app e calcolatrice
- **Selettore finestre** — Alt+Tab tra tutti i workspace
- **Gestore appunti** — cronologia con ricerca e anteprima immagini
- **Strumenti regione** — screenshot, registrazione schermo, OCR, ricerca inversa immagini
- **Foglio promemoria** — visualizzatore scorciatoie estratte dalla config di Niri
- **Controlli multimediali** — lettore MPRIS completo con più preset di layout
- **Display su schermo** — OSD volume, luminosità e multimedia
- **Riconoscimento brani** — identificazione stile Shazam via SongRec
- **Ricerca vocale** — registra e cerca via Gemini

### Sistema

- **Impostazioni GUI** — configura tutto senza modificare file
- **GameMode** — disabilita automaticamente gli effetti per le app a schermo intero
- **Aggiornamenti automatici** — `inir update` con rollback, migrazioni e preservazione delle modifiche utente
- **Schermata di blocco** e **schermata di sessione** (logout/riavvio/spegnimento/sospensione)
- **Agente polkit**, **tastiera su schermo**, **gestore avvio automatico**
- **9 lingue** — rilevamento automatico, con generazione traduzioni assistita da IA
- **Luce notturna** — programmata o manuale
- **Meteo** — Open-Meteo, supporta GPS, coordinate manuali o nome città
- **Gestione batteria** — soglie configurabili, sospensione automatica in stato critico
- **Controllo aggiornamenti shell** — notifica quando sono disponibili nuove versioni

</details>

---

## Avvio rapido

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interattivo — chiede prima di ogni passo
./setup install -y    # automatico — nessuna domanda
```

L'installer gestisce dipendenze, configurazione di sistema, tematizzazione — tutto. Dopo l'installazione, esegui `inir run` per avviare la shell, o disconnettiti e riconnettiti.

```bash
inir run                        # avviare la shell
inir settings                   # aprire le impostazioni GUI
inir logs                       # controllare i log di runtime
inir doctor                     # auto-diagnosi e riparazione
inir update                     # pull + migrazioni + riavvio
```

**Distro supportate:** Arch (installer automatizzato). Altre distro possono installare manualmente — vedi [PACKAGES.md](../PACKAGES.md).

| Metodo | Comando |
|--------|---------|
| Installazione di sistema | `sudo make install && inir run` |
| Menu TUI | `./setup` |
| Rollback | `./setup rollback` |

---

## Scorciatoie

| Tasto | Azione |
|-----|--------|
| `Super+Space` | Panoramica — cerca app, naviga workspace |
| `Alt+Tab` | Selettore finestre |
| `Super+V` | Cronologia appunti |
| `Super+Shift+S` | Screenshot regione |
| `Super+Shift+X` | OCR regione |
| `Super+,` | Impostazioni |
| `Super+Shift+W` | Cambia famiglia di pannelli |

Lista completa: [KEYBINDS.md](../KEYBINDS.md)

---

## Sfondi

15 sfondi sono inclusi. Per altri, vedi [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — una collezione curata che funziona bene con la pipeline Material You.

---

## Documentazione

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | Guida all'installazione |
| [SETUP.md](../SETUP.md) | Comandi setup — aggiornamenti, migrazioni, rollback |
| [KEYBINDS.md](../KEYBINDS.md) | Tutte le scorciatoie da tastiera |
| [IPC.md](../IPC.md) | Target IPC per scripting e scorciatoie personalizzate |
| [PACKAGES.md](../PACKAGES.md) | Ogni dipendenza e perché c'è |
| [LIMITATIONS.md](../LIMITATIONS.md) | Limitazioni note e soluzioni |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Panoramica dell'architettura tecnica |

---

## Risoluzione problemi

```bash
inir logs                       # controlla i log — la risposta di solito è lì
inir restart                    # riavvia la shell
inir repair                     # doctor + riavvio + controllo log filtrato
./setup doctor                  # auto-diagnosi e risoluzione problemi comuni
./setup rollback                # annulla l'ultimo aggiornamento
```

Controlla [LIMITATIONS.md](../LIMITATIONS.md) prima di aprire un issue.

---

## Contribuire

Vedi [CONTRIBUTING.md](../../CONTRIBUTING.md) per la configurazione dell'ambiente di sviluppo, i pattern di codice e le linee guida per le PR.

---

## Crediti

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse originale per Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — il framework che alimenta questa shell
- [**Niri**](https://github.com/YaLTeR/niri) — il compositor Wayland a tiling con scorrimento

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributori</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">Licenza MIT</a>
</p>
