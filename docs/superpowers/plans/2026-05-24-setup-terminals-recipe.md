# Setup Terminals Recipe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an interactive `/setup-terminals` recipe that installs a terminal emulator and sets it as the iNiR default terminal in `defaults/config.json`.

**Architecture:** Implement one self-contained Bash recipe under `scripts/setup/terminals.sh`, following the existing setup recipe metadata/discovery pattern. The recipe presents a menu, installs the selected terminal via existing package helpers, and updates `.apps.terminal` plus `.apps.update` in `defaults/config.json` using `jq`.

**Tech Stack:** Bash, existing setup helpers from `scripts/setup/_lib.sh`, `jq`, Arch package helpers, Flatpak fallback helpers.

---

### Task 1: Add setup terminal recipe script

**Files:**
- Create: `scripts/setup/terminals.sh`
- Reference: `scripts/setup/spotify.sh`
- Reference: `scripts/setup/_scan.sh`
- Reference: `scripts/setup/_lib.sh`
- Reference: `defaults/config.json`

- [ ] **Step 1: Create `scripts/setup/terminals.sh` metadata and shell setup**

Create a Bash script with:

```bash
#!/usr/bin/env bash
# scripts/setup/terminals.sh
# /setup-terminals — install and set the default terminal emulator.
#
# @meta name: Setup Terminals
# @meta description: Install and set the default terminal emulator
# @meta icon: terminal
# @meta keywords: terminal kitty foot alacritty wezterm ghostty konsole

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"
```

- [ ] **Step 2: Add terminal table and field helpers**

Use a single table format: `key|Display Name|arch repo packages|arch AUR packages|flatpak package|exec prefix`.

```bash
TERMINALS=(
    "kitty|Kitty|kitty|||kitty -e"
    "foot|Foot|foot|||foot"
    "alacritty|Alacritty|alacritty|||alacritty -e"
    "wezterm|WezTerm|wezterm|||wezterm start --"
    "ghostty|Ghostty||ghostty|com.mitchellh.ghostty|ghostty -e"
    "konsole|Konsole|konsole|||konsole -e"
)
```

Implement helpers:

```bash
terminal_field() {
    local row="$1" field_index="$2"
    local key label arch_repo arch_aur flatpak exec_prefix
    IFS='|' read -r key label arch_repo arch_aur flatpak exec_prefix <<< "$row"

    case "$field_index" in
        key) echo "$key" ;;
        label) echo "$label" ;;
        arch_repo) echo "$arch_repo" ;;
        arch_aur) echo "$arch_aur" ;;
        flatpak) echo "$flatpak" ;;
        exec_prefix) echo "$exec_prefix" ;;
    esac
}
```

- [ ] **Step 3: Add interactive selection**

Implement `choose_terminal_index()` using the same stderr menu/stdout return pattern as prior setup recipes:

```bash
choose_terminal_index() {
    local cancel_idx choice i row label details arch_repo arch_aur flatpak
    echo >&2
    echo "Select one terminal emulator to install and use as default:" >&2
    for i in "${!TERMINALS[@]}"; do
        row="${TERMINALS[$i]}"
        label="$(terminal_field "$row" label)"
        arch_repo="$(terminal_field "$row" arch_repo)"
        arch_aur="$(terminal_field "$row" arch_aur)"
        flatpak="$(terminal_field "$row" flatpak)"
        details=()
        [[ -n "$arch_repo" ]] && details+=("repo: $arch_repo")
        [[ -n "$arch_aur" ]] && details+=("aur: $arch_aur")
        [[ -n "$flatpak" ]] && details+=("flatpak: $flatpak")
        printf '  %d) %s%s\n' "$((i + 1))" "$label" "$(if (( ${#details[@]} )); then printf ' (%s)' "$(IFS=', '; echo "${details[*]}")"; fi)" >&2
    done
    cancel_idx=$(( ${#TERMINALS[@]} + 1 ))
    printf '  %d) Cancel\n\n' "$cancel_idx" >&2

    while true; do
        read -r -p "Enter choice [1-${cancel_idx}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= cancel_idx )); then
            break
        fi
        echo "Invalid choice. Please enter a number from 1 to ${cancel_idx}." >&2
    done
    (( choice == cancel_idx )) && return 1
    echo "$((choice - 1))"
}
```

### Task 2: Install selected terminal

**Files:**
- Modify: `scripts/setup/terminals.sh`

- [ ] **Step 1: Add package splitting helper**

```bash
split_words_into_array() {
    local raw="$1"
    local -n out_ref="$2"
    out_ref=()
    [[ -z "$raw" ]] && return 0
    # shellcheck disable=SC2206
    out_ref=($raw)
}
```

- [ ] **Step 2: Add install function**

For Arch-like distros use existing `install_arch`. For non-Arch use Flatpak when the row defines a Flatpak ID; otherwise fail clearly.

