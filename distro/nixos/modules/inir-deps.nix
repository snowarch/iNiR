# Everything iNiR needs on NixOS that isn't pulled in automatically.
# `inir doctor` reports most of these as "missing" because it assumes an
# Arch-style package manager; on NixOS they have to be declared here.
#
# Every package below was added to fix a REAL crash or missing feature,
# confirmed by hand against `inir logs --full` / `journalctl --user -u inir`.
# The "optional" block at the end is taste, not requirement — trim freely.

{ pkgs }:

with pkgs; [
  # --- Core shell / compositor glue ---
  git                      # version control and flake management
  curl                     # downloads and API requests (tesseract models, OCR, weather)
  go                       # builds inir-washi (scripts/colors/washi): sin toolchain la paleta de iRiS queda atorada en el fallback
  rsync                    # sync operations for shell themes, backups and presets
  glib                     # provides `gsettings` for GNOME/GTK desktop theme sync
  util-linux               # provides `flock`, used by niri-sync-colors watcher
  procps                   # provides `pgrep`, `pkill`, `pidof`, `kill`
  inotify-tools            # provides `inotifywait`, used by systemd/niri-sync-colors.service
  quickshell              # the actual runtime iNiR's `inir` launcher wraps
  xwayland-satellite       # Xwayland support under niri (non-native apps)
  psmisc                   # provides `killall`, used by iNiR conflict dialog and process management
  swaylock
  swayidle
  wl-clipboard
  cliphist
  libnotify
  wlsunset
  xdg-user-dirs
  xdg-utils
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  gnome-keyring
  fish                    # some of iNiR's scripts shell out to fish specifically
  gum
  uv                       # fast Python package / project runner
  ripgrep
  jq

  # --- Qt/QML modules — without these, quickshell fails with
  #     'module "org.kde.X" is not installed' and the bar/background never render ---
  kdePackages.qt5compat
  kdePackages.kirigami
  kdePackages.qtmultimedia   # required for video wallpapers; without it they fall back to a blurry static thumbnail
  kdePackages.syntax-highlighting
  kdePackages.kdialog
  kdePackages.plasma-integration
  kdePackages.plasma-browser-integration
  kdePackages.kconfig
  kdePackages.kde-cli-tools
  kdePackages.qt6ct
  qt6Packages.qtstyleplugin-kvantum
  darkly

  # --- Wallpapers / color pipeline ---
  awww                      # default hardware-accelerated wallpaper backend ('awww'/'awww-daemon'); without it iNiR falls back to the internal renderer
  matugen                   # the actual engine that generates the Material You palette
  gowall                    # wallpaper processing and palette conversion used in switchwall.sh
  (python3.withPackages (ps: with ps; [
    pip
    materialyoucolor
    material-color-utilities
    pillow
    evdev
    numpy
    psutil
    pygobject3
    pycairo
    loguru
    click
    websockets
    ytmusicapi
    secretstorage
    opencv4                 # provides cv2 for wallpaper scheme & region detection (scheme_for_image.py, find_regions.py)
    tqdm                    # progress reporting for thumbnail generator (thumbgen.py)
    yt-dlp                  # cookie extraction and streaming backend for YouTube Music
    kde-material-you-colors # KDE/Qt color palette synchronization
  ]))

  # --- Screenshots / OCR / screen recording / audio ---
  grim
  slurp
  swappy
  imagemagick             # provides `magick`; regionSelector crops the grim capture with it
  tesseract
  wf-recorder
  ffmpeg
  pulseaudio               # provides `pactl` and `parec`; needed for audio mixing & music recognition
  songrec                  # audio recognition (Shazam client) used by musicRecognition/recognize-music.sh

  # --- System controls the shell's widgets call ---
  brightnessctl
  ddcutil                  # external monitor brightness over DDC/CI
  playerctl                # media keys / MPRIS control used in niri/config.kdl
  wireplumber              # provides `wpctl`, required for audio device control and query
  hyprpicker               # color picker tool used by inir
  upower
  blueman
  networkmanagerapplet
  pavucontrol

  # --- Fonts the shell's icons/UI actually depend on ---
  nerd-fonts.jetbrains-mono
  material-symbols          # the icon font used throughout iNiR's UI — do not remove
  papirus-icon-theme        # desktop icon theme
  adw-gtk3                  # provides adw-gtk3-dark to ensure GTK3/4 apps render in dark mode
  nautilus                  # default file manager bound to Mod+E in niri/config.kdl

  # ===========================================================================
  # OPTIONAL — features you may not use. Safe to delete any of these lines.
  # ===========================================================================
  wtype                     # simulated keyboard input, used by a couple of automation features
  ydotool
  geoclue2                  # location for the weather widget
  fprintd                   # fingerprint unlock — only relevant if your laptop has a sensor
  libqalculate               # calculator widget backend
  translate-shell            # translate widget
  socat                      # used by a couple of IPC helper scripts
  mission-center              # system monitor GUI, launched from the dashboard
  ani-cli                     # anime streaming CLI used by inir-ani
  lsp-plugins                 # audio effect plugins, only relevant if you use easyeffects/cava
  cava
  easyeffects
  mpv
  mpvScripts.mpris             # media-key/MPRIS integration for the YouTube Music widget
  deno                        # JavaScript runtime required by yt-dlp / InnerTube for YouTube Music
  ffmpegthumbnailer           # Video thumbnail extraction
  zenity                      # GUI dialog fallback for scripts
]

