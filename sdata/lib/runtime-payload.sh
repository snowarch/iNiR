# shellcheck shell=bash
# What the installed shell is, one policy for setup, update, make and nix: the root files and folders in
# sdata/runtime-root-files.txt and runtime-payload-dirs.txt, minus sdata/runtime-exclusions.json. Every link is
# checked before anything is written.
#   runtime_payload manifest --root DIR                  path:sha256 (code files only), sorted
#   runtime_payload filters --root DIR [--subdir REL]    rsync --exclude rules for one folder of the payload
#   runtime_payload filter-installed --root DIR          stdin paths minus what is not the payload's to clean
#   runtime_payload copy --root DIR --target DIR [--delete] [--out-format FMT]
#   runtime_payload retire-checkout --root DIR --target DIR

INIR_PAYLOAD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

runtime_payload() (
  set -o pipefail
  shopt -s nullglob dotglob
  fail() { printf 'runtime payload: %s\n' "$*" >&2; exit 1; }
  usage() { printf 'runtime payload: %s\n' "$*" >&2; exit 2; }

  local cmd="${1:-}" root="$INIR_PAYLOAD_ROOT" target="" subdir="" delete=false out_format="" has_subdir=false
  shift || true
  local key value
  while (($#)); do
    key="${1%%=*}"
    if [[ "$1" == --*=* ]]; then value="${1#*=}"
    elif [[ "$key" != --delete ]]; then
      (($# > 1)) || usage "$key needs a value"
      value="$2"; shift
    fi
    case "$key" in
      --root) root="$value" ;;
      --target) target="$value" ;;
      --subdir) subdir="$value"; has_subdir=true ;;
      --out-format) out_format="$value" ;;
      --delete) delete=true ;;
      *) usage "unknown argument: $1" ;;
    esac
    shift
  done
  root="$(realpath -m -- "$root")"
  [[ -z "$target" || "$target" == /* ]] || target="$PWD/$target"

  local policy="$root/sdata/runtime-exclusions.json"
  [[ -f "$policy" ]] || fail "missing $policy"
  local strings='type == "array" and all(type == "string")'
  jq -e "([.excludedNames, .excludedNamePrefixes, .excludedNameSuffixes, .excludedPaths] | all($strings))
         and (.excludedDirectorySuffixes | type == \"object\" and all($strings))" "$policy" >/dev/null 2>&1 \
    || fail "invalid policy: $policy"
  local -a names prefixes suffixes paths dirsuffixes dirs=() files=()
  mapfile -t names < <(jq -r '.excludedNames[]' "$policy")
  mapfile -t prefixes < <(jq -r '.excludedNamePrefixes[]' "$policy")
  mapfile -t suffixes < <(jq -r '.excludedNameSuffixes[]' "$policy")
  mapfile -t paths < <(jq -r '.excludedPaths[]' "$policy")
  mapfile -t dirsuffixes < <(jq -r '.excludedDirectorySuffixes | to_entries[] | .key as $d | .value[] | "\($d)\t\(.)"' "$policy")

  read_list() {
    local -n into="$1"
    local line
    [[ -r "$root/sdata/$2" ]] || fail "cannot read sdata/$2"
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
      [[ -n "$line" && "$line" != \#* ]] || continue
      [[ "$line" != /* && "/$line/" != */../* ]] || fail "invalid runtime path: $line"
      into+=("$line")
    done < "$root/sdata/$2"
  }
  read_list dirs runtime-payload-dirs.txt
  read_list files runtime-root-files.txt

  # keep: stdin paths that are not excluded. A folder that is excluded takes everything under it ("d<TAB>path"
  # lines, as find prints them, mark folders; plain lines are checked alone).
  keep() {
    P_NAMES="$(printf '%s\n' "${names[@]}")" P_PRE="$(printf '%s\n' "${prefixes[@]}")" \
    P_SUF="$(printf '%s\n' "${suffixes[@]}")" P_PATHS="$(printf '%s\n' "${paths[@]}")" \
    P_DSUF="$(printf '%s\n' "${dirsuffixes[@]}")" LC_ALL=C awk '
      function load(key, arr,   n, tmp, i) {
        n = split(ENVIRON[key], tmp, "\n"); m = 0
        for (i = 1; i <= n; i++) if (tmp[i] != "") arr[++m] = tmp[i]
        return m
      }
      function ends(s, x) { return length(s) >= length(x) && substr(s, length(s) - length(x) + 1) == x }
      function excluded(rel,   n, parts, i, j, parent) {
        n = split(rel, parts, "/")
        for (i = 1; i <= n; i++) {
          if (parts[i] in NAME) return 1
          for (j = 1; j <= npre; j++) if (index(parts[i], PRE[j]) == 1) return 1
          for (j = 1; j <= nsuf; j++) if (ends(parts[i], SUF[j])) return 1
        }
        for (j = 1; j <= npath; j++) if (rel == PATH[j] || index(rel, PATH[j] "/") == 1) return 1
        parent = rel
        if (!sub(/\/[^\/]*$/, "", parent)) parent = "."
        for (j = 1; j <= ndsuf; j++) if (parent == DDIR[j] && ends(rel, DSUF[j])) return 1
        return 0
      }
      BEGIN {
        nn = load("P_NAMES", N); for (i = 1; i <= nn; i++) NAME[N[i]] = 1
        npre = load("P_PRE", PRE); nsuf = load("P_SUF", SUF); npath = load("P_PATHS", PATH)
        n = load("P_DSUF", DS)
        for (i = 1; i <= n; i++) { t = index(DS[i], "\t"); DDIR[++ndsuf] = substr(DS[i], 1, t - 1); DSUF[ndsuf] = substr(DS[i], t + 1) }
      }
      {
        type = ""; rel = $0
        if (substr($0, 2, 1) == "\t") { type = substr($0, 1, 1); rel = substr($0, 3) }
        for (p in PRUNED) if (index(rel, p) == 1) next
        if (excluded(rel)) { if (type == "d") PRUNED[rel "/"] = 1; next }
        if (type != "d") print (type == "" ? rel : type "\t" rel)
      }'
  }
  is_excluded() { [[ -z "$(printf '%s\n' "$1" | keep)" ]]; }

  in_payload() {
    local rel="$1" d
    for d in "${files[@]}"; do [[ "$rel" == "$d" ]] && return 0; done
    for d in "${dirs[@]}"; do [[ "$rel" == "$d" || "$rel" == "$d"/* ]] && return 0; done
    return 1
  }
  # A link ships only when it is relative and lands on something the payload ships.
  check_link() {
    local path="$root/$1" dest rel
    [[ -L "$path" ]] || return 0
    [[ "$(readlink -- "$path")" != /* ]] || fail "absolute runtime symlink: $1"
    dest="$(realpath -m -- "$path" 2>/dev/null)" || fail "escaping or dangling runtime symlink: $1"
    [[ "$dest" == "$root"/* && -e "$dest" ]] || fail "escaping or dangling runtime symlink: $1"
    rel="${dest#"$root"/}"
    if ! { in_payload "$rel" || [[ "$rel" != */* && "$rel" == *.qml && -f "$dest" ]]; } || is_excluded "$rel"; then
      fail "unsafe runtime symlink: $1"
    fi
  }

  # Every path the payload ships, checked; any problem stops before a byte is copied.
  payload_paths() {
    local name path type rel
    for name in "${files[@]}"; do
      ! is_excluded "$name" || fail "excluded root manifest entry: $name"
      [[ -f "$root/$name" ]] || fail "missing runtime file: $name"
      check_link "$name"
      printf '%s\n' "$name"
    done
    for path in "$root"/*.qml; do
      name="${path##*/}"
      [[ -f "$path" ]] && ! is_excluded "$name" || continue
      check_link "$name"
      printf '%s\n' "$name"
    done
    for name in "${dirs[@]}"; do
      ! is_excluded "$name" && [[ -d "$root/$name" ]] || fail "invalid runtime directory: $name"
      [[ ! -L "$root/$name" ]] || fail "runtime directory must not be a symlink: $name"
    done
    local walked
    walked="$(for name in "${dirs[@]}"; do
                find "$root/$name" -mindepth 1 -printf "%y\t$name/%P\n" || exit 1
              done | keep)" || fail "cannot walk the payload"
    while IFS=$'\t' read -r type rel; do
      [[ -n "$rel" ]] || continue
      [[ "$type" != l ]] || check_link "$rel"
      printf '%s\n' "$rel"
    done <<< "$walked"
  }

  rsync_filters() {
    local sub="$1" rule entry dir suffix
    local -a rules=("${names[@]}")
    for rule in "${prefixes[@]}"; do rules+=("$rule*"); done
    for rule in "${suffixes[@]}"; do rules+=("*$rule"); done
    for rule in "${paths[@]}"; do
      if [[ -z "$sub" ]]; then rules+=("/$rule")
      elif [[ "$rule" == "$sub"/* ]]; then rules+=("/${rule#"$sub"/}"); fi
    done
    for entry in "${dirsuffixes[@]}"; do
      dir="${entry%%$'\t'*}" suffix="${entry#*$'\t'}"
      if [[ -z "$sub" ]]; then rules+=("/$dir/*$suffix")
      elif [[ "$dir" == "$sub"/* ]]; then rules+=("/${dir#"$sub"/}/*$suffix"); fi
    done
    # Caches the shell writes itself (a v2.33 helper's __pycache__) are perishable: they go with a folder the payload
    # drops, where a plain exclude kept it alive ("cannot delete non-empty directory", 11-04).
    for rule in "${rules[@]}"; do
      case "$rule" in
        __pycache__|.ruff_cache|'*.pyc'|'*.qmlc'|'*.jsc') printf -- '--filter=-p %s\n' "$rule" ;;
        *) printf -- '--exclude=%s\n' "$rule" ;;
      esac
    done
  }

  # separate: the target is its own folder, not this checkout, inside it or holding it.
  separate() {
    local dest
    [[ ! -L "$1" ]] || return 1
    dest="$(realpath -m -- "$1")"
    [[ "$dest" != / && "$dest" != "$root" && "$root" != "$dest"/* && "$dest" != "$root"/* ]]
  }

  # Synced files no longer match the copy's own HEAD, and setup would update from that checkout.
  retire_checkout() {
    local git="$1/.git" dest
    [[ -e "$git" || -L "$git" ]] || return 0
    dest="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/backups/runtime-git-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$(dirname "$dest")" && mv -- "$git" "$dest" || fail "cannot move $git"
    printf "Moved the installed copy's old .git to %s; updates now come from %s\n" "$dest" "$root"
  }

  case "$cmd" in
    manifest)
      local -a all code=()
      local name hash list hashes=""
      list="$(payload_paths)" || exit 1
      mapfile -t all < <(LC_ALL=C sort -u <<< "$list")
      for name in "${all[@]}"; do
        [[ -f "$root/$name" && "${name##*/}" =~ ^.+\.(qml|js|py|sh|fish)$ ]] && code+=("$name")
      done
      if ((${#code[@]})); then
        hashes="$(cd "$root" && printf '%s\0' "${code[@]}" | xargs -0 sha256sum --)" || fail "cannot hash the payload"
      fi
      local -A sums=()
      while read -r hash name; do
        [[ -n "$name" ]] && sums["$name"]="$hash"
      done <<< "$hashes"
      for name in "${all[@]}"; do printf '%s:%s\n' "$name" "${sums[$name]:-}"; done
      ;;
    filters)
      ! $has_subdir || [[ "$subdir" != /* && "/$subdir/" != */../* ]] || usage "invalid subdirectory"
      payload_paths >/dev/null || exit 1
      rsync_filters "$subdir"
      ;;
    filter-installed)
      # Optional packs and private or user files stay out of orphan cleanup; old source-only tooling does not.
      local -a assets=()
      local p
      for p in "${paths[@]}"; do [[ "$p" == assets/* ]] && assets+=("$p"); done
      paths=("${assets[@]}")
      keep
      ;;
    retire-checkout)
      [[ -n "$target" ]] || usage "--target is required"
      ! separate "$target" || retire_checkout "$target"
      ;;
    copy)
      [[ -n "$target" ]] || usage "--target is required"
      payload_paths >/dev/null || exit 1
      separate "$target" || fail "destination must be a separate installed directory"
      retire_checkout "$target"
      local -a args=(rsync -a --chmod=u+w) link  # a read-only payload (Nix store) still gives a copy the person owns
      # `inir hub` plugins are links under modules/ the payload never put there: --delete leaves them.
      while IFS= read -r link; do
        [[ -e "$root/modules/$link" ]] || args+=("--filter=P /modules/$(sed 's/[*?[\\]/\\&/g' <<< "$link")")
      done < <(find "$target/modules/" -type l -printf '%P\n' 2>/dev/null)
      mapfile -t -O "${#args[@]}" args < <(rsync_filters "")
      ! $delete || args+=(--delete)
      [[ -z "$out_format" ]] || args+=("--out-format=$out_format")
      for p in "$root"/*.qml; do [[ -f "$p" ]] && args+=("--include=/${p##*/}"); done
      for p in "${files[@]}"; do args+=("--include=/$p"); done
      for p in "${dirs[@]}"; do args+=("--include=/$p/***"); done
      args+=(--exclude='/*')
      mkdir -p -- "$target" || fail "cannot create $target"
      "${args[@]}" "$root/" "$target/" || fail "rsync failed ($?)"
      ;;
    *) usage "usage: runtime_payload manifest|filters|filter-installed|copy|retire-checkout [--root DIR] ..." ;;
  esac
)