```bash
install_terminal() {
    local row="$1"
    local arch_repo arch_aur flatpak repo_pkgs aur_pkgs
    arch_repo="$(terminal_field "$row" arch_repo)"
    arch_aur="$(terminal_field "$row" arch_aur)"
    flatpak="$(terminal_field "$row" flatpak)"
    repo_pkgs=()
    aur_pkgs=()
    split_words_into_array "$arch_repo" repo_pkgs
    split_words_into_array "$arch_aur" aur_pkgs

    if is_arch_like; then
        if (( ${#repo_pkgs[@]} )) && (( ${#aur_pkgs[@]} )); then
            install_arch "${repo_pkgs[@]}" -- "${aur_pkgs[@]}"
        elif (( ${#repo_pkgs[@]} )); then
            install_arch "${repo_pkgs[@]}"
        elif (( ${#aur_pkgs[@]} )); then
            install_arch -- "${aur_pkgs[@]}"
        else
            echo "No Arch package mapping found for: $(terminal_field "$row" label)" >&2
            return 1
        fi
    else
        if [[ -z "$flatpak" ]]; then
            echo "No Flatpak fallback is configured for $(terminal_field "$row" label)." >&2
            return 1
        fi
        install_flatpak "$flatpak"
    fi
}
```

### Task 3: Update config defaults

**Files:**
- Modify: `scripts/setup/terminals.sh`
- Modify at runtime: `defaults/config.json`

- [ ] **Step 1: Add config update function**

Require `jq` for safe JSON editing. Update `apps.terminal` and `apps.update`.

```bash
update_terminal_config() {
    local row="$1"
    local terminal_key exec_prefix config_path tmp_path update_cmd
    terminal_key="$(terminal_field "$row" key)"
    exec_prefix="$(terminal_field "$row" exec_prefix)"
    config_path="$SCRIPT_DIR/../../defaults/config.json"
    tmp_path="${config_path}.tmp"
    update_cmd="${exec_prefix} arch-update"

    if ! have_cmd jq; then
        echo "jq is required to safely update $config_path." >&2
        return 1
    fi
    if [[ ! -f "$config_path" ]]; then
        echo "Could not find config file: $config_path" >&2
        return 1
    fi

    jq --arg terminal "$terminal_key" --arg update "$update_cmd" \
        '.apps.terminal = $terminal | .apps.update = $update' \
        "$config_path" > "$tmp_path"
    mv "$tmp_path" "$config_path"
}
```

- [ ] **Step 2: Add command verification helper**

Verify the selected terminal command exists after installation:

```bash
verify_terminal_command() {
    local row="$1" terminal_key
    terminal_key="$(terminal_field "$row" key)"
    if ! have_cmd "$terminal_key"; then
        echo "warning: $terminal_key is not in PATH yet. You may need to open a new terminal session." >&2
        return 0
    fi
}
```

### Task 4: Wire main flow and validation

**Files:**
- Modify: `scripts/setup/terminals.sh`

- [ ] **Step 1: Add main flow**

```bash
setup_init "terminals" "Setup Terminals"

TOTAL=4
setup_progress 1 $TOTAL "Choose terminal emulator"
if ! selected_index="$(choose_terminal_index)"; then
    setup_progress 2 $TOTAL "No changes made"
    setup_done "Cancelled by user"
    setup_finish_pause
    exit 0
fi

selected_row="${TERMINALS[$selected_index]}"
selected_name="$(terminal_field "$selected_row" label)"

setup_progress 2 $TOTAL "Installing ${selected_name}"
install_terminal "$selected_row"

setup_progress 3 $TOTAL "Updating iNiR default terminal"
update_terminal_config "$selected_row"
verify_terminal_command "$selected_row"

setup_progress 4 $TOTAL "Finalizing"
setup_done "${selected_name} is now the default iNiR terminal"
setup_finish_pause
```

- [ ] **Step 2: Validate syntax**

Run:

```bash
bash -n scripts/setup/terminals.sh
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Validate recipe discovery**

Run:

```bash
bash scripts/setup/_scan.sh | jq '.[] | select(.slug == "terminals")'
```

Expected JSON contains:

```json
{
  "slug": "terminals",
  "name": "Setup Terminals",
  "description": "Install and set the default terminal emulator",
  "icon": "terminal",
  "keywords": "terminal kitty foot alacritty wezterm ghostty konsole"
}
```

- [ ] **Step 4: Commit implementation**

```bash
git add scripts/setup/terminals.sh docs/superpowers/plans/2026-05-24-setup-terminals-recipe.md
git commit -m "feat(setup): add terminal setup recipe"
```

---

## Self-Review

- Spec coverage: The plan covers recipe creation, package install, config update, discovery validation, and maintainability.
- Placeholder scan: No TBD/TODO placeholders remain.
- Type consistency: Function names and table fields are consistent across tasks.
