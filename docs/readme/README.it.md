<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Una shell desktop completa per Niri, costruita su Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Installa</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Scorciatoie</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">Riferimento IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuire</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Su questa traduzione:** in caso di dubbi, fa fede la [versione inglese](../../README.md).

---

<details>
<summary><b>🤔 Nuovo qui? Clicca se non hai idea di cosa sia tutto questo</b></summary>

### Cos'è?

iNiR è tutto il tuo desktop. La barra in alto, il dock, le notifiche, le impostazioni, gli sfondi, tutto. Non è un tema né dei dotfile da incollare. È una shell completa che gira su Linux.

### Cosa mi serve per usarlo?

Un compositor. È quello che gestisce le finestre e porta i pixel sullo schermo. iNiR è fatto per [Niri](https://github.com/YaLTeR/niri) (un compositor Wayland a tiling). C'è ancora del vecchio codice Hyprland di quando questo era un fork dei dots di end-4, ma Niri è quello che uso e provo davvero.

La shell gira su [Quickshell](https://quickshell.outfoxxed.me/), un framework per creare shell in QML (il linguaggio di interfaccia di Qt). Non serve sapere niente di tutto questo per usarla: si configura tutto dall'interfaccia o da un file JSON.

### Come si collega tutto

```
your apps
   ↓
iNiR (shell: bar, sidebars, dock, notifications, settings...)
   ↓
Quickshell (runs QML shells)
   ↓
Niri (compositor: windows, rendering)
   ↓
Wayland → GPU
```

### È stabile?

È un progetto personale che è sfuggito di mano. Lo uso ogni giorno, e tanta gente sul Discord pure. Ma a volte qualcosa si rompe, il codice è disordinato in alcuni punti e sto imparando strada facendo.

Se qualcosa non va, `inir doctor` sistema quasi tutto. Altrimenti il Discord è attivo. Solo, non aspettarti un software rifinito: è il rice di una persona che per caso piace anche ad altri.

### Perché esiste?

Volevo che il mio desktop avesse un certo aspetto e funzionasse in un certo modo, e niente faceva esattamente questo. È partito dai dots Hyprland di end-4 ed è diventato una riscrittura completa per Niri, con molte più funzioni.

### Parole che incontrerai

- **Shell**: lo strato di interfaccia (barra, pannelli, overlay)
- **Compositor**: gestisce le finestre e disegna sullo schermo (Niri, Hyprland, Sway...)
- **Wayland**: il protocollo di visualizzazione di Linux (quello nuovo, sostituisce X11)
- **QML**: il linguaggio di interfaccia dichiarativo di Qt, quello in cui è scritto iNiR
- **Material You**: il sistema di colori di Google che ricava palette da un'immagine (è così che funziona il tema automatico)
- **ii / waffle / iRiS**: le tre famiglie di pannelli. ii = stile Material Design, waffle = stile Windows 11, iRiS = una Island che diventa ciò che apri. `Super+Shift+W` passa dall'una all'altra

</details>

---

## Screenshot

<details open>
<summary><b>iRiS</b>: Island, Customize, barra dei menu, card e Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: barra flottante, sidebar, estetica Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: barra delle applicazioni in basso, centro operativo, stile Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> Non è per macchine poco potenti.
> Però si può alleggerire parecchio: spegni gli effetti, togli pannelli, semplifica il design. Dalle impostazioni o da `config.json`, come preferisci.

## Funzionalità

**Tre famiglie di pannelli**, intercambiabili al volo con `Super+Shift+W`:
- **Material ii**: barra flottante, sidebar, dock e 9 stili globali (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: barra delle applicazioni, menu start, centro operativo e centro notifiche in stile Windows 11
- **iRiS**: la famiglia di punta. Una Island su qualsiasi bordo dello schermo che si apre in pagine, card e pannelli, pezzi che puoi spostare, un Dock su qualsiasi bordo, glass, Themes che ridisegnano tutto, chiaro, inchiostro e scuro, e Customize direttamente sulla shell

**Tema automatico**. Scegli uno sfondo e tutto si adatta:
- Colori della shell con Material You, portati a GTK3/4, Qt, terminali, Firefox, Discord, SDDM
- 10 destinazioni del tema: terminali, editor, browser, Spicetify, Steam, Cava e altro
- Preset di tema: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine e i tuoi

**Fatto per Niri.** Il codice Hyprland sopravvive dal fork, ma non viene testato.

**Kira**, la mascotte, vive sul tuo desktop se la vuoi lì. È spenta di default e il suo pacchetto grafico si scarica a parte.

<details>
<summary><b>Elenco completo delle funzionalità</b></summary>

### iRiS

- **La Island**: un'unica forma su un bordo dello schermo che dice "cosa sta succedendo" e diventa la pagina, la card o il pannello che hai aperto, poi si richiude. In alto, in basso, a sinistra o a destra (`inir iris edge <side>`, o trascinala lì). Su un lato si alza in piedi, con l'orologio impilato e le bolle sopra e sotto
- **Barra dei menu**: una striscia sottile con i tuoi workspace, la finestra e i pezzi, con la Island appesa come un notch (`inir iris layout menubar`)
- **Modalità barra a tutta larghezza** con zone di inizio, centro e fine per la Island, i workspace, la finestra attiva, l'ora o qualsiasi pezzo (`inir iris zone start|center|end kinds+joined+with+plus`)
- **Pezzi**: meteo, audio, microfono, tray, notifiche, strumenti, musica, VPN, un visualizzatore, anime (Airing e Continue) e le tue app, come bolle da lasciare sulla Island, sul contorno dello schermo o libere sul desktop
- **I pezzi si uniscono a ciò che toccano**: mettine uno sul bordo del Dock o della Island e diventa parte di quel corpo invece di galleggiarci sopra
- **Dock** su qualsiasi bordo (`inir iris dockEdge <side|auto>`); in auto sta di fronte alla Island, e se ne mandi uno sul bordo dell'altro si scambiano di posto
- **Glass** che smeriglia lo sfondo sotto ogni superficie e tiene il testo leggibile anche su sfondi chiari o pieni di dettagli. Esiste anche il blur del compositor, ma è ancora in lavorazione, quindi non giudicarlo per ora
- **Themes**: 20 riprogettazioni curate (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 e altre) più le tue come file JSON da condividere (`inir iris theme`)
- **Chiaro, Inchiostro e Scuro**, ciascuno con il suo tono e la sua smerigliatura, e temi di colore (Catppuccin, Nord, Rosé Pine, Tokyo Night…) che usano anche le tue app (`inir iris palette`)
- **Forma**: capsula, rotonda, squircle o quadrata per la Island e il Dock
- **Customize sulla shell**: tocca la Island, il Dock o una bolla e le sue opzioni escono da lì, con Themes, Look, Pieces e annulla sotto la Island (`inir iris edit`). Se preferisci, Studio raccoglie tutto in un pannello accanto allo schermo
- **Un Control Center che componi tu**: ogni interruttore rapido condiviso, il player e ogni slider sono celle che trascini, ridimensioni da un angolo e aggiungi da una libreria accanto, con sei layout di partenza; con il tasto destro un controllo si apre (`inir iris control edit`)
- **Una schermata di blocco da provare**: il vero blocco si apre modificabile e senza niente da sbloccare; sposta l'orologio, il player e il campo di accesso, e scegli cosa scorre dietro, video compreso (`inir iris lock edit`)

### Tema e aspetto

- **9 stili globali**: Material (pieno), Cards, Aurora (glass con blur), iNiR (ispirato alle TUI), Angel (neo-brutalismo), Regalia (telaio nero, inchiostro avorio caldo, finiture champagne sobrie), ZZZ (lastre da poster), Cookie Shapes (forme animate), Editorial (tipografia carta e inchiostro)
- **Colori dinamici dallo sfondo** con Material You, in tutto il sistema
- **10 strumenti da terminale e TUI con tema automatico**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **Tema delle app**: GTK3/4, Qt (con plasma-integration e darkly), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Preset di tema**: Gruvbox, Catppuccin, Rosé Pine e altri, oppure crea il tuo
- **Sfondi video**: mp4/webm/gif con blur opzionale, o il primo fotogramma fermo per le prestazioni
- **Widget del desktop**: un solo design per tutti (iRiS, Material, iNstrument o Readout), pile che girano come su iOS e inchiostro che segue lo sfondo sotto di loro

### Barra

- **6 stili di barra**: classic, islands, scenic, frame, capsule Material 3 e pill
- **Barra pill**: un'isola centrale che si trasforma e al passaggio del mouse apre workspace, launcher, mixer, musica, calendario e registratore dello schermo
- **Layout modulare** con editor a trascinamento nelle impostazioni, per mettere qualsiasi modulo ovunque
- **Barra verticale** per chi rivuole il bordo dello schermo

### Sidebar e widget (Material ii)

Sidebar sinistra (cassetto delle app):
- **Chat IA**: cataloghi di modelli in tempo reale da Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI e OpenCode
- **YT Music**: player InnerTube senza cookie, con ricerca, coda, radio e testi sincronizzati
- **Browser Wallhaven**: cerca e applica sfondi direttamente
- **Tracker anime**: integrazione con AniList e vista del palinsesto
- **Traduttore**: con Gemini o translate-shell
- **Widget trascinabili**: cripto, player, note rapide, anelli di stato, calendario settimanale

Sidebar destra:
- **Calendario** con eventi
- **Centro notifiche**
- **Interruttori rapidi**: WiFi, Bluetooth, luce notturna, Non disturbare, profili energetici, WARP VPN, EasyEffects
- **Mixer del volume** per app
- **Bluetooth e WiFi**: gestione dei dispositivi
- **Pomodoro**, **attività**, **calcolatrice**, **blocco note**
- **Monitor di sistema**: CPU, RAM, temperatura

### Strumenti

- **Panoramica dei workspace**: adattata al modello a scorrimento di Niri, con ricerca app e calcolatrice
- **Dashboard**: overlay configurabile a tre colonne con agenda, notifiche, attività, note, musica e meteo
- **Striscia dei workspace sul bordo**: binario al passaggio del mouse con anteprime dal vivo e riordino trascinando
- **Selettore di finestre**: un Alt-Tab animato su tutti i workspace, opzionale ora che Niri ha il suo
- **Appunti**: cronologia con ricerca e anteprima delle immagini
- **Strumenti di area**: screenshot, registrazione dello schermo, OCR, ricerca inversa per immagini
- **Cheatsheet**: le scorciatoie prese dalla tua config di Niri
- **Controlli multimediali**: player MPRIS completo con più layout
- **OSD**: volume, luminosità e media
- **Riconoscimento brani**: in stile Shazam con SongRec
- **Input vocale**: whisper.cpp in locale se installato, oppure Groq, Gemini o OpenAI collegati

### Sistema

- **Impostazioni grafiche**: configuri tutto senza toccare file
- **GameMode**: spegne gli effetti da solo con le app a schermo intero
- **Aggiornamenti**: `inir update` con rollback, migrazioni e rispetto delle tue modifiche
- **Schermata di blocco** e **schermata di sessione** (esci/riavvia/spegni/sospendi)
- **Agente polkit**, **tastiera a schermo**, **gestione dell'avvio automatico** basata sul file di avvio di niri
- **Kira**: una ragazza gatto in pixel art che gira sui bordi dello schermo, reagisce a quello che fai e ha una modalità caos. Opzionale, con un pacchetto grafico separato di circa 32 MiB in `./setup` › Extras
- **18 lingue** con rilevamento automatico, tra cui indonesiano (`id_ID`) e groenlandese (`kl_GL`)
- **Luce notturna**: programmata o manuale
- **Meteo**: Open-Meteo, con GPS, coordinate manuali o nome della città
- **Gestione della batteria**: soglie configurabili e sospensione automatica al livello critico
- **Suoni degli eventi** con volume generale e un file audio per evento
- **Controllo aggiornamenti**: ti avvisa quando esce una nuova versione

</details>

---

## Avvio rapido

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

L'installer si occupa di dipendenze, configurazione di sistema e tema. Dopo l'installazione, esegui `inir run` per avviare la shell, oppure esci dalla sessione e rientra.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

Altri modi per installare, se `./setup install` non fa per te:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Distribuzioni:** Arch è l'obiettivo principale. Anche Fedora e Debian/Ubuntu hanno un'installazione automatica delle dipendenze che usa prima i repository della distribuzione; le altre seguono la guida generale nella [lista dei pacchetti](https://github.com/snowarch/inir/wiki/PACKAGES). iNiR richiede Qt 6.9 o più recente: Ubuntu 25.10, Fedora 43 e Debian testing o successive.

---

## Scorciatoie

| Tasto | Azione |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Panoramica: cerca app, naviga tra i workspace |
| <kbd>Super</kbd> + <kbd>V</kbd> | Cronologia degli appunti |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Screenshot di un'area |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR di un'area |
| <kbd>Super</kbd> + <kbd>,</kbd> | Impostazioni |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Cambia famiglia di pannelli |
| <kbd>Super</kbd> + <kbd>/</kbd> | Cheatsheet, nel caso dimentichi il resto |

Elenco completo: [Scorciatoie](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Sfondi

Sono inclusi 15 sfondi. Per averne altri, guarda [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), una raccolta curata che funziona bene con Material You.

---

## Documentazione

Tutto quello che serve agli utenti è nella [Wiki](https://github.com/snowarch/inir/wiki) (in inglese).

| Pagina | Contenuto |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Farlo partire |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Aggiornamenti, migrazioni, rollback |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Tutte le scorciatoie |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Comandi per scorciatoie e script |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Ogni dipendenza e perché c'è |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | Cosa si sa che non va, e come aggirarlo |
| [Architecture](../../ARCHITECTURE.md) | Com'è organizzato il codice |

---

## Risoluzione dei problemi

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Guarda [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) prima di aprire una issue. Se preferisci chiedere a qualcuno, sul Discord fai prima.

---

## Contribuire

Vedi [CONTRIBUTING.md](../../CONTRIBUTING.md) per l'ambiente di sviluppo, le convenzioni del codice e come inviare una pull request.

---

## Crediti

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, i dots Hyprland da cui nasce iNiR
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): un fork che ogni tanto ha un'idea davvero buona
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), da cui vengono la barra pill e il look washi e flame
- [**Quickshell**](https://quickshell.outfoxxed.me/): il framework su cui gira
- [**Niri**](https://github.com/YaLTeR/niri): il compositor per cui è fatto

GPL-3.0, come i dots di end-4. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributori</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">Licenza GPL-3.0</a>
</p>
