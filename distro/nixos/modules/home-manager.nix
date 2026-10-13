{ config, pkgs, lib, inir ? null, ... }:

let
  cfg = config.programs.inir;
  inirDeps = import ./inir-deps.nix { inherit pkgs; };
  pythonEnv = lib.findSingle
    (p: lib.hasPrefix "python3-" (p.name or "") && lib.hasSuffix "-env" (p.name or ""))
    (pkgs.python3.withPackages (ps: []))
    null
    inirDeps;

  shellScript = path: name: extraPath:
      let
        script = pkgs.writeTextFile {
          inherit name;
          executable = true;
          destination = "/bin/${name}";
          text = "#!${pkgs.bash}/bin/bash\n" + builtins.readFile path;
        };
      in
      pkgs.runCommand name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
        makeWrapper ${script}/bin/${name} $out/bin/${name} \
          --prefix PATH : ${lib.makeBinPath extraPath}
      '';

  niriSyncColors = shellScript ../scripts/niri-sync-colors "niri-sync-colors" [
    pkgs.bash
    pkgs.coreutils
    pkgs.python3
    pkgs.glib
    pkgs.util-linux
    pkgs.inotify-tools
    pkgs.procps
    pkgs.jq
    pkgs.niri
  ];
  recordScreen = shellScript ../scripts/record-screen "record-screen" [
    pkgs.bash
    pkgs.coreutils
    pkgs.wf-recorder
    pkgs.slurp
    pkgs.imagemagick
    pkgs.pulseaudio
    pkgs.procps
  ];
  inirSync = shellScript ../scripts/inir-sync "inir-sync" [
    pkgs.bash
    pkgs.coreutils
    pkgs.git
    pkgs.jq
    pkgs.systemd
    pkgs.nix
  ];
in
{
  options.programs.inir = {
    enable = lib.mkEnableOption "iNiR desktop shell and Niri integration for Home Manager";

    colorSync = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic Material You background palette synchronization service.";
      };
    };

    autoDeployConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically deploy Niri modular configuration (~/.config/niri/config.d).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inirSync
      niriSyncColors
      recordScreen
    ] ++ inirDeps;


    # Deploy modular Niri configuration
    xdg.configFile = lib.mkIf cfg.autoDeployConfig {
      "niri/config.kdl".source = ../niri/config.kdl;
      "niri/config.d/10-input-and-cursor.kdl".source = ../niri/config.d/10-input-and-cursor.kdl;
      "niri/config.d/20-layout-and-overview.kdl".source = ../niri/config.d/20-layout-and-overview.kdl;
      "niri/config.d/30-window-rules.kdl".source = ../niri/config.d/30-window-rules.kdl;
      "niri/config.d/40-environment.kdl".source = ../niri/config.d/40-environment.kdl;
      "niri/config.d/50-startup.kdl".source = ../niri/config.d/50-startup.kdl;
      "niri/config.d/60-animations.kdl".source = ../niri/config.d/60-animations.kdl;
      "niri/config.d/70-binds.kdl".source = ../niri/config.d/70-binds.kdl;
      "niri/config.d/80-layer-rules.kdl".source = ../niri/config.d/80-layer-rules.kdl;
      "niri/config.d/90-user-extra.kdl".source = ../niri/config.d/90-user-extra.kdl;
    };

    # Systemd user service for color synchronization
    systemd.user.services.niri-sync-colors = lib.mkIf cfg.colorSync.enable {
      Unit = {
        Description = "Sync Niri colors and iNiR wallpaper with generated theme data";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${niriSyncColors}/bin/niri-sync-colors --watch";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" "default.target" ];
      };
    };

    # Symlink Python venv for Quickshell
    home.file.".local/state/quickshell/.venv".source = pythonEnv;
  };
}
