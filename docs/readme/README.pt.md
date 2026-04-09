<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Um shell de desktop completo para Niri, feito com Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="../INSTALL.md">Instalar</a> &bull;
  <a href="../KEYBINDS.md">Atalhos</a> &bull;
  <a href="../IPC.md">Referência IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuir</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Sobre a tradução:** Tradução da comunidade. Se algo não ficou claro, consulte a [versão em inglês](../../README.md).

---

<details>
<summary><b>🤔 Chegou agora? Clica aqui se não sabe o que é isso</b></summary>

### O que é isso?

iNiR é o teu desktop inteiro. A barra no topo, o dock, notificações, configurações, wallpapers, tudo. Não é um tema, não são dotfiles pra copiar e colar. É um shell completo que roda no Linux.

### O que preciso pra usar?

Um compositor. É o que gerencia janelas e coloca pixels na tela. iNiR foi feito pro [Niri](https://github.com/YaLTeR/niri) (um compositor Wayland de tiling). Tem código velho do Hyprland de quando isso era um fork dos dots do end-4, mas o que realmente testo e uso é Niri.

O shell roda no [Quickshell](https://quickshell.outfoxxed.me/), um framework pra fazer shells em QML (linguagem de UI do Qt). Não precisa saber nada disso pra usar, tudo se configura pela GUI ou um JSON.

### Como tudo conecta

```
teus apps
   ↓
iNiR (shell: barra, sidebars, dock, notificações, settings...)
   ↓
Quickshell (roda shells QML)
   ↓
Niri (compositor: janelas, renderização)
   ↓
Wayland → GPU
```

### É estável?

É um projeto pessoal que saiu do controle. Uso todo dia, muita gente no Discord também. Mas às vezes quebra, código tá bagunçado em partes, vou aprendendo enquanto faço.

Se algo não funcionar, `inir doctor` arruma a maioria. Discord tá ativo se isso não resolver. Não espera software polido, isso é o rice de uma pessoa que outros curtiram.

### Por que existe?

Queria que meu desktop tivesse uma cara e funcionasse de um jeito, e nada mais fazia exatamente isso. Começou como os dots do end-4 pro Hyprland, virou uma reescrita completa pro Niri com muito mais features.

### Palavras que vais ver

- **Shell**: a camada de UI (barra, painéis, overlays)
- **Compositor**: gerencia janelas, desenha na tela (Niri, Hyprland, Sway...)
- **Wayland**: protocolo de display do Linux (o novo, substitui X11)
- **QML**: linguagem declarativa de UI do Qt, iNiR é escrito nisso
- **Material You**: sistema de cores do Google que gera paletas de imagens (assim funciona o auto-theming)
- **ii / waffle**: os dois estilos de painel. ii = vibe Material Design, waffle = vibe Windows 11. `Super+Shift+W` alterna

</details>

---

## Capturas de tela

<details open>
<summary><b>Material ii</b> — barra flutuante, sidebars, estética Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — barra de tarefas na parte inferior, centro de ações, visual Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Funcionalidades

**Duas famílias de painéis**, alternáveis em tempo real com `Super+Shift+W`:
- **Material ii** — barra flutuante, sidebars, dock, 5 estilos visuais (material, cards, aurora, inir, angel)
- **Waffle** — barra de tarefas estilo Windows 11, menu iniciar, centro de ações, centro de notificações

**Tematização automática** — escolha um wallpaper e tudo se adapta:
- Cores do shell via Material You, propagadas para GTK3/4, Qt, terminais, Firefox, Discord, SDDM
- 10 ferramentas de terminal com tema automático (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Presets de temas: Gruvbox, Catppuccin, Rosé Pine, e personalizado

**Compositor** — feito para Niri.

<details>
<summary><b>Lista completa de funcionalidades</b></summary>

### Temas e aparência

Escolha um wallpaper e o sistema inteiro acompanha — shell, apps GTK/Qt, terminais, Firefox, Discord, tela de login SDDM. Tudo automático.

- **5 estilos visuais** — Material (sólido), Cards, Aurora (blur de vidro), iNiR (inspirado em TUI), Angel (neo-brutalismo)
- **Cores dinâmicas do wallpaper** via Material You — propagadas para todo o sistema
- **10 ferramentas de terminal com tema automático** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **Tematização de apps** — GTK3/4, Qt (via plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Presets de temas** — Gruvbox, Catppuccin, Rosé Pine, e mais — ou crie o seu
- **Wallpapers de vídeo** — mp4/webm/gif com blur opcional, ou primeiro frame congelado para performance
- **Tema SDDM de login** — cores Material You sincronizadas com seu wallpaper
- **Widgets de desktop** — relógio (vários estilos), clima, controles de mídia na camada de wallpaper

### Sidebars e widgets (Material ii)

Sidebar esquerdo (gaveta de apps):
- **Chat IA** — Gemini, Mistral, OpenRouter, ou modelos locais via Ollama
- **YT Music** — player completo com busca, fila e controles
- **Navegador Wallhaven** — busque e aplique wallpapers diretamente
- **Anime tracker** — integração com AniList e visualização de agenda
- **Feed do Reddit** — navegue subreddits inline
- **Tradutor** — via Gemini ou translate-shell
- **Widgets arrastáveis** — cripto, media player, notas rápidas, status rings, calendário semanal

Sidebar direito:
- **Calendário** com integração de eventos
- **Centro de notificações**
- **Toggles rápidos** — WiFi, Bluetooth, luz noturna, DND, perfis de energia, WARP VPN, EasyEffects
- **Mixer de volume** — controle por app
- **Bluetooth e WiFi** — gerenciamento de dispositivos
- **Timer pomodoro**, **lista de tarefas**, **calculadora**, **bloco de notas**
- **Monitor do sistema** — CPU, RAM, temperatura

### Ferramentas

- **Visão geral de workspaces** — adaptado ao modelo de scroll do Niri, com busca de apps e calculadora
- **Alternador de janelas** — Alt+Tab entre todos os workspaces
- **Gerenciador de área de transferência** — histórico com busca e preview de imagens
- **Ferramentas de região** — capturas, gravação de tela, OCR, busca reversa de imagens
- **Cheatsheet** — visualizador de atalhos extraídos da config do Niri
- **Controles de mídia** — player MPRIS completo com múltiplos presets de layout
- **On-screen display** — OSD de volume, brilho e mídia
- **Reconhecimento de músicas** — identificação estilo Shazam via SongRec
- **Busca por voz** — grave e busque via Gemini

### Sistema

- **Configurações GUI** — configure tudo sem editar arquivos
- **GameMode** — desativa efeitos automaticamente com apps em tela cheia
- **Atualizações automáticas** — `inir update` com rollback, migrações e preservação de mudanças do usuário
- **Tela de bloqueio** e **tela de sessão** (logout/reboot/shutdown/suspend)
- **Agente polkit**, **teclado na tela**, **gerenciador de autostart**
- **9 idiomas** — detecção automática, com geração de traduções assistida por IA
- **Luz noturna** — agendada ou manual
- **Clima** — Open-Meteo, suporte a GPS, coordenadas manuais ou nome da cidade
- **Gerenciamento de bateria** — limiares configuráveis, auto-suspend em nível crítico
- **Verificador de atualizações** — notifica quando há novas versões

</details>

---

## Início rápido

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interativo — pergunta antes de cada passo
./setup install -y    # automático — sem perguntas
```

O instalador cuida de dependências, configuração do sistema, tematização — tudo. Após instalar, rode `inir run` para iniciar o shell, ou faça logout e login novamente.

```bash
inir run                        # iniciar o shell
inir settings                   # abrir configurações GUI
inir logs                       # verificar logs de runtime
inir doctor                     # auto-diagnosticar e corrigir
inir update                     # pull + migrações + reiniciar
```

**Distros suportadas:** Arch (instalador automatizado). Outras distros podem instalar manualmente — veja [PACKAGES.md](../PACKAGES.md).

| Método | Comando |
|--------|---------|
| Instalação de sistema | `sudo make install && inir run` |
| Menu TUI | `./setup` |
| Rollback | `./setup rollback` |

---

## Atalhos

| Tecla | Ação |
|-----|--------|
| `Super+Space` | Visão geral — buscar apps, navegar workspaces |
| `Alt+Tab` | Alternador de janelas |
| `Super+V` | Histórico da área de transferência |
| `Super+Shift+S` | Captura de região |
| `Super+Shift+X` | OCR de região |
| `Super+,` | Configurações |
| `Super+Shift+W` | Alternar família de painéis |

Lista completa: [KEYBINDS.md](../KEYBINDS.md)

---

## Wallpapers

15 wallpapers vêm incluídos. Para mais, confira [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — uma coleção curada que funciona bem com o pipeline Material You.

---

## Documentação

| | |
|---|---|
| [INSTALL.md](../INSTALL.md) | Guia de instalação |
| [SETUP.md](../SETUP.md) | Comandos do setup — updates, migrações, rollback |
| [KEYBINDS.md](../KEYBINDS.md) | Todos os atalhos de teclado |
| [IPC.md](../IPC.md) | Alvos IPC para scripting e atalhos customizados |
| [PACKAGES.md](../PACKAGES.md) | Cada dependência e por que está ali |
| [LIMITATIONS.md](../LIMITATIONS.md) | Limitações conhecidas e soluções |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Visão geral da arquitetura técnica |

---

## Solução de problemas

```bash
inir logs                       # verifique os logs — a resposta geralmente está lá
inir restart                    # reiniciar o shell
inir repair                     # doctor + reinício + verificação de logs filtrada
./setup doctor                  # auto-diagnosticar e corrigir problemas comuns
./setup rollback                # desfazer a última atualização
```

Verifique [LIMITATIONS.md](../LIMITATIONS.md) antes de abrir uma issue.

---

## Contribuir

Veja [CONTRIBUTING.md](../../CONTRIBUTING.md) para setup de desenvolvimento, padrões de código e diretrizes de PR.

---

## Créditos

- [**end-4**](https://github.com/end-4/dots-hyprland) — illogical-impulse original para Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — o framework que alimenta este shell
- [**Niri**](https://github.com/YaLTeR/niri) — o compositor Wayland de tiling com scroll

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contribuidores</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">Licença MIT</a>
</p>
