#!/usr/bin/env bash
set -euo pipefail

check_only=false
if [[ ${1:-} == "--check" ]]; then
  check_only=true
  shift
fi

avatar=${1:-}
if [[ -z "$avatar" || ! -f "$avatar" ]]; then
  printf 'usage: %s IMAGE_FILE\n' "$0" >&2
  exit 2
fi

user_name=${USER:-$(id -un)}
object_line=$(busctl --system call \
  org.freedesktop.Accounts \
  /org/freedesktop/Accounts \
  org.freedesktop.Accounts \
  FindUserByName s "$user_name")

object_path=$(sed -n 's/^o "\([^"]*\)"$/\1/p' <<<"$object_line")
if [[ -z "$object_path" ]]; then
  printf 'Could not resolve AccountsService user object for %s\n' "$user_name" >&2
  exit 1
fi

if [[ "$check_only" == true ]]; then
  printf '%s\n' "$object_path"
  exit 0
fi

# AccountsService refuses an icon over 1 MiB (ICON_FILE_MAX_SIZE) and login screens may not read webp or avif:
# such a picture is made a 512 px square PNG first.
lower=${avatar,,}
if (( $(stat -c %s "$avatar") > 1048576 )) || [[ $lower != *.png && $lower != *.jpg && $lower != *.jpeg ]]; then
  im=$(command -v magick || command -v convert || true)
  if [[ -z "$im" ]]; then
    printf 'ImageMagick is needed to shrink %s\n' "$avatar" >&2
    exit 1
  fi
  out_dir="${XDG_CACHE_HOME:-$HOME/.cache}/inir"
  mkdir -p "$out_dir"
  out="$out_dir/avatar.png"
  for side in 512 256; do
    "$im" "${avatar}[0]" -auto-orient -resize "${side}x${side}^" -gravity center -extent "${side}x${side}" -depth 8 -strip "$out"
    (( $(stat -c %s "$out") <= 1048576 )) && break
  done
  avatar=$out
fi

busctl --system call \
  org.freedesktop.Accounts \
  "$object_path" \
  org.freedesktop.Accounts.User \
  SetIconFile s "$avatar" >/dev/null
