#compdef inir
# Zsh completion for inir CLI
# Install: inir completions install zsh
# Or: eval "$(inir completions zsh)"
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
        'settings:Toggle settings'
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
        'completions:Generate or install shell completions'
        'bind:Make a Niri keybind for any inir call'
    )

    local -a ipc_targets=() ipc_aliases=()
    local have_registry=0
    if _inir_load_registry 2>/dev/null; then
        have_registry=1
        local t desc
        for t in "${IPC_ALL_TARGETS[@]}"; do
            desc="${IPC_TARGET_DESC[$t]:-}"
            ipc_targets+=("${t}:${desc%%.*}")
        done
        for t in ${(k)IPC_KEBAB_ALIASES}; do
            desc="${IPC_TARGET_DESC[${IPC_KEBAB_ALIASES[$t]}]:-}"
            ipc_aliases+=("${t}:${desc%%.*}")
        done
    fi

    # The words of an IPC call: after `inir`, `inir ipc` or `inir bind [--opts] <keys>`.
    local first="${words[2]:-}" i=2
    local -a call=()
    if [[ "$first" == ipc ]]; then
        i=3
    elif [[ "$first" == bind ]]; then
        i=3
        while (( i < CURRENT )) && [[ "${words[i]}" == --* ]]; do (( i++ )); done
        if (( CURRENT <= i )); then
            local -a bind_opts=(
                '--add:Write the bind into your own block of 90-user-extra.kdl'
                '--remove:Take a bind you added back out'
                '--list:The binds you added'
                '--examples:Ready binds for what people do most'
            )
            [[ "$PREFIX" == -* ]] && _describe 'option' bind_opts || _message 'keys, e.g. Mod+O'
            return
        fi
        (( i++ ))
    fi
    for (( ; i < CURRENT; i++ )); do call+=("${words[i]}"); done

    if (( CURRENT == 2 )); then
        _describe 'command' cli_commands
        (( have_registry )) && _describe 'IPC target' ipc_targets && _describe 'IPC alias' ipc_aliases
        return
    fi
    if [[ "$first" != ipc && "$first" != bind && ${#call} -eq 1 ]]; then
        case "$first" in
            service)
                local -a service_cmds=(install uninstall enable disable start stop restart status logs)
                _describe 'service command' service_cmds; return ;;
            theme)
                local -a theme_cmds=(list-targets inspect doctor scaffold apply)
                _describe 'theme command' theme_cmds; return ;;
            completions)
                local -a shells=('bash' 'zsh' 'fish' 'install:Install them where your shell looks')
                _describe 'shell' shells; return ;;
        esac
    fi
    (( have_registry )) || return

    local target="${call[1]:-}"
    [[ -n "$target" && -n "${IPC_KEBAB_ALIASES[$target]:-}" ]] && target="${IPC_KEBAB_ALIASES[$target]}"
    case ${#call} in
        0)
            _describe 'IPC target' ipc_targets
            _describe 'IPC alias' ipc_aliases
            ;;
        1)
            [[ -n "$target" && -n "${IPC_TARGET_FUNCTIONS[$target]:-}" ]] || return
            local -a funcs=()
            local fn
            for fn in ${(s: :)IPC_TARGET_FUNCTIONS[$target]}; do
                funcs+=("${fn}:${${IPC_FUNCTION_DESC[${target}:${fn}]:-}%%.*}")
            done
            _describe 'function' funcs
            ;;
        *)
            # A function's own values, for as many arguments as it takes.
            local key="${target}:${call[2]}"
            local -a hint=(${(s: :)IPC_FUNCTION_ARGS[$key]:-})
            if (( ${#call} - 1 <= ${#hint} )) && [[ -n "${IPC_FUNCTION_VALUES[$key]:-}" ]]; then
                local -a values=(${(s: :)IPC_FUNCTION_VALUES[$key]})
                _describe 'value' values
            else
                _message "${IPC_FUNCTION_ARGS[$key]:-argument}"
            fi
            ;;
    esac
}

_inir "$@"
