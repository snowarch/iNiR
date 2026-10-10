# Bash completion for inir CLI
# Install: inir completions install bash
# Or: eval "$(inir completions bash)"
# Or: inir completions bash > /etc/bash_completion.d/inir

_inir_completions() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Top-level CLI commands
    local cli_commands="bind install start stop run restart kill logs terminal browser close-window ipc settings settings-window waffle-settings-window repair path test-local setup service doctor migrate status update rollback my-changes uninstall config info backup version theme hub help completions"

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

    # The words of an IPC call: after `inir`, `inir ipc` or `inir bind [--opts] <keys>`.
    local -a call=()
    local i=1 first="${COMP_WORDS[1]:-}"
    if [[ "$first" == "ipc" ]]; then
        i=2
    elif [[ "$first" == "bind" ]]; then
        i=2
        while (( i < COMP_CWORD )) && [[ "${COMP_WORDS[i]}" == --* ]]; do ((i++)); done
        # Keys first: nothing to offer while they are being typed.
        if (( COMP_CWORD <= i )); then
            [[ "$cur" == -* ]] && COMPREPLY=( $(compgen -W "--add --remove --list --examples" -- "$cur") )
            return 0
        fi
        ((i++))
    fi
    for (( ; i < COMP_CWORD; i++ )); do call+=("${COMP_WORDS[i]}"); done

    if (( COMP_CWORD == 1 )); then
        COMPREPLY=( $(compgen -W "$cli_commands $ipc_targets $ipc_aliases" -- "$cur") )
        return 0
    fi
    if [[ "$first" != "ipc" && "$first" != "bind" && ${#call[@]} -eq 1 ]]; then
        case "$first" in
            service) COMPREPLY=( $(compgen -W "install uninstall enable disable start stop restart status logs" -- "$cur") ); return 0 ;;
            theme) COMPREPLY=( $(compgen -W "list-targets inspect doctor scaffold apply" -- "$cur") ); return 0 ;;
            hub) COMPREPLY=( $(compgen -W "list search info install update remove sync status sources open refresh changed" -- "$cur") ); return 0 ;;
            completions) COMPREPLY=( $(compgen -W "bash zsh fish install" -- "$cur") ); return 0 ;;
        esac
    fi

    local target="${call[0]:-}"
    [[ -n "$target" && -n "${IPC_KEBAB_ALIASES[$target]+_}" ]] && target="${IPC_KEBAB_ALIASES[$target]}"
    case "${#call[@]}" in
        0)
            COMPREPLY=( $(compgen -W "$ipc_targets $ipc_aliases" -- "$cur") )
            ;;
        1)
            [[ -n "$target" && -n "${IPC_TARGET_FUNCTIONS[$target]+_}" ]] && \
                COMPREPLY=( $(compgen -W "${IPC_TARGET_FUNCTIONS[$target]}" -- "$cur") )
            ;;
        *)
            # A function's own values, for as many arguments as it takes.
            local key="${target}:${call[1]}"
            local -a hint=( ${IPC_FUNCTION_ARGS[$key]:-} )
            if (( ${#call[@]} - 1 <= ${#hint[@]} )) && [[ -n "${IPC_FUNCTION_VALUES[$key]+_}" ]]; then
                COMPREPLY=( $(compgen -W "${IPC_FUNCTION_VALUES[$key]}" -- "$cur") )
            fi
            ;;
    esac
}

complete -F _inir_completions inir
