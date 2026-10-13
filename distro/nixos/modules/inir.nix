{ config, pkgs, lib, inir ? null, ... }:

let
  inirFlake =
    if inir != null then inir
    else ../../..;

  inirNixosModule =
    if inirFlake ? nixosModules && inirFlake.nixosModules ? inir
    then inirFlake.nixosModules.inir
    else import "${inirFlake}/nix/nixos-module.nix";

  inirDeps = import ./inir-deps.nix { inherit pkgs; };
  pythonEnv = lib.findSingle
    (p: lib.hasPrefix "python3-" (p.name or "") && lib.hasSuffix "-env" (p.name or ""))
    (pkgs.python3.withPackages (ps: []))
    null
    inirDeps;

# Los scripts usan `#!/usr/bin/env bash`, que en NixOS no resuelve: bajo systemd --user
    # el PATH no trae bash y el interprete acaba siendo /usr/bin/env. Se fija el bash del store
    # y se envuelve con un PATH propio, en vez de tocar environment.PATH de la unidad (choca
    # con el valor global de NixOS para servicios de usuario).
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
    config.programs.niri.package
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


  versionJsonFile = pkgs.writeText "inir-version.json" ((builtins.toJSON {
    version = inirFlake.shortRev or inirFlake.dirtyShortRev or "2.33.0";
    commit = inirFlake.rev or inirFlake.dirtyRev or "48cdcecb";
    installMode = "package-managed";
    updateStrategy = "package-manager";
    packageName = "inir";
    packageUpdateHint = "nixos-rebuild switch";
  }) + "\n");

  inirPatched = (pkgs.callPackage "${inirFlake}/nix/package.nix" { inherit pkgs; }).overrideAttrs (old: {
    # Adapt iNiR's Arch assumptions to NixOS (idempotent regex rewrites).
    postPatch = (old.postPatch or "") + ''
      cp ${../nix/nixos-postpatch.py} nixos-postpatch.py
      python3 nixos-postpatch.py
      rm -f nixos-postpatch.py
    '';
  });

  mascotPackage = config.programs.inir.mascot.package or (
    if inirFlake != null && builtins.pathExists "${inirFlake}/nix/mascot-package.nix"
    then pkgs.callPackage "${inirFlake}/nix/mascot-package.nix" { inherit pkgs; }
    else null
  );

  inirPackage =
    if (config.programs.inir.mascot.enable or false) && mascotPackage != null
    then pkgs.symlinkJoin {
      name = "inir-with-mascot-${inirPatched.version or "2.33.0"}";
      paths = [ inirPatched mascotPackage ];
      meta = (inirPatched.meta or { }) // {
        description = "iNiR desktop shell with the official Kira mascot art pack integrated";
        homepage = "https://github.com/snowarch/inir";
        license = pkgs.lib.licenses.gpl3Only;
        mainProgram = "inir";
      };
    }
    else inirPatched;

  cfg = config.programs.inir;
# Siembra la config de niri/alacritty solo si no existe. Nunca sobrescribe: a partir
  # de la primera vez el usuario es dueño del fichero, asi niri puede guardar los cambios
  # que haga desde el menu de iRiS (raton, sensibilidad, atajos, focus-ring...).
  niriConfigSeed = pkgs.writeShellApplication {
    name = "niri-config-seed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      seed() {
        local src="$1" dst="$2"
        mkdir -p "$(dirname "$dst")"
        if [[ -e "$dst" ]]; then
          # Ya existe: solo nos aseguramos de que siga siendo escribible. Los ficheros
          # sembrados por la version previa quedaron en 444 y niri no podia guardar nada.
          if [[ ! -w "$dst" ]]; then
            chmod u+w "$dst"
          fi
        else
          install -Dm644 "$src" "$dst"
        fi
      }

      seed ${../niri/config.kdl} "$HOME/.config/niri/config.kdl"
      seed ${../niri/config.d/10-input-and-cursor.kdl} "$HOME/.config/niri/config.d/10-input-and-cursor.kdl"
      seed ${../niri/config.d/20-layout-and-overview.kdl} "$HOME/.config/niri/config.d/20-layout-and-overview.kdl"
      seed ${../niri/config.d/30-window-rules.kdl} "$HOME/.config/niri/config.d/30-window-rules.kdl"
      seed ${../niri/config.d/40-environment.kdl} "$HOME/.config/niri/config.d/40-environment.kdl"
      seed ${../niri/config.d/50-startup.kdl} "$HOME/.config/niri/config.d/50-startup.kdl"
      seed ${../niri/config.d/60-animations.kdl} "$HOME/.config/niri/config.d/60-animations.kdl"
      seed ${../niri/config.d/70-binds.kdl} "$HOME/.config/niri/config.d/70-binds.kdl"
      seed ${../niri/config.d/80-layer-rules.kdl} "$HOME/.config/niri/config.d/80-layer-rules.kdl"
      seed ${../niri/config.d/90-user-extra.kdl} "$HOME/.config/niri/config.d/90-user-extra.kdl"
    '';
  };

