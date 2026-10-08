<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Un shell de bureau complet pour Niri, construit sur Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Installer</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Raccourcis</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">Référence IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuer</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **À propos de cette traduction :** en cas de doute, la [version anglaise](../../README.md) fait référence.

---

<details>
<summary><b>🤔 Nouveau ici ? Clique si tu ne sais pas du tout ce que c'est</b></summary>

### C'est quoi ?

iNiR, c'est tout ton bureau. La barre en haut, le dock, les notifications, les réglages, les fonds d'écran, tout. Pas un thème, pas des dotfiles à copier. Un shell complet qui tourne sous Linux.

### De quoi j'ai besoin ?

D'un compositeur. C'est lui qui gère tes fenêtres et affiche les pixels à l'écran. iNiR est fait pour [Niri](https://github.com/YaLTeR/niri) (un compositeur Wayland en tiling). Il reste un peu de vieux code Hyprland de l'époque où c'était un fork des dots d'end-4, mais c'est Niri que j'utilise et que je teste vraiment.

Le shell tourne sur [Quickshell](https://quickshell.outfoxxed.me/), un framework pour créer des shells en QML (le langage d'interface de Qt). Pas besoin de connaître tout ça pour l'utiliser : tout se règle depuis l'interface ou un fichier JSON.

### Comment tout s'articule

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

### C'est stable ?

C'est un projet perso qui a pris des proportions. Je l'utilise tous les jours, et beaucoup de monde sur le Discord aussi. Mais des trucs cassent parfois, le code est brouillon par endroits et j'apprends en avançant.

Si quelque chose ne marche pas, `inir doctor` règle la plupart des problèmes. Sinon, le Discord est actif. N'attends juste pas un logiciel poli : c'est le rice d'une personne que d'autres ont fini par aimer.

### Pourquoi ça existe ?

Je voulais que mon bureau ait une certaine allure et fonctionne d'une certaine façon, et rien ne faisait exactement ça. C'est parti des dots Hyprland d'end-4 et c'est devenu une réécriture complète pour Niri, avec beaucoup plus de fonctionnalités.

### Les mots que tu vas croiser

- **Shell** : la couche d'interface (barre, panneaux, overlays)
- **Compositeur** : gère les fenêtres et dessine à l'écran (Niri, Hyprland, Sway...)
- **Wayland** : le protocole d'affichage de Linux (le nouveau, qui remplace X11)
- **QML** : le langage d'interface déclaratif de Qt, celui d'iNiR
- **Material You** : le système de couleurs de Google qui tire des palettes d'une image (c'est ça, le thème automatique)
- **ii / waffle / iRiS** : les trois familles de panneaux. ii = style Material Design, waffle = style Windows 11, iRiS = une Island qui devient ce que tu ouvres. `Super+Shift+W` passe de l'une à l'autre

</details>

---

## Captures d'écran

<details open>
<summary><b>iRiS</b> : Island, Customize, barre de menus, cards et Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b> : barre flottante, sidebars, esthétique Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> : barre des tâches en bas, centre d'actions, style Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> Pas pour les machines modestes.
> Tu peux quand même beaucoup l'alléger : coupe les effets, retire des panneaux, simplifie le design. Dans les réglages ou `config.json`, comme tu préfères.

## Fonctionnalités

