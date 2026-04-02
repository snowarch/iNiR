#!/usr/bin/env bash
# Memory optimization environment for Quickshell/iNiR
#
# Qt decodes wallpaper images in background threads. glibc malloc creates
# per-thread arenas that retain freed memory instead of returning it to
# the OS. After several wallpaper switches, hundreds of MB accumulate in
# these stale arenas.
#
# These variables fix the problem:
#
#   MALLOC_ARENA_MAX=2
#     Limit glibc to 2 malloc arenas instead of 8×cores.
#     Prevents thread arenas from proliferating.
#
#   MALLOC_MMAP_THRESHOLD_=131072
#     Force allocations >128KB to use mmap() instead of sbrk().
#     Decoded wallpaper textures (always >128KB) are allocated via mmap
#     and returned to the OS immediately when freed.
#
# Usage:
#   Source this before launching quickshell:
#     source ~/.config/quickshell/inir/scripts/quickshell-env.sh
#     inir run
#
#   Or in niri config.kdl environment block:
#     MALLOC_ARENA_MAX "2"
#     MALLOC_MMAP_THRESHOLD_ "131072"
#
#   Or in ~/.config/environment.d/quickshell-mem.conf:
#     MALLOC_ARENA_MAX=2
#     MALLOC_MMAP_THRESHOLD_=131072

export MALLOC_ARENA_MAX=2
export MALLOC_MMAP_THRESHOLD_=131072
