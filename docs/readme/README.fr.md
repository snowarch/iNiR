<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Un shell de bureau complet pour Niri, construit avec Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">Installation</a> &bull;
  <a href="../KEYBINDS.md">Raccourcis</a> &bull;
  <a href="../IPC.md">Référence IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuer</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **À propos de la traduction :** Traduction communautaire. En cas de doute, consultez la [version anglaise](../../README.md).

---

<details>
<summary><b>🤔 Nouveau ici ? Clique si tu ne sais pas ce que c'est</b></summary>

### C'est quoi ?

iNiR c'est tout ton bureau. La barre en haut, le dock, les notifications, les paramètres, les fonds d'écran, tout. C'est pas un thème, c'est pas des dotfiles à copier-coller. C'est un shell complet qui tourne sur Linux.

### Qu'est-ce qu'il faut ?

Un compositeur. C'est ce qui gère tes fenêtres et met les pixels à l'écran. iNiR est fait pour [Niri](https://github.com/YaLTeR/niri) (un compositeur Wayland en tiling). Y'a du vieux code Hyprland de quand c'était un fork des dots de end-4, mais c'est Niri que je teste et utilise vraiment.

Le shell tourne sur [Quickshell](https://quickshell.outfoxxed.me/), un framework pour créer des shells en QML (le langage UI de Qt). T'as pas besoin de connaître ça pour l'utiliser, tout se configure via la GUI ou un fichier JSON.

### Comment tout s'emboîte

```
tes apps
   ↓
iNiR (shell : barre, sidebars, dock, notifications, paramètres...)
   ↓
Quickshell (fait tourner les shells QML)
   ↓
Niri (compositeur : fenêtres, rendu)
   ↓
Wayland → GPU
```

### C'est stable ?

C'est un projet perso qui m'a échappé. Je l'utilise tous les jours, plein de gens sur Discord aussi. Mais des fois ça casse, le code est bordélique par endroits, j'apprends en avançant.

Si un truc marche pas, `inir doctor` règle la plupart des problèmes. Le Discord est actif si ça suffit pas. Attends pas un logiciel fini, c'est le rice d'une personne que d'autres ont aimé.

### Pourquoi ça existe ?

Je voulais que mon bureau ressemble et fonctionne d'une certaine façon, et rien d'autre le faisait exactement. Ça a commencé comme les dots Hyprland de end-4, c'est devenu une réécriture complète pour Niri avec bien plus de features.

### Mots que tu vas voir

- **Shell** : la couche UI (barre, panneaux, overlays)
- **Compositeur** : gère les fenêtres, dessine à l'écran (Niri, Hyprland, Sway...)
- **Wayland** : protocole d'affichage Linux (le nouveau, remplace X11)
- **QML** : langage déclaratif UI de Qt, iNiR est écrit dedans
- **Material You** : système de couleurs Google qui génère des palettes à partir d'images (c'est comme ça que marche l'auto-theming)
- **ii / waffle** : les deux styles de panneaux. ii = vibes Material Design, waffle = vibes Windows 11. `Super+Shift+W` pour changer

</details>

---

## Captures d'écran

<details open>
<summary><b>Material ii</b> — barre flottante, barres latérales, esthétique Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — barre des tâches en bas, centre d'actions, ambiance Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Fonctionnalités

**Deux familles de panneaux**, interchangeables à la volée avec `Super+Shift+W` :
- **Material ii** — barre flottante, barres latérales, dock, 5 styles visuels (material, cards, aurora, inir, angel)
- **Waffle** — barre des tâches style Windows 11, menu démarrer, centre d'actions, centre de notifications

**Thématisation automatique** — choisissez un fond d'écran et tout s'adapte :
- Couleurs du shell via Material You, propagées vers GTK3/4, Qt, terminaux, Firefox, Discord, SDDM
- 10 outils de terminal auto-thématisés (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Préréglages de thèmes : Gruvbox, Catppuccin, Rosé Pine, et personnalisé

**Compositeur** — conçu pour Niri.

<details>
<summary><b>Liste complète des fonctionnalités</b></summary>

### Thèmes et apparence

Choisissez un fond d'écran et tout le système suit — shell, apps GTK/Qt, terminaux, Firefox, Discord, écran de connexion SDDM. Entièrement automatique.

- **5 styles visuels** — Material (uni), Cards, Aurora (flou de verre), iNiR (inspiré TUI), Angel (néo-brutalisme)
- **Couleurs dynamiques du fond d'écran** via Material You — propagées à tout le système
- **10 outils de terminal auto-thématisés** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **Thématisation d'apps** — GTK3/4, Qt (via plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Préréglages de thèmes** — Gruvbox, Catppuccin, Rosé Pine, et plus — ou créez le vôtre
- **Fonds d'écran vidéo** — mp4/webm/gif avec flou optionnel, ou première image figée pour les performances
- **Thème SDDM de connexion** — couleurs Material You synchronisées avec votre fond d'écran
- **Widgets de bureau** — horloge (plusieurs styles), météo, contrôles média sur la couche fond d'écran

### Barres latérales et widgets (Material ii)

Barre latérale gauche (tiroir d'apps) :
- **Chat IA** — Gemini, Mistral, OpenRouter, ou modèles locaux via Ollama
- **YT Music** — lecteur complet avec recherche, file d'attente et contrôles
- **Navigateur Wallhaven** — cherchez et appliquez des fonds d'écran directement
- **Suivi d'anime** — intégration AniList avec calendrier de sorties
- **Flux Reddit** — parcourez les subreddits en ligne
- **Traducteur** — via Gemini ou translate-shell
- **Widgets déplaçables** — crypto, lecteur média, notes rapides, anneaux de statut, calendrier hebdomadaire

Barre latérale droite :
- **Calendrier** avec intégration d'événements
- **Centre de notifications**
- **Bascules rapides** — WiFi, Bluetooth, veilleuse, DND, profils d'alimentation, WARP VPN, EasyEffects
- **Mixeur de volume** — contrôle par application
- **Bluetooth et WiFi** — gestion des appareils
- **Timer pomodoro**, **liste de tâches**, **calculatrice**, **bloc-notes**
- **Moniteur système** — CPU, RAM, température

### Outils

- **Vue d'ensemble des espaces de travail** — adaptée au modèle de défilement Niri, avec recherche d'apps et calculatrice
- **Sélecteur de fenêtres** — Alt+Tab entre tous les espaces de travail
- **Gestionnaire de presse-papiers** — historique avec recherche et aperçu d'images
- **Outils de région** — captures d'écran, enregistrement, OCR, recherche d'image inversée
- **Aide-mémoire** — visualiseur de raccourcis extraits de votre config Niri
- **Contrôles média** — lecteur MPRIS complet avec plusieurs préréglages de disposition
- **Affichage à l'écran** — OSD de volume, luminosité et média
- **Reconnaissance de musique** — identification style Shazam via SongRec
- **Recherche vocale** — enregistrez et cherchez via Gemini

### Système

- **Paramètres GUI** — configurez tout sans toucher aux fichiers
- **GameMode** — désactive automatiquement les effets pour les apps en plein écran
- **Mises à jour auto** — `inir update` avec retour arrière, migrations et préservation des modifications utilisateur
- **Écran de verrouillage** et **écran de session** (déconnexion/redémarrage/arrêt/veille)
- **Agent polkit**, **clavier virtuel**, **gestionnaire de démarrage automatique**
- **9 langues** — détection automatique, avec génération de traductions assistée par IA
- **Veilleuse** — programmée ou manuelle
- **Météo** — Open-Meteo, supporte GPS, coordonnées manuelles ou nom de ville
- **Gestion de batterie** — seuils configurables, mise en veille automatique en niveau critique
- **Vérificateur de mises à jour** — notifie quand de nouvelles versions sont disponibles

</details>

---

## Démarrage rapide

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactif — demande avant chaque étape
./setup install -y    # automatique — sans questions
```

L'installateur gère les dépendances, la config système, la thématisation — tout. Après l'installation, lancez `inir run` pour démarrer le shell, ou déconnectez-vous et reconnectez-vous.

```bash
inir run                        # lancer le shell
inir settings                   # ouvrir les paramètres GUI
inir logs                       # vérifier les logs d'exécution
inir doctor                     # auto-diagnostic et réparation
inir update                     # pull + migrations + redémarrage
```

**Distributions supportées :** Arch (installateur automatisé). Les autres distributions peuvent installer manuellement — voir [PACKAGES.md](../PACKAGES.md).

| Méthode | Commande |
|--------|---------|
| Installation système | `sudo make install && inir run` |
| Menu TUI | `./setup` |
| Retour arrière | `./setup rollback` |

---

## Raccourcis

| Touche | Action |
|-----|--------|
| `Super+Space` | Vue d'ensemble — recherche d'apps, navigation entre espaces |
| `Alt+Tab` | Sélecteur de fenêtres |
| `Super+V` | Historique du presse-papiers |
| `Super+Shift+S` | Capture de région |
| `Super+Shift+X` | OCR de région |
| `Super+,` | Paramètres |
| `Super+Shift+W` | Changer de famille de panneaux |

Liste complète : [KEYBINDS.md](../KEYBINDS.md)

---

## Fonds d'écran

15 fonds d'écran sont inclus. Pour en avoir plus, consultez [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — une collection qui fonctionne bien avec le pipeline Material You.

---

## Documentation

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | Guide d'installation |
| [SETUP.md](../SETUP.md) | Commandes setup — mises à jour, migrations, retour arrière |
| [KEYBINDS.md](../KEYBINDS.md) | Tous les raccourcis clavier |
| [IPC.md](../IPC.md) | Cibles IPC pour scripts et raccourcis personnalisés |
| [PACKAGES.md](../PACKAGES.md) | Chaque dépendance et pourquoi elle est là |
| [LIMITATIONS.md](../LIMITATIONS.md) | Limitations connues et solutions |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Vue d'ensemble de l'architecture technique |

---

## Dépannage

```bash
inir logs                       # vérifiez les logs — la réponse est souvent là
inir restart                    # redémarrer le shell
inir repair                     # doctor + redémarrage + vérification de logs filtrée
./setup doctor                  # auto-diagnostic et réparation des problèmes courants
./setup rollback                # annuler la dernière mise à jour
```

Consultez [LIMITATIONS.md](../LIMITATIONS.md) avant d'ouvrir une issue.

---

## Contribuer

Voir [CONTRIBUTING.md](../../CONTRIBUTING.md) pour la configuration de développement, les patterns de code et les directives de PR.

---

## Crédits

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse original pour Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — le framework qui fait tourner ce shell
- [**Niri**](https://github.com/YaLTeR/niri) — le compositeur Wayland à tiling défilant

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributeurs</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">Licence MIT</a>
</p>
