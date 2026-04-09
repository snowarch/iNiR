# Bash completion for inir CLI
# Install: eval "$(inir completions bash)"
# Or: inir completions bash > /etc/bash_completion.d/inir

_inir_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Top-level CLI commands
    local cli_commands="install start stop run restart kill logs terminal browser close-window ipc settings settings-window waffle-settings-window repair path test-local setup service doctor migrate status update rollback my-changes uninstall config info backup version theme help completions"

    # Source IPC registry for target/function completion
    local script_dir inir_bin
    inir_bin="$(command -v inir 2>/dev/null || echo /usr/bin/inir)"
    # Follow symlinks to find the real scripts/ directory
    if [[ -L "$inir_bin" ]] && command -v readlink &>/dev/null; then
        script_dir="$(cd -- "$(dirname -- "$(readlink -f "$inir_bin")")" 2>/dev/null && pwd)"
    else
        script_dir="$(cd -- "$(dirname -- "$inir_bin")" 2>/dev/null && pwd)"
    fi
    local registry=""
    local candidate
    for candidate in \
        "${script_dir}/lib/ipc-registry.sh" \
        "/usr/share/quickshell/inir/scripts/lib/ipc-registry.sh" \
        "/usr/local/share/quickshell/inir/scripts/lib/ipc-registry.sh"; do
        if [[ -f "$candidate" ]]; then
            registry="$candidate"
            break
        fi
    done

    local ipc_targets=""
    local ipc_aliases=""
    if [[ -n "$registry" ]]; then
        # Source the full registry — declare -gA ensures arrays are global
        source "$registry" 2>/dev/null
        ipc_targets="${IPC_ALL_TARGETS[*]}"
        if [[ ${#IPC_KEBAB_ALIASES[@]} -gt 0 ]]; then
            ipc_aliases="${!IPC_KEBAB_ALIASES[*]}"
        fi
    fi

    case "$COMP_CWORD" in
        1)
            # First argument: CLI commands + IPC targets + kebab aliases
            COMPREPLY=( $(compgen -W "$cli_commands $ipc_targets $ipc_aliases" -- "$cur") )
            ;;
        2)
            case "$prev" in
                service)
                    COMPREPLY=( $(compgen -W "install uninstall enable disable start stop restart status logs" -- "$cur") )
                    ;;
                theme)
                    COMPREPLY=( $(compgen -W "list-targets inspect doctor scaffold apply" -- "$cur") )
                    ;;
                completions)
                    COMPREPLY=( $(compgen -W "bash zsh fish" -- "$cur") )
                    ;;
                ipc)
                    COMPREPLY=( $(compgen -W "$ipc_targets $ipc_aliases" -- "$cur") )
                    ;;
                *)
                    # Check if prev is an IPC target — complete with its functions
                    local normalized="$prev"
                    if [[ -n "${IPC_KEBAB_ALIASES[$prev]+_}" ]]; then
                        normalized="${IPC_KEBAB_ALIASES[$prev]}"
                    fi
                    if [[ -n "${IPC_TARGET_FUNCTIONS[$normalized]+_}" ]]; then
                        COMPREPLY=( $(compgen -W "${IPC_TARGET_FUNCTIONS[$normalized]}" -- "$cur") )
                    fi
                    ;;
            esac
            ;;
        3)
            # Third arg: if "ipc <target>" pattern, complete functions
            if [[ "${COMP_WORDS[1]}" == "ipc" ]]; then
                local target="${COMP_WORDS[2]}"
                if [[ -n "${IPC_KEBAB_ALIASES[$target]+_}" ]]; then
                    target="${IPC_KEBAB_ALIASES[$target]}"
                fi
                if [[ -n "${IPC_TARGET_FUNCTIONS[$target]+_}" ]]; then
                    COMPREPLY=( $(compgen -W "${IPC_TARGET_FUNCTIONS[$target]}" -- "$cur") )
                fi
            fi
            ;;
    esac
}

complete -F _inir_completions inir
