<p align="center">
  <img src="../images/iris-2.32-principal.webp" alt="iNiR iRiS desktop" width="900">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>Um shell de desktop completo para o Niri, feito com Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.32.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Instalar</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Atalhos</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">Referência IPC</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="../../CONTRIBUTING.md">Contribuir</a>
</p>

<p align="center">
  <sub>
    <a href="../../README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh.md">中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.pt.md">Português</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ko.md">한국어</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.ar.md">العربية</a> · <a href="README.it.md">Italiano</a>
  </sub>
</p>

---

> **Sobre esta tradução:** se algo não ficar claro, a [versão em inglês](../../README.md) é a referência.

---

<details>
<summary><b>🤔 Chegou agora? Clique se não faz ideia do que é tudo isso</b></summary>

### O que é isso?

O iNiR é o seu desktop inteiro. A barra de cima, o dock, as notificações, as configurações, os wallpapers, tudo. Não é um tema nem dotfiles para colar. É um shell completo que roda no Linux.

### Do que eu preciso para usar?

Um compositor. É o que cuida das suas janelas e coloca os pixels na tela. O iNiR é feito para o [Niri](https://github.com/YaLTeR/niri) (um compositor Wayland de tiling). Ainda sobra um pouco de código do Hyprland de quando isto era um fork dos dots do end-4, mas o Niri é o que eu realmente uso e testo.

O shell roda sobre o [Quickshell](https://quickshell.outfoxxed.me/), um framework para criar shells em QML (a linguagem de interface do Qt). Você não precisa saber nada disso para usar: tudo se configura pela interface ou por um arquivo JSON.

### Como tudo se conecta

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

### É estável?

É um projeto pessoal que saiu do controle. Eu uso todo dia, e muita gente do Discord também. Mas às vezes algo quebra, o código é bagunçado em alguns lugares e eu vou aprendendo no caminho.

Se algo não funcionar, `inir doctor` resolve quase tudo. Se não resolver, o Discord é ativo. Só não espere um software polido: é o rice de uma pessoa que outras pessoas também curtiram.

### Por que existe?

Eu queria que meu desktop tivesse uma certa cara e um certo jeito de funcionar, e nada fazia exatamente isso. Começou como os dots de Hyprland do end-4 e virou uma reescrita completa para o Niri com muito mais recursos.

### Palavras que você vai ver por aí

- **Shell**: a camada de interface (barra, painéis, overlays)
- **Compositor**: gerencia as janelas e desenha na tela (Niri, Hyprland, Sway...)
- **Wayland**: o protocolo de tela do Linux (o novo, substitui o X11)
- **QML**: a linguagem declarativa de interface do Qt, em que o iNiR é escrito
- **Material You**: o sistema de cores do Google que tira paletas de uma imagem (é assim que o tema automático funciona)
- **ii / waffle / iRiS**: as três famílias de painéis. ii = estilo Material Design, waffle = estilo Windows 11, iRiS = uma Island que vira o que você abre. `Super+Shift+W` alterna entre elas

</details>

---

## Capturas de tela

<details open>
<summary><b>iRiS</b>: Island, Customize, barra de menu, cards e Dock</summary>

<p align="center">
  <img src="../images/iris-2.31-desktop.webp" alt="iRiS desktop layout" width="49%">
  <img src="../images/iris-2.31-card.webp" alt="iRiS card surface" width="49%">
</p>

<p align="center">
  <img src="../images/iris-2.31-dock.webp" alt="iRiS Dock and edge layout" width="99%">
</p>

</details>

<details open>
<summary><b>Material ii</b>: barra flutuante, sidebars, estética Material Design</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: barra de tarefas embaixo, central de ações, estilo Windows 11</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> Não é para máquinas fracas.
> Mas dá para deixar bem mais leve: desligue efeitos, tire painéis, simplifique o visual. Pelas configurações ou pelo `config.json`, como preferir.

## Recursos

**Três famílias de painéis**, trocadas na hora com `Super+Shift+W`:
- **Material ii**: barra flutuante, sidebars, dock e 9 estilos globais (Material, Cards, Aurora, iNiR, Angel, Regalia, ZZZ, Cookie Shapes, Editorial)
- **Waffle**: barra de tarefas, menu iniciar, central de ações e central de notificações no estilo Windows 11
- **iRiS**: a família principal. Uma Island em qualquer borda da tela que cresce em páginas, cards e painéis, peças que você leva para onde quiser, um Dock em qualquer borda, glass, Themes que redesenham tudo, claro, tinta e escuro, e Customize direto no shell

**Tema automático**. Escolha um wallpaper e tudo se adapta:
- Cores do shell via Material You, levadas para GTK3/4, Qt, terminais, Firefox, Discord e SDDM
- 10 alvos de tema: terminais, editores, navegadores, Spicetify, Steam, Cava e mais
- Presets de tema: Regalia / Regalia Ivory, Gruvbox, Catppuccin, Rosé Pine e os seus

**Feito para o Niri.** O código do Hyprland sobrevive do fork, mas não é testado.

**Kira**, a mascote, mora no seu desktop se você quiser. Vem desligada, e o pacote de arte é baixado à parte.

<details>
<summary><b>Lista completa de recursos</b></summary>

### iRiS

- **A Island**: uma única forma numa borda da tela que responde "o que está acontecendo" e vira a página, o card ou o painel que você abriu, depois se recolhe de novo. Em cima, embaixo, à esquerda ou à direita (`inir iris edge <side>`, ou arraste até lá). Numa lateral ela fica de pé, com o relógio empilhado e bolhas acima e abaixo
- **Barra de menu**: uma faixa fina com seus workspaces, a janela e as peças, com a Island pendurada nela como um notch (`inir iris layout menubar`)
- **Modo barra de largura total** com zonas de início, centro e fim para a Island, os workspaces, a janela em foco, a hora ou qualquer peça (`inir iris zone start|center|end kinds+joined+with+plus`)
- **Peças**: clima, som, microfone, bandeja, notificações, ferramentas, música, VPN, um visualizador, anime (Airing e Continue) e seus próprios apps como bolhas que você deixa na Island, no contorno da tela ou soltas no desktop
- **As peças se juntam ao que tocam**: deixe uma na borda do Dock ou da Island e ela vira parte daquele corpo em vez de flutuar por cima
- **Dock** em qualquer borda (`inir iris dockEdge <side|auto>`); no auto ele fica em frente à Island, e se você mandar um para a borda do outro, eles trocam de lugar
- **Glass** que fosca o wallpaper sob cada superfície e mantém o texto legível mesmo em wallpapers claros ou carregados. O Blur do compositor também existe, mas ainda está em construção, então não julgue ainda
- **Themes**: 20 redesenhos selecionados (Liquid Glass, Frost, Obsidian, Terminal, Neo Tokyo, Twilight, Lume, Sakura, Unit-01 e mais) e os seus como arquivos JSON para compartilhar (`inir iris theme`)
- **Claro, Tinta e Escuro**, cada um com seu tom e seu fosco, e temas de cor (Catppuccin, Nord, Rosé Pine, Tokyo Night…) que seus apps também usam (`inir iris palette`)
- **Forma**: cápsula, redonda, squircle ou quadrada para a Island e o Dock
- **Customize no próprio shell**: toque na Island, no Dock ou numa bolha e as opções saem dali mesmo, com Themes, Look, Pieces e desfazer embaixo da Island (`inir iris edit`). Se preferir, o Studio junta tudo num painel ao lado da tela
- **Central de Controle que você monta**: cada botão rápido compartilhado, o player e cada slider viram células que você arrasta, redimensiona pelo canto e adiciona de uma biblioteca ao lado, com seis layouts iniciais; com o botão direito um controle se expande (`inir iris control edit`)
- **Tela de bloqueio que você ensaia**: o bloqueio real abre editável e sem nada para desbloquear; mova o relógio, o player e o campo de senha, e escolha o que aparece atrás, vídeo incluído (`inir iris lock edit`)

### Tema e aparência

- **9 estilos globais**: Material (sólido), Cards, Aurora (glass com blur), iNiR (inspirado em TUI), Angel (neobrutalismo), Regalia (chassi preto, tinta marfim quente, ferragens champanhe discretas), ZZZ (placas de pôster), Cookie Shapes (formas animadas), Editorial (tipografia de papel e tinta)
- **Cores dinâmicas do wallpaper** via Material You, no sistema todo
- **10 ferramentas de terminal e TUI com tema automático**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **Tema nos apps**: GTK3/4, Qt (via plasma-integration e darkly), Firefox, Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Presets de tema**: Gruvbox, Catppuccin, Rosé Pine e mais, ou crie o seu
- **Wallpapers de vídeo**: mp4/webm/gif com blur opcional, ou o primeiro quadro congelado para economizar
- **Widgets de desktop**: um só design para todos (iRiS, Material, iNstrument ou Readout), pilhas que giram como as do iOS e tinta que acompanha o wallpaper embaixo deles

### Barra

- **6 estilos de barra**: classic, islands, scenic, frame, cápsulas Material 3 e pill
- **Barra pill**: uma ilha central que se transforma e, ao passar o mouse, abre workspaces, lançador, mixer, música, calendário e gravador de tela
- **Layout modular** com editor de arrastar nas configurações, para pôr qualquer módulo em qualquer lugar
- **Barra vertical** para quem quer a borda da tela de volta

### Sidebars e widgets (Material ii)

Sidebar esquerda (gaveta de apps):
- **Chat com IA**: catálogos de modelos ao vivo de Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI e OpenCode
- **YT Music**: player InnerTube sem cookies, com busca, fila, rádio e letras sincronizadas
- **Navegador do Wallhaven**: busque e aplique wallpapers direto
- **Acompanhamento de anime**: integração com AniList e grade de horários
- **Tradutor**: via Gemini ou translate-shell
- **Widgets arrastáveis**: cripto, player, notas rápidas, anéis de status, calendário semanal

Sidebar direita:
- **Calendário** com eventos
- **Central de notificações**
- **Botões rápidos**: WiFi, Bluetooth, luz noturna, Não perturbe, perfis de energia, WARP VPN, EasyEffects
- **Mixer de volume** por app
- **Bluetooth e WiFi**: gerenciamento de dispositivos
- **Pomodoro**, **tarefas**, **calculadora**, **bloco de notas**
- **Monitor do sistema**: CPU, RAM, temperatura

### Ferramentas

- **Overview de workspaces**: adaptado ao modelo de rolagem do Niri, com busca de apps e calculadora
- **Dashboard**: overlay de três colunas configurável com agenda, notificações, tarefas, notas, música e clima
- **Faixa de workspaces na borda**: trilho ao passar o mouse, com prévias ao vivo e reordenação por arrastar
- **Alternador de janelas**: um Alt-Tab animado entre todos os workspaces, opcional agora que o Niri tem o dele
- **Área de transferência**: histórico com busca e prévia de imagens
- **Ferramentas de região**: capturas, gravação de tela, OCR, busca reversa de imagem
- **Cheatsheet**: os atalhos tirados da sua config do Niri
- **Controles de música**: player MPRIS completo com vários layouts
- **OSD**: volume, brilho e música
- **Reconhecimento de música**: no estilo Shazam via SongRec
- **Entrada por voz**: whisper.cpp local quando instalado, ou Groq, Gemini ou OpenAI conectados

### Sistema

- **Configurações gráficas**: ajuste tudo sem mexer em arquivos
- **GameMode**: desliga efeitos sozinho com apps em tela cheia
- **Atualizações**: `inir update` com rollback, migrações e preservação das suas mudanças
- **Tela de bloqueio** e **tela de sessão** (sair/reiniciar/desligar/suspender)
- **Agente polkit**, **teclado na tela**, **gerenciador de inicialização** apoiado no próprio arquivo de startup do niri
- **Kira**: uma garota-gato em pixel art que anda pelas bordas da tela, reage ao que você faz e tem um modo caos. Opcional, com um pacote de arte separado de ~32 MiB em `./setup` › Extras
- **18 idiomas** com detecção automática, incluindo indonésio (`id_ID`) e groenlandês (`kl_GL`)
- **Luz noturna**: agendada ou manual
- **Clima**: Open-Meteo, com GPS, coordenadas manuais ou nome da cidade
- **Bateria**: limites configuráveis e suspensão automática no nível crítico
- **Sons de eventos** com volume geral e um arquivo de áudio por evento
- **Aviso de atualização**: avisa quando sai uma versão nova

</details>

---

## Começo rápido

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

O instalador cuida das dependências, da configuração do sistema e do tema. Depois de instalar, rode `inir run` para iniciar o shell, ou saia da sessão e entre de novo.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

Outras formas de instalar, se `./setup install` não for o que você quer:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Distros:** o Arch é o alvo principal. Fedora e Debian/Ubuntu também têm instalação automática de dependências que usa primeiro os repositórios da distro; as outras seguem o guia geral da [lista de pacotes](https://github.com/snowarch/inir/wiki/PACKAGES). O iNiR precisa do Qt 6.9 ou mais novo: Ubuntu 25.10, Fedora 43 e Debian testing ou posteriores.

---

## Atalhos

| Tecla | Ação |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Overview: buscar apps, navegar pelos workspaces |
| <kbd>Super</kbd> + <kbd>V</kbd> | Histórico da área de transferência |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Captura de uma região |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR de uma região |
| <kbd>Super</kbd> + <kbd>,</kbd> | Configurações |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Trocar de família de painéis |
| <kbd>Super</kbd> + <kbd>/</kbd> | Cheatsheet, caso você esqueça o resto |

Lista completa: [Atalhos](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Wallpapers

15 wallpapers vêm incluídos. Para mais, veja o [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), uma coleção selecionada que combina bem com o Material You.

---

## Documentação

Tudo o que é para usuários está na [Wiki](https://github.com/snowarch/inir/wiki) (em inglês).

| Página | O que tem |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Colocar para rodar |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Atualizações, migrações, rollback |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Todos os atalhos |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Comandos para atalhos e scripts |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Cada dependência e por que ela está ali |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | O que se sabe que falha, e como contornar |
| [Architecture](../../ARCHITECTURE.md) | Como o código é organizado |

---

## Solução de problemas

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Veja [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) antes de abrir uma issue. Se preferir perguntar para alguém, o Discord é mais rápido.

---

## Contribuir

Veja [CONTRIBUTING.md](../../CONTRIBUTING.md) para o ambiente de desenvolvimento, os padrões de código e como enviar um pull request.

---

## Créditos

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, os dots de Hyprland de onde o iNiR saiu
- [**pctrade/end4-pC**](https://github.com/pctrade/end4-pC): um fork que de vez em quando tem uma ideia muito boa
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), de onde vêm a barra pill e o visual washi e flame
- [**Quickshell**](https://quickshell.outfoxxed.me/): o framework sobre o qual ele roda
- [**Niri**](https://github.com/YaLTeR/niri): o compositor para o qual ele é feito

GPL-3.0, igual aos dots do end-4. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contribuidores</a> &bull;
  <a href="../../CHANGELOG.md">Changelog</a> &bull;
  <a href="../../LICENSE">Licença GPL-3.0</a>
</p>
