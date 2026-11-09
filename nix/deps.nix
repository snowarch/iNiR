# What iNiR needs on NixOS, dep by dep as sdata/deps.toml names them: the same things setup installs on Arch.
#   pkgs    on the shell's PATH and installed for the person (apps, tools, icons, themes, Qt plugins)
#   fonts   fonts.packages / home.packages
#   qml     QML modules for nixpkgs' Quickshell, the runtime where qs-rs has no build (it carries its own Qt)
#   nixos   what the NixOS module turns on for it (services, groups, PAM): a note, the module holds the code
# The flake's `deps` check fails when deps.toml has a dep this table lacks, or this one names a dep it dropped.
{ pkgs }:

let
  inherit (pkgs) lib;
  kde = pkgs.kdePackages;

  # the Google Fonts families iNiR's styles name (Arch gets them from the AUR, Fedora downloads them)
  googleFonts = pkgs.google-fonts.override {
    fonts = [ "GoogleSansFlex" "Oxanium" "Gabarito" "SpaceGrotesk" "ReadexPro" ];
  };

  table = {
    quickshell = { pkgs = [ pkgs.quickshell ]; };
    niri = { nixos = "programs.niri"; };
    qt6 = { qml = with pkgs.qt6; [ qt5compat qtdeclarative qtimageformats qtmultimedia qtsvg qtwayland ]; };
    quickshell-libs = { };
    kde-qml = { pkgs = [ kde.kdialog ]; qml = [ kde.kirigami.unwrapped kde.syntax-highlighting ]; };
    qt-theming = { pkgs = [ kde.qt6ct kde.plasma-integration kde.frameworkintegration kde.kdecoration kde.breeze-icons ]; nixos = "qt.platformTheme kde"; };
    kvantum = { pkgs = [ kde.qtstyleplugin-kvantum ]; };
    plasma-integration = { };
    kconfig = { pkgs = [ kde.kconfig ]; };
    polkit = { nixos = "security.polkit"; };
    portals = { nixos = "xdg.portal: gnome and gtk"; };
    network = { pkgs = [ pkgs.networkmanagerapplet ]; nixos = "networking.networkmanager, services.gnome.gnome-keyring"; };
    void-session = { };
    power-profiles = { nixos = "services.power-profiles-daemon"; };
    login = { nixos = "services.displayManager.sddm"; };
    files = { pkgs = [ pkgs.nautilus ]; };
    terminal = { pkgs = [ pkgs.kitty ]; };
    fish = { pkgs = [ pkgs.fish ]; nixos = "programs.fish"; };
    xwayland = { pkgs = [ pkgs.xwayland-satellite ]; };
    wallpaper-daemon = { pkgs = [ pkgs.awww ]; };
    thumbnails = { };
    icon-themes = { pkgs = with pkgs; [ hicolor-icon-theme adwaita-icon-theme papirus-icon-theme ]; };
    mission-center = { pkgs = [ pkgs.mission-center ]; };
    browser-media = { pkgs = [ kde.plasma-browser-integration ]; };
    base-tools = {
      pkgs = with pkgs; [
        bash coreutils curl findutils gawk git gnugrep gnused jq procps python3 ripgrep rsync unzip util-linux
        xdg-user-dirs xdg-utils wl-clipboard libnotify wlsunset
      ];
    };
    cliphist = { pkgs = [ pkgs.cliphist ]; };
    gum = { pkgs = [ pkgs.gum ]; };
    prompt = { pkgs = with pkgs; [ starship eza ]; };
    translate = { pkgs = [ pkgs.translate-shell ]; };
    build-tools = { };
    pipewire = { pkgs = with pkgs; [ pipewire pulseaudio wireplumber ]; nixos = "services.pipewire"; };
    media-control = { pkgs = with pkgs; [ playerctl pavucontrol ]; };
    cava = { pkgs = [ pkgs.cava ]; };
    equalizer = { pkgs = with pkgs; [ easyeffects lsp-plugins ]; };
    # yt-dlp-ejs is a Python module nixpkgs' yt-dlp carries; deno runs its challenges
    player = { pkgs = with pkgs; [ (mpv.override { scripts = [ mpvScripts.mpris ]; }) yt-dlp deno socat ]; };
    songrec = { pkgs = [ pkgs.songrec ]; };
    input = { pkgs = with pkgs; [ upower wtype ydotool fprintd ]; nixos = "services.upower, programs.ydotool, the input group"; };
    ydotool = { };
    backlight = { pkgs = with pkgs; [ brightnessctl ddcutil geoclue2 ]; nixos = "hardware.i2c, services.geoclue2, the video group"; };
    idle = { pkgs = with pkgs; [ swayidle swaylock ]; nixos = "security.pam.services.swaylock"; };
    screenshot = { pkgs = with pkgs; [ grim slurp imagemagick ]; };
    imagemagick-void = { };
    hyprpicker = { pkgs = [ pkgs.hyprpicker ]; };
    calculator = { pkgs = [ pkgs.libqalculate ]; };
    bluetooth = { pkgs = [ pkgs.blueman ]; nixos = "hardware.bluetooth, services.blueman"; };
    gowall = { pkgs = [ pkgs.gowall ]; };
    flatpak = { };
    ocr = {
      pkgs = [
        (pkgs.tesseract.override {
          enableLanguages = [ "eng" "spa" "rus" "jpn" "jpn_vert" "chi_sim" "chi_sim_vert" "chi_tra" "chi_tra_vert" ];
        })
      ];
    };
    ocr-vertical-models = { };
    recording = { pkgs = with pkgs; [ swappy wf-recorder ffmpeg ]; };
    swappy = { };
    ffmpeg-core = { pkgs = [ pkgs.ffmpeg ]; };
    fonts = {
      pkgs = with pkgs; [ fontconfig glib adw-gtk3 capitaine-cursors ];
      fonts = with pkgs; [ noto-fonts-color-emoji dejavu_fonts liberation_ttf roboto material-symbols nerd-fonts.jetbrains-mono ];
    };
    emoji-core = { fonts = [ pkgs.noto-fonts-color-emoji ]; };
    aur-fonts = {
      pkgs = [ pkgs.whitesur-icon-theme ];
      fonts = with pkgs; [ roboto-flex rubik twemoji-color-font googleFonts ];
    };
    darkly = { pkgs = [ pkgs.darkly ]; };
    darkly-build = { };
    qt-avif = { pkgs = [ kde.kimageformats ]; };
    fonts-download = { };
    theme-download = { };
  };

  field = name: lib.unique (lib.concatMap (dep: dep.${name} or [ ]) (lib.attrValues table));
in
{
  inherit table;
  packages = field "pkgs";
  fonts = field "fonts";
  qml = field "qml";

  # every dep of sdata/deps.toml has a line here, and none is left over
  missing =
    let
      wanted = map (dep: dep.name) (builtins.fromTOML (builtins.readFile ../sdata/deps.toml)).dep;
      have = lib.attrNames table;
    in
    {
      notHere = lib.subtractLists have wanted;
      leftOver = lib.subtractLists wanted have;
    };
}
