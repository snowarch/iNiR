#!/usr/bin/env bash
# scripts/setup/_development.sh
# Internal backend for development-environment discovery and mutation.
#
# Search metadata lives in defaults/dev-environments.json. This file is
# intentionally private so it is not exposed as a generic /setup action.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

readonly MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
readonly MISE_CACHE_DIR="${MISE_CACHE_DIR:-$HOME/.cache/mise}"
readonly ENV_IDS=(rails node bun deno go php laravel symfony python elixir phoenix rust java zig dotnet ocaml clojure scala docker-dbs)

declare -A ENV_LABELS=(
    [rails]="Ruby on Rails"
    [node]="Node.js"
    [bun]="Bun"
    [deno]="Deno"
    [go]="Go"
    [php]="PHP"
    [laravel]="Laravel"
    [symfony]="Symfony"
    [python]="Python"
    [elixir]="Elixir"
    [phoenix]="Phoenix"
    [rust]="Rust"
    [java]="Java"
    [zig]="Zig"
    [dotnet]=".NET"
    [ocaml]="OCaml"
    [clojure]="Clojure"
    [scala]="Scala"
    [docker-dbs]="Docker Databases"
)

usage() {
    printf 'Usage: %s status | %s install <environment> | %s remove <environment>\n' \
        "${BASH_SOURCE[0]}" "${BASH_SOURCE[0]}" "${BASH_SOURCE[0]}"
    printf 'Environments: %s\n' "${ENV_IDS[*]}"
}

valid_environment() {
    local id="$1"
    local candidate
    for candidate in "${ENV_IDS[@]}"; do
        [[ "$candidate" == "$id" ]] && return 0
    done
    return 1
}

