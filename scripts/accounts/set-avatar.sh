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

busctl --system call \
  org.freedesktop.Accounts \
  "$object_path" \
  org.freedesktop.Accounts.User \
  SetIconFile s "$avatar" >/dev/null