**Trois familles de panneaux**, interchangeables à la volée avec `Super+Shift+W` :
- **Material ii** : barre flottante, sidebars, dock et 9 styles globaux (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle** : barre des tâches, menu démarrer, centre d'actions et centre de notifications façon Windows 11
- **iRiS** : la famille phare. Une Island sur n'importe quel bord de l'écran qui s'ouvre en pages, cards et panneaux, des pièces que tu déplaces, un Dock sur n'importe quel bord, du glass, des Themes qui redessinent tout, clair, encre et sombre, et Customize directement sur le shell

**Thème automatique**. Choisis un fond d'écran et tout s'adapte :
- Couleurs du shell via Material You, propagées à GTK3/4, Qt, terminaux, Firefox, Discord, SDDM
- 10 cibles de thème : terminaux, éditeurs, navigateurs, Spicetify, Steam, Cava et plus
- Préréglages de thème : Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine et les tiens

**Fait pour Niri.** Le code Hyprland survit du fork mais n'est pas testé.

**Kira**, la mascotte, vit sur ton bureau si tu le veux. Désactivée par défaut, son pack graphique se télécharge à part.

<details>
<summary><b>Liste complète des fonctionnalités</b></summary>

### iRiS

- **L'Island** : une seule forme sur un bord de l'écran qui répond à « qu'est-ce qui se passe » et devient la page, la card ou le panneau que tu as ouvert, puis se replie. En haut, en bas, à gauche ou à droite (`inir iris edge <side>`, ou glisse-la). Sur un côté elle se dresse, avec l'horloge empilée et des bulles au-dessus et en dessous
- **Barre de menus** : une bande fine avec tes workspaces, la fenêtre et les pièces, l'Island suspendue dessous comme une encoche (`inir iris layout menubar`)
- **Mode barre pleine largeur** avec des zones début, centre et fin pour l'Island, les workspaces, la fenêtre active, l'heure ou n'importe quelle pièce (`inir iris zone start|center|end kinds+joined+with+plus`)
- **Pièces** : météo, son, micro, zone de notification, notifications, outils, musique, VPN, un visualiseur, anime (Airing et Continue) et tes propres apps, en bulles à poser sur l'Island, sur le contour de l'écran ou librement sur le bureau
- **Les pièces rejoignent ce qu'elles touchent** : pose-en une sur le bord du Dock ou de l'Island et elle fait partie de ce corps au lieu de flotter par-dessus
- **Dock** sur n'importe quel bord (`inir iris dockEdge <side|auto>`) ; en auto il se place en face de l'Island, et si tu envoies l'un sur le bord de l'autre, ils échangent leurs places
- **Glass** qui dépolit le fond d'écran sous chaque surface et garde le texte lisible, même sur des fonds clairs ou chargés. Le flou du compositeur existe aussi, mais il est encore en chantier, donc ne le juge pas tout de suite
- **Themes** : 20 refontes choisies (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 et d'autres) plus les tiens en fichiers JSON à partager (`inir iris theme`)
- **Clair, Encre et Sombre**, chacun avec sa teinte et son dépoli, et des thèmes de couleur (Catppuccin, Nord, Rosé Pine, Tokyo Night…) que tes apps portent aussi (`inir iris palette`)
- **Forme** : capsule, ronde, squircle ou carrée pour l'Island et le Dock
- **Customize sur le shell** : touche l'Island, le Dock ou une bulle et ses options en sortent directement, avec Themes, Look, Pieces et annuler sous l'Island (`inir iris edit`). Si tu préfères, Studio regroupe tout dans un panneau à côté de l'écran
- **Un Control Center que tu composes** : chaque bouton rapide partagé, le lecteur et chaque curseur deviennent des cellules que tu déplaces, redimensionnes par un coin et ajoutes depuis une bibliothèque à côté, avec six dispositions de départ ; un clic droit déplie un contrôle (`inir iris control edit`)
- **Un écran de verrouillage que tu répètes** : le vrai verrouillage s'ouvre en édition, sans rien à déverrouiller ; déplace l'horloge, le lecteur et le champ de connexion, et choisis ce qui passe derrière, vidéo comprise (`inir iris lock edit`)

### Thème et apparence

- **9 styles globaux** : Material (plein), Cards, Aurora (glass flouté), iNiR (inspiré des TUI), Angel (néo-brutalisme), Regalia (châssis noir, encre ivoire chaude, finitions champagne discrètes), ZZZ (plaques d'affiche), Cookie Shapes (formes animées), Editorial (typographie papier et encre)
- **Couleurs dynamiques du fond d'écran** via Material You, dans tout le système
- **10 outils de terminal et TUI thématisés automatiquement** : foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **Thème des apps** : GTK3/4, Qt (via plasma-integration et darkly), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Préréglages de thème** : Gruvbox, Catppuccin, Rosé Pine et d'autres, ou crée le tien
- **Fonds d'écran vidéo** : mp4/webm/gif avec flou optionnel, ou première image figée pour les performances
- **Widgets de bureau** : un seul design pour tous (iRiS, Material, iNstrument ou Readout), des piles qui tournent comme sur iOS et une encre qui suit le fond d'écran en dessous

### Barre

- **6 styles de barre** : classic, islands, scenic, frame, capsules Material 3 et pill
- **Barre pill** : une île centrale qui se transforme et s'ouvre au survol sur les workspaces, le lanceur, le mixeur, la musique, le calendrier et un enregistreur d'écran
- **Disposition modulaire** avec un éditeur par glisser-déposer dans les réglages, pour placer n'importe quel module n'importe où
- **Barre verticale** pour qui veut récupérer le bord de l'écran

### Sidebars et widgets (Material ii)

Sidebar gauche (tiroir d'apps) :
- **Chat IA** : catalogues de modèles en direct pour Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI et OpenCode
- **YT Music** : lecteur InnerTube sans cookies, avec recherche, file d'attente, radio et paroles synchronisées
- **Navigateur Wallhaven** : cherche et applique des fonds d'écran directement
- **Suivi d'anime** : intégration AniList avec vue du planning
- **Traducteur** : via Gemini ou translate-shell
- **Widgets déplaçables** : crypto, lecteur, notes rapides, anneaux d'état, calendrier de la semaine

Sidebar droite :
- **Calendrier** avec les événements
- **Centre de notifications**
- **Boutons rapides** : WiFi, Bluetooth, lumière nocturne, Ne pas déranger, profils d'énergie, WARP VPN, EasyEffects
- **Mixeur de volume** par app
- **Bluetooth et WiFi** : gestion des appareils
- **Pomodoro**, **tâches**, **calculatrice**, **bloc-notes**
- **Moniteur système** : CPU, RAM, température

### Outils

- **Vue d'ensemble des workspaces** : adaptée au défilement de Niri, avec recherche d'apps et calculatrice
- **Dashboard** : overlay configurable en trois colonnes avec agenda, notifications, tâches, notes, musique et météo
- **Bande de workspaces en bord d'écran** : rail au survol avec aperçus en direct et réorganisation par glisser
- **Sélecteur de fenêtres** : un Alt-Tab animé sur tous les workspaces, optionnel maintenant que Niri a le sien
- **Presse-papiers** : historique avec recherche et aperçu des images
- **Outils de région** : captures, enregistrement d'écran, OCR, recherche d'image inversée
- **Cheatsheet** : les raccourcis lus dans ta config Niri
- **Contrôles média** : lecteur MPRIS complet avec plusieurs dispositions
- **OSD** : volume, luminosité et média
- **Reconnaissance de chansons** : façon Shazam via SongRec
- **Saisie vocale** : whisper.cpp en local s'il est installé, ou Groq, Gemini ou OpenAI connectés

### Système

- **Réglages graphiques** : tout se configure sans toucher aux fichiers
- **GameMode** : coupe les effets tout seul pour les apps en plein écran
- **Mises à jour** : `inir update` avec rollback, migrations et conservation de tes changements
- **Écran de verrouillage** et **écran de session** (déconnexion/redémarrage/arrêt/veille)
- **Agent polkit**, **clavier à l'écran**, **gestionnaire de démarrage** appuyé sur le fichier de démarrage de niri
- **Kira** : une fille-chat en pixel art qui se balade sur les bords de l'écran, réagit à ce que tu fais et a un mode chaos. Optionnelle, avec un pack graphique séparé d'environ 32 Mio dans `./setup` › Extras
- **18 langues** avec détection automatique, dont l'indonésien (`id_ID`) et le groenlandais (`kl_GL`)
- **Lumière nocturne** : programmée ou manuelle
- **Météo** : Open-Meteo, avec GPS, coordonnées manuelles ou nom de ville
- **Batterie** : seuils réglables et mise en veille automatique au niveau critique
- **Sons d'événements** avec un volume général et un fichier audio par événement
- **Vérification des mises à jour** : te prévient quand une nouvelle version sort

</details>

---

## Démarrage rapide

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

L'installateur s'occupe des dépendances, de la configuration système et du thème. Après l'installation, lance `inir run` pour démarrer le shell, ou déconnecte-toi puis reconnecte-toi.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

D'autres façons d'installer, si `./setup install` ne te convient pas :

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Distributions :** Arch est la cible principale. Fedora et Debian/Ubuntu ont aussi une installation automatique des dépendances qui passe d'abord par les dépôts de la distribution ; les autres suivent le guide général de la [liste des paquets](https://github.com/snowarch/inir/wiki/PACKAGES). iNiR demande Qt 6.9 ou plus récent : Ubuntu 25.10, Fedora 43 et Debian testing ou ultérieures.

---

## Raccourcis

| Touche | Action |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Vue d'ensemble : chercher des apps, naviguer entre les workspaces |
| <kbd>Super</kbd> + <kbd>V</kbd> | Historique du presse-papiers |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Capture d'une région |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR d'une région |
| <kbd>Super</kbd> + <kbd>,</kbd> | Réglages |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Changer de famille de panneaux |
| <kbd>Super</kbd> + <kbd>/</kbd> | Cheatsheet, au cas où tu oublies le reste |

Liste complète : [Raccourcis](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Fonds d'écran

15 fonds d'écran sont inclus. Pour plus, va voir [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), une collection choisie qui marche bien avec Material You.

---

## Documentation

Tout ce qui concerne les utilisateurs est dans le [Wiki](https://github.com/snowarch/inir/wiki) (en anglais).

| Page | Contenu |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Le faire tourner |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Mises à jour, migrations, rollback |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Tous les raccourcis |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Commandes pour raccourcis et scripts |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Chaque dépendance et pourquoi elle est là |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | Ce qu'on sait cassé, et comment le contourner |
| [Architecture](../../ARCHITECTURE.md) | Comment le code est organisé |

---

## Dépannage

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Regarde [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) avant d'ouvrir une issue. Si tu préfères demander à quelqu'un, le Discord est plus rapide.

---

## Contribuer

Voir [CONTRIBUTING.md](../../CONTRIBUTING.md) pour l'environnement de développement, les conventions de code et l'envoi de pull requests.

---

## Crédits

- [**end-4**](https://github.com/end-4/dots-hyprland) : illogical-impulse, les dots Hyprland dont iNiR est issu
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC) : un fork qui a de temps en temps une vraie bonne idée
- [**Gakuseei**](https://github.com/Gakuseei) : [Ricelin](https://github.com/Gakuseei/Ricelin), d'où viennent la barre pill et le look washi et flame
- [**Quickshell**](https://quickshell.outfoxxed.me/) : le framework sur lequel il tourne
- [**Niri**](https://github.com/YaLTeR/niri) : le compositeur pour lequel il est fait

GPL-3.0, comme les dots d'end-4. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributeurs</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">Licence GPL-3.0</a>
</p>