mise_runtime_present() {
    [[ -n "$(compgen -G "$MISE_DATA_DIR/installs/$1/*" || true)" ]]
}

remove_mise_runtime() {
    local tool="$1"

    if have_cmd mise; then
        # Remove both the global selector and every installed version. The
        # explicit tree cleanup handles runtimes left behind by older mise
        # versions or interrupted uninstalls.
        mise unuse --global "$tool" 2>/dev/null || true
        mise uninstall --all "$tool" 2>/dev/null || true
    fi
    rm -rf -- "$MISE_DATA_DIR/installs/$tool" "$MISE_CACHE_DIR/$tool"
}

system_runtime_package() {
    local tool="$1" executable package
    have_cmd pacman || return 1
    executable="$(command -v "$tool" 2>/dev/null || true)"
    [[ "$executable" == /usr/bin/* ]] || return 1
    package="$(pacman -Qo "$executable" 2>/dev/null | awk '{print $5}')"
    case "$tool:$package" in
        deno:deno|bun:bun|bun:bun-bin) printf '%s\n' "$package"; return 0 ;;
    esac
    return 1
}

remove_system_runtime() {
    local tool="$1" package
    package="$(system_runtime_package "$tool" || true)"
    [[ -n "$package" ]] || return 0
    sudo pacman -Rns --noconfirm "$package"
}

docker_container_present() {
    local target="$1"
    have_cmd docker || return 1
    local name
    while IFS= read -r name; do
        [[ "$name" == "$target" ]] && return 0
    done < <(docker ps -a --format '{{.Names}}' 2>/dev/null || true)
    return 1
}

docker_database_present() {
    docker_container_present mysql8 || docker_container_present postgres18 \
        || docker_container_present redis || docker_container_present mongodb \
        || docker_container_present mariadb11 || docker_container_present mssql
}

environment_status() {
    case "$1" in
        rails) mise_runtime_present ruby ;;
        node|go|python|elixir|java|zig|dotnet|clojure|scala) mise_runtime_present "$1" ;;
        bun|deno) mise_runtime_present "$1" || system_runtime_package "$1" >/dev/null ;;
        php) have_cmd php ;;
        laravel) [[ -x "$HOME/.config/composer/vendor/bin/laravel" ]] ;;
        symfony) have_cmd symfony ;;
        phoenix) compgen -G "$HOME/.mix/archives/phx_new*" >/dev/null ;;
        rust) [[ -d "$HOME/.rustup" ]] ;;
        ocaml) [[ -d "${OPAMROOT:-$HOME/.opam}" ]] ;;
        docker-dbs) docker_database_present ;;
        *) return 1 ;;
    esac
}

status_all() {
    local id state
    for id in "${ENV_IDS[@]}"; do
        if ! is_arch_like; then
            state="unsupported"
        elif environment_status "$id"; then
            state="installed"
        else
            state="missing"
        fi
        printf '%s\t%s\n' "$id" "$state"
    done
}

require_arch() {
    if ! is_arch_like; then
        setup_fail "Development environment setup currently supports Arch-based systems only."
        setup_finish_pause
        exit 1
    fi
}

ensure_mise() {
    if ! have_cmd mise; then
        setup_progress 1 2 "Installing mise"
        install_arch mise
    fi
    have_cmd mise || { setup_fail "mise is not available after installation"; return 1; }
}

install_node() {
    ensure_mise
    mise use --global node@latest
}

install_php() {
    install_arch php composer php-sqlite xdebug

    local bashrc="$HOME/.bashrc"
    if [[ ! -f "$bashrc" ]] || ! grep -Fq 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' "$bashrc"; then
        printf '\nexport PATH="$HOME/.config/composer/vendor/bin:$PATH"\n' >> "$bashrc"
    fi
    export PATH="$HOME/.config/composer/vendor/bin:$PATH"

    local php_ini_path="/etc/php/php.ini"
    local ext
    local extensions_to_enable=(bcmath intl iconv openssl pdo_sqlite pdo_mysql)
    sudo sed -i \
        -e 's/^;zend_extension=xdebug.so/zend_extension=xdebug.so/' \
        -e 's/^;xdebug.mode=debug/xdebug.mode=debug/' \
        /etc/php/conf.d/xdebug.ini
    for ext in "${extensions_to_enable[@]}"; do
        sudo sed -i "s/^;extension=${ext}/extension=${ext}/" "$php_ini_path"
    done
}

install_docker_databases() {
    local options=(MySQL PostgreSQL Redis MongoDB MariaDB MSSQL)
    local choices
    if have_cmd gum; then
        choices="$(printf '%s\n' "${options[@]}" | gum choose --no-limit --header 'Select databases to install' || true)"
    else
        choices=""
        printf 'Install Docker databases with gum for multi-select.\n' >&2
        read -r -p 'Enter database names separated by spaces (or leave empty to cancel): ' choices
    fi
    [[ -n "$choices" ]] || return 0

    local db
    for db in $choices; do
        case "$db" in
            MySQL)
                docker_container_present mysql8 || sudo docker run -d --restart unless-stopped -p 127.0.0.1:3306:3306 --name=mysql8 -e MYSQL_ROOT_PASSWORD= -e MYSQL_ALLOW_EMPTY_PASSWORD=true mysql:8.4
                ;;
            PostgreSQL)
                docker_container_present postgres18 || sudo docker run -d --restart unless-stopped -p 127.0.0.1:5432:5432 --name=postgres18 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:18
                ;;
            MariaDB)
                docker_container_present mariadb11 || sudo docker run -d --restart unless-stopped -p 127.0.0.1:3306:3306 --name=mariadb11 -e MARIADB_ROOT_PASSWORD= -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=true mariadb:11.8
                ;;
            Redis)
                docker_container_present redis || sudo docker run -d --restart unless-stopped -p 127.0.0.1:6379:6379 --name=redis redis:7
                ;;
            MongoDB)
                docker_container_present mongodb || sudo docker run -d --restart unless-stopped -p 127.0.0.1:27017:27017 --name=mongodb -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=admin123 mongo:noble
                ;;
            MSSQL)
                docker_container_present mssql || sudo docker run -d --restart unless-stopped -p 127.0.0.1:1433:1433 --name=mssql -e MSSQL_PID=Developer -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='@dmin123' mcr.microsoft.com/mssql/server:2022-CU12-ubuntu-22.04
                ;;
            *)
                printf 'Unknown database: %s\n' "$db" >&2
                return 1
                ;;
        esac
    done
}

remove_docker_databases() {
    local known=(mysql8 postgres18 redis mongodb mariadb11 mssql)
    local existing=()
    local id
    for id in "${known[@]}"; do
        docker_container_present "$id" && existing+=("$id")
    done
    ((${#existing[@]})) || { printf 'No managed Docker database containers found.\n'; return 0; }

    local choices
    if have_cmd gum; then
        choices="$(printf '%s\n' "${existing[@]}" | gum choose --no-limit --header 'Select databases to remove' || true)"
    else
        choices="${existing[*]}"
        read -r -p "Enter container names separated by spaces [${choices}]: " input
        [[ -n "$input" ]] && choices="$input"
    fi
    [[ -n "$choices" ]] || return 0
    for id in $choices; do
        valid=0
        for known_id in "${known[@]}"; do
            [[ "$id" == "$known_id" ]] && valid=1
        done
        (( valid )) || { printf 'Skipping unmanaged container: %s\n' "$id" >&2; continue; }
        sudo docker rm -f -- "$id"
    done
}

install_environment() {
    local id="$1"
    local label="${ENV_LABELS[$id]}"
    setup_init "development-$id" "Setup $label"
    require_arch
    setup_progress 1 2 "Installing $label"

    case "$id" in
        rails)
            install_arch libyaml
            ensure_mise
            mise settings add ruby.compile false
            mise settings add idiomatic_version_file_enable_tools ruby
            mise use --global ruby@latest
            printf 'gem: --no-document\n' > "$HOME/.gemrc"
            mise x ruby -- gem install rails --no-document
            ;;
        node) install_node ;;
        bun) ensure_mise; mise use --global bun@latest ;;
        deno) ensure_mise; mise use --global deno@latest ;;
        go) ensure_mise; mise use --global go@latest ;;
        php) install_php ;;
        laravel) install_php; install_node; composer global require laravel/installer ;;
        symfony) install_php; install_arch -- symfony-cli ;;
        python)
            ensure_mise
            mise use --global python@latest
            have_cmd uv || curl -fsSL https://astral.sh/uv/install.sh | sh
            ;;
        elixir)
            ensure_mise
            mise use --global erlang@latest
            mise use --global elixir@latest
            mise x elixir -- mix local.hex --force
            ;;
        phoenix)
            ensure_mise
            mise use --global erlang@latest
            mise use --global elixir@latest
            mise x elixir -- mix local.hex --force
            mise x elixir -- mix local.rebar --force
            mise x elixir -- mix archive.install hex phx_new --force
            ;;
        rust) have_cmd rustup || bash -c "$(curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs)" -- -y ;;
        java) ensure_mise; mise use --global java@latest ;;
        zig) ensure_mise; mise use --global zig@latest; mise use --global zls@latest ;;
        dotnet) ensure_mise; mise use --global dotnet@latest ;;
        ocaml)
            if ! have_cmd opam; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
            fi
            opam init --yes
            eval "$(opam env)"
            opam install ocaml-lsp-server odoc ocamlformat utop --yes
            ;;
        clojure) install_arch rlwrap; ensure_mise; mise use --global clojure@latest ;;
        scala) ensure_mise; mise use --global java@latest; mise use --global scala@latest; mise use --global scala-cli@latest ;;
        docker-dbs)
            have_cmd docker || install_arch docker
            install_docker_databases
            ;;
        *) setup_fail "Unknown development environment: $id"; setup_finish_pause; exit 1 ;;
    esac

    setup_progress 2 2 "Verifying $label"
    if [[ "$id" != docker-dbs ]] && ! environment_status "$id"; then
        setup_fail "$label setup did not produce the expected installation marker"
        setup_finish_pause
        exit 1
    fi
    setup_done "$label ready"
    setup_finish_pause
}

remove_environment() {
    local id="$1"
    local label="${ENV_LABELS[$id]}"
    setup_init "development-remove-$id" "Remove $label"
    require_arch
    setup_progress 1 2 "Removing $label"

    case "$id" in
        rails) remove_mise_runtime ruby; rm -f "$HOME/.gemrc" ;;
        node|go|java|dotnet|clojure)
            remove_mise_runtime "$id"
            ;;
        bun|deno)
            remove_mise_runtime "$id"
            remove_system_runtime "$id"
            ;;
        php) sudo pacman -Rns --noconfirm php composer php-sqlite xdebug 2>/dev/null || true ;;
        laravel) composer global remove laravel/installer 2>/dev/null || true ;;
        symfony) sudo pacman -Rns --noconfirm symfony-cli 2>/dev/null || true ;;
        python)
            remove_mise_runtime python
            rm -f "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx" "$HOME/.cargo/bin/uv"
            ;;
        elixir|phoenix)
            remove_mise_runtime elixir
            remove_mise_runtime erlang
            ;;
        rust) rustup self uninstall -y 2>/dev/null || true ;;
        zig)
            remove_mise_runtime zig
            remove_mise_runtime zls
            ;;
        ocaml)
            opam switch remove default -y 2>/dev/null || true
            rm -rf "${OPAMROOT:-$HOME/.opam}"
            sudo rm -f /usr/local/bin/opam 2>/dev/null || true
            ;;
        scala)
            remove_mise_runtime scala
            remove_mise_runtime scala-cli
            ;;
        docker-dbs) remove_docker_databases ;;
        *) setup_fail "Unknown development environment: $id"; setup_finish_pause; exit 1 ;;
    esac

    setup_progress 2 2 "Verifying removal"
    if [[ "$id" != docker-dbs ]] && environment_status "$id"; then
        setup_fail "$label removal left an installed runtime or tool behind"
        setup_finish_pause
        exit 1
    fi
    setup_done "$label removed"
    setup_finish_pause
}

main() {
    local operation="${1:-}"
    local id="${2:-}"

    case "$operation" in
        status)
            status_all
            ;;
        install|remove)
            if ! valid_environment "$id"; then
                usage >&2
                exit 2
            fi
            if [[ "$operation" == install ]]; then
                install_environment "$id"
            else
                remove_environment "$id"
            fi
            ;;
        --help|-h)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
