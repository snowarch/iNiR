#compdef inir
# Zsh completion for inir CLI
# Install: eval "$(inir completions zsh)"
# Or: inir completions zsh > ~/.zsh/completions/_inir

# Source IPC registry for target data
_inir_load_registry() {
    local script_dir inir_bin
    inir_bin="$(command -v inir 2>/dev/null || echo /usr/bin/inir)"
    # Follow symlinks to find the real scripts/ directory
    if [[ -L "$inir_bin" ]]; then
        script_dir="$(cd -- "$(dirname -- "$(readlink -f "$inir_bin")")" 2>/dev/null && pwd)"
    else
        script_dir="$(cd -- "$(dirname -- "$inir_bin")" 2>/dev/null && pwd)"
    fi
    local candidate
    for candidate in \
        "${script_dir}/lib/ipc-registry.sh" \
        "/usr/share/quickshell/inir/scripts/lib/ipc-registry.sh" \
        "/usr/local/share/quickshell/inir/scripts/lib/ipc-registry.sh"; do
        if [[ -f "$candidate" ]]; then
            source "$candidate"
            return 0
        fi
    done
    return 1
}

_inir() {
    local -a cli_commands=(
        'install:Install iNiR'
        'start:Start the shell'
        'stop:Stop the shell'
        'run:Run the shell'
        'restart:Restart the shell'
        'kill:Kill the shell process'
        'logs:View runtime logs'
        'terminal:Open terminal'
        'browser:Open browser'
        'close-window:Close focused window'
        'ipc:Low-level IPC call'
        'settings:Open settings'
        'settings-window:Open settings window'
        'waffle-settings-window:Open waffle settings window'
        'repair:Repair shell state'
        'path:Show config path'
        'test-local:Run local tests'
        'setup:Run setup directly'
        'service:Manage systemd service'
        'doctor:Health checks'
        'migrate:Run migrations'
        'status:Shell status'
        'update:Update shell'
        'rollback:Rollback update'
        'my-changes:Show local changes'
        'uninstall:Uninstall shell'
        'config:View/edit config'
        'info:System info'
        'backup:Create backup'
        'version:Show version'
        'theme:Theme management'
        'help:Show help'
        'completions:Generate shell completions'
    )

    local -a ipc_targets=()
    local -a ipc_aliases=()

    if _inir_load_registry 2>/dev/null; then
        local t
        for t in "${IPC_ALL_TARGETS[@]}"; do
            local desc="${IPC_TARGET_DESC[$t]:-}"
            desc="${desc%%.*}"
            ipc_targets+=("${t}:${desc:-IPC target}")
        done
        local alias_name
        for alias_name in "${!IPC_KEBAB_ALIASES[@]}"; do
            local real="${IPC_KEBAB_ALIASES[$alias_name]}"
            local desc="${IPC_TARGET_DESC[$real]:-}"
            desc="${desc%%.*}"
            ipc_aliases+=("${alias_name}:${desc:-alias for ${real}}")
        done
    fi

    case "$CURRENT" in
        2)
            _describe 'command' cli_commands
            if [[ ${#ipc_targets[@]} -gt 0 ]]; then
                _describe 'IPC target' ipc_targets
                _describe 'IPC alias' ipc_aliases
            fi
            ;;
        3)
            local subcmd="${words[2]}"
            case "$subcmd" in
                service)
                    local -a service_cmds=(
                        'install:Install systemd service'
                        'uninstall:Remove systemd service'
                        'enable:Enable service'
                        'disable:Disable service'
                        'start:Start service'
                        'stop:Stop service'
                        'restart:Restart service'
                        'status:Service status'
                        'logs:Service logs'
                    )
                    _describe 'service command' service_cmds
                    ;;
                theme)
                    local -a theme_cmds=(
                        'list-targets:List theme targets'
                        'inspect:Inspect theme target'
                        'doctor:Check theme health'
                        'scaffold:Create theme template'
                        'apply:Apply theme'
                    )
                    _describe 'theme command' theme_cmds
                    ;;
                completions)
                    local -a shells=('bash' 'zsh' 'fish')
                    _describe 'shell' shells
                    ;;
                ipc)
                    if [[ ${#ipc_targets[@]} -gt 0 ]]; then
                        _describe 'IPC target' ipc_targets
                        _describe 'IPC alias' ipc_aliases
                    fi
                    ;;
                *)
                    # Check if it's an IPC target
                    local normalized="$subcmd"
                    if [[ -n "${IPC_KEBAB_ALIASES[$subcmd]+_}" ]]; then
                        normalized="${IPC_KEBAB_ALIASES[$subcmd]}"
                    fi
                    if [[ -n "${IPC_TARGET_FUNCTIONS[$normalized]+_}" ]]; then
                        local -a funcs=()
                        local fn
                        for fn in ${IPC_TARGET_FUNCTIONS[$normalized]}; do
                            local fn_desc="${IPC_FUNCTION_DESC[${normalized}:${fn}]:-}"
                            funcs+=("${fn}:${fn_desc:-}")
                        done
                        _describe 'function' funcs
                    fi
                    ;;
            esac
            ;;
        4)
            if [[ "${words[2]}" == "ipc" ]]; then
                local target="${words[3]}"
                if [[ -n "${IPC_KEBAB_ALIASES[$target]+_}" ]]; then
                    target="${IPC_KEBAB_ALIASES[$target]}"
                fi
                if [[ -n "${IPC_TARGET_FUNCTIONS[$target]+_}" ]]; then
                    local -a funcs=()
                    local fn
                    for fn in ${IPC_TARGET_FUNCTIONS[$target]}; do
                        local fn_desc="${IPC_FUNCTION_DESC[${target}:${fn}]:-}"
                        funcs+=("${fn}:${fn_desc:-}")
                    done
                    _describe 'function' funcs
                fi
            fi
            ;;
    esac
}

_inir "$@"