in
{
  options.programs.inir = {
    familyTransitionAnimation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        # Animada por defecto: el ciclo Super+Shift+W debe verse, no parpadear.
        # El riesgo aceptado es un segfault ocasional de Qt 6.11 al desmontar
        # layer-shell; inir.service tiene Restart=on-failure, así que cuesta un
        # reinicio del shell y ningún dato. Ponlo en false para volver al
        # cambio de familia con reinicio (sin animación).
        default = true;
        description = ''
          Animar el cambio de familia de paneles en Qt 6.11, aceptando el riesgo de
          segfault. Upstream desactiva la transición en Qt 6.11 porque el desmontaje de
          layer-shell puede tumbar el shell, y en su lugar reinicia el proceso: la familia
          cambia de golpe, sin animación. Activado por defecto aquí para que el atajo del
          ciclo de familias se vea animado; con false vuelve el comportamiento upstream
          (reinicio, sin animación). Si el shell se cae, systemd lo reinicia solo y no se
          pierde nada; mientras Qt no llegue a 6.12 no hay forma de tener la animación sin
          este riesgo.
        '';
      };
    };

    colorSync = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar el servicio de sincronización automática de colores Material You con Niri, terminales compatibles y GTK.";
      };
    };

    screenRecording = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar el script record-screen para grabación de pantalla Wayland con audio integrado.";
      };
    };

    hardware = {
      brightnessControl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar soporte i2c y ddcutil para control de brillo en monitores externos.";
      };
    };

    niri = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Habilitar e integrar el compositor Wayland Niri para iNiR.";
      };
      autoDeployConfig = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Desplegar automáticamente la configuración modular de Niri si no existe en el directorio del usuario.";
      };
      defaultTerminal = lib.mkOption {
        type = lib.types.str;
        default = "alacritty";
        description = "Emulador de terminal preferido (mantenido por compatibilidad con configuraciones existentes).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Habilitar el módulo oficial de iNiR con detección de iconos corregida y soporte para mascota
    programs.inir = {
      service.compositor = "niri";
      package = lib.mkDefault inirPackage;
      extraPackages = inirDeps;
    };

    # Paquetes disponibles globalmente en el sistema para herramientas y scripts de iNiR
    environment.systemPackages = inirDeps
      ++ [ inirSync ]
      ++ (lib.optional cfg.colorSync.enable niriSyncColors)
      ++ (lib.optional cfg.screenRecording.enable recordScreen);


    # Variables de entorno globales para que cualquier shell o launcher localice el runtime.
    # INIR_VENV / ILLOGICAL_IMPULSE_VIRTUAL_ENV NO se declaran a nivel de sistema: apuntan
    # al python env de iNiR que se materializa por usuario en ~/.local/state/quickshell/.venv
    # (ver systemd.user.tmpfiles.rules y niri/config.d/40-environment.kdl). Un symlink dentro
    # de /run/current-system/sw/share/quickshell es imposible (el store de Nix es de solo lectura).
    environment.variables = {
      INIR_SYSTEM_RUNTIME_DIR = "/run/current-system/sw/share/quickshell/inir";
      INIR_FALLBACK_SYSTEM_RUNTIME_DIR = "/run/current-system/sw/share/quickshell/inir";
    };

    # Control de hardware para brillo de monitores externos mediante ddcutil
    hardware.i2c.enable = lib.mkDefault cfg.hardware.brightnessControl;

    # Rutas estándar FHS y temas de iconos para compatibilidad de scripts
    systemd.tmpfiles.rules = [
      "L+ /bin/cat - - - - ${pkgs.coreutils}/bin/cat"
      "d /usr/share 0755 root root -"
      "L+ /usr/share/icons - - - - /run/current-system/sw/share/icons"
      "L+ /usr/share/quickshell - - - - /run/current-system/sw/share/quickshell"
    ];

    # Habilitar Niri y dconf (la preferencia dark/light la gestiona dinámicamente el tema de iNiR)
    programs.niri.enable = lib.mkDefault cfg.niri.enable;
    programs.dconf.enable = lib.mkDefault true;

    # Elevación de privilegios gráfica (Polkit) para aplicaciones en Wayland
    security.polkit.enable = lib.mkDefault true;
    systemd.user.services.polkit-kde-authentication-agent-1 = {
      description = "polkit-kde-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    # Integración XDG Desktop Portal para captura de pantalla / WebRTC / diálogos en Niri
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
      config.niri.default = [ "gnome" "gtk" ];
    };

    # Soporte Bluetooth y daemon Blueman para el widget de iNiR
    hardware.bluetooth.enable = lib.mkDefault true;
    services.blueman.enable = lib.mkDefault true;

    # Demonio UPower para widget de batería y suspensión
    services.upower.enable = lib.mkDefault true;

    # Variables de entorno para el servicio user de systemd
    systemd.user.services.inir = {
      environment = {
        INIR_VENV = "%h/.local/state/quickshell/.venv";
        ILLOGICAL_IMPULSE_VIRTUAL_ENV = "%h/.local/state/quickshell/.venv";
      }
      // lib.optionalAttrs cfg.familyTransitionAnimation.enable {
        # Opt in to the animated family transition on Qt 6.11; see the option.
        INIR_FAMILY_ANIMATION_ON_QT611 = "1";
      };
    };

    # Servicio de usuario para sincronización automática de colores con Niri / Alacritty / GTK
    systemd.user.services.niri-sync-colors = lib.mkIf cfg.colorSync.enable {
      description = "Sync Niri colors and iNiR wallpaper with generated theme data";
      wantedBy = [ "graphical-session.target" "default.target" ];
      after = [ "inir.service" ];
      # The watcher locates python3, gsettings, niri and inotifywait through the PATH
      # baked into its wrapper. Overriding environment.PATH here would collide with
      # the value NixOS sets globally for user units.
      environment = {
        XDG_CONFIG_HOME = "%h/.config";
        XDG_STATE_HOME = "%h/.local/state";
        INIR_VENV = "%h/.local/state/quickshell/.venv";
        ILLOGICAL_IMPULSE_VIRTUAL_ENV = "%h/.local/state/quickshell/.venv";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${niriSyncColors}/bin/niri-sync-colors --watch";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Reglas de usuario para asegurar symlinks correctos y compatibilidad permanente
    systemd.user.tmpfiles.rules = [
      "d %h/.local/bin 0755 - - -"
      "d %h/.local/state/quickshell 0755 - - -"
      "L+ %h/.local/state/quickshell/.venv - - - - ${pythonEnv}"
      "L+ %h/.local/bin/inir - - - - /run/current-system/sw/bin/inir"
      "L+ %h/.local/bin/inir-sync - - - - ${inirSync}/bin/inir-sync"
      "L+ %h/.local/bin/niri-sync-colors - - - - ${niriSyncColors}/bin/niri-sync-colors"

      "L+ %h/.local/bin/record-screen - - - - ${recordScreen}/bin/record-screen"
      "L+ %h/.local/bin/pactl - - - - ${pkgs.pulseaudio}/bin/pactl"
      "d %h/.config/inir 0755 - - -"
      "L+ %h/.config/inir/version.json - - - - ${versionJsonFile}"
      "d %h/.config/illogical-impulse 0755 - - -"
      "L+ %h/.config/illogical-impulse/version.json - - - - ${versionJsonFile}"
      "d %h/.local/share/icons 0755 - - -"
      "L+ %h/.icons - - - - %h/.local/share/icons"
      "d %h/.config/quickshell 0755 - - -"
      "L+ %h/.config/quickshell/inir - - - - /run/current-system/sw/share/quickshell/inir"
      "d %h/.config/mpv/scripts 0755 - - -"
      "L+ %h/.config/mpv/scripts/mpris.so - - - - ${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so"
      # Los dotfiles originales de iNiR (docs/INSTALL.md: `cp -r dots/.config/* ~/.config/`).
      # switchwall.sh lee TEMPLATE_DIR="$XDG_CONFIG_HOME/matugen"; sin este directorio el
      # generador se salta --render-templates y GTK/terminales/KDE nunca reciben la paleta.
      "d %h/.config/fontconfig/conf.d 0755 - - -"
    ]
    ++ lib.optionals cfg.colorSync.enable [
      "C+ %h/.config/matugen/config.toml - - - - ${inirPatched}/share/quickshell/inir/dots/.config/matugen/config.toml"
      "C+ %h/.config/matugen/templates.json - - - - ${inirPatched}/share/quickshell/inir/dots/.config/matugen/templates.json"
      "C+ %h/.config/matugen/templates - - - - ${inirPatched}/share/quickshell/inir/dots/.config/matugen/templates"
      # Las superficies de iNiR son translúcidas: sin esto el texto tiene franjas de subpíxel.
      "C+ %h/.config/fontconfig/conf.d/90-inir-shell.conf - - - - ${inirPatched}/share/quickshell/inir/dots/.config/fontconfig/conf.d/90-inir-shell.conf"
    ]
    ++ lib.optionals cfg.niri.autoDeployConfig [
      "d %h/.config/niri 0755 - - -"
      "d %h/.config/niri/config.d 0755 - - -"
    ];

    # La config de Niri NO se despliega con tmpfiles "C+": ese tipo copia
    # conservando el modo del store (444) y sobrescribe en cada arranque. Con eso niri
    # no podia guardar nada, el menu de ajustes de iRiS se perdia cada cambio (raton,
    # sensibilidad, atajos...) y el siguiente login lo revertia.
    #
    # Ahora se siembran una sola vez con permisos 644 y nunca se vuelven a tocar: el
    # usuario es el dueño. Para actualizar la base hay que editar el fichero destino,
    # no este repositorio.
    systemd.user.services.niri-config-seed = lib.mkIf cfg.niri.autoDeployConfig {
      description = "Seed iNiR's niri config once; the user owns it afterwards";
      before = [ "niri.service" ];
      wantedBy = [ "default.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${niriConfigSeed}/bin/niri-config-seed";
      };
    };
  };
}
