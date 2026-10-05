#!/usr/bin/env bash
# Deploy gate for the iNiR shell.
#
# Why this file exists. `is-active` plus "some qs process exists" stays green
# while the shell runs the PREVIOUS version, because QML is read into memory at
# shell start, so both checks report on code that was never running. This gate
# fails loudly on exactly that, and on a stale crash from a previous shell still
# inside the journal window.
set -uo pipefail

R=/home/luis/Projects/Inir/iNiR
L=/home/luis/.config/quickshell/inir
TS=$(date -u +%Y%m%dT%H%M%SZ)
rc=0

shell_pid() { ps -eo pid,args --no-headers | grep -F "/usr/bin/qs -n -p $L" | grep -v grep | awk '{print $1}' | head -1; }
shell_age() { local p; p=$(shell_pid); [ -z "$p" ] && { echo -1; return; }; ps -o etimes= -p "$p" 2>/dev/null | tr -d ' '; }

echo "═══ 1. ficheros (solo los que git dice) ═══"
mapfile -t FILES < <(cd "$R" && git status --porcelain | awk '{print $2}')
if [ ${#FILES[@]} -eq 0 ]; then
  echo "  (nada modificado)"
else
  for P in "${FILES[@]}"; do
    mkdir -p "$L/$(dirname "$P")"
    [ -f "$L/$P" ] && cp -a "$L/$P" "$L/$P.bak-$TS"
    if [[ "$P" == *.py ]]; then M=755; else M=644; fi
    install -D -m "$M" "$R/$P" "$L/$P"
    cmp -s "$R/$P" "$L/$P" && echo "  ok $M $P" || { echo "  *** DIF $P"; rc=1; }
  done
fi

OLD_PID=$(shell_pid); OLD_AGE=$(shell_age)
echo "═══ 2. reiniciar ═══"
echo "  shell antes: PID=${OLD_PID:-ninguno} edad=${OLD_AGE}s"
systemctl --user reset-failed inir.service 2>/dev/null
systemctl --user restart inir.service; echo "  systemctl rc=$?"
sleep 5

echo "═══ 3. ¿el shell es NUEVO? ═══"
NEW_PID=$(shell_pid); NEW_AGE=$(shell_age)
echo "  shell ahora: PID=${NEW_PID:-NINGUNO} edad=${NEW_AGE}s"
if [ -z "$NEW_PID" ]; then
  echo "  *** NO HAY SHELL. rc=1"; rc=1
elif [ "$NEW_PID" = "$OLD_PID" ] && [ "${OLD_AGE:-0}" -lt 1000 ]; then
  echo "  *** MISMO PID ($NEW_PID) y no parece rehecho — el reinicio no cuajó. rc=1"; rc=1
else
  echo "  PID distinto: sí arrancó de verdad"
fi

echo "  ── ¿ejecuta el código recién escrito? ──"
STALE=0
for P in "${FILES[@]}"; do
  [ -f "$L/$P" ] || continue
  MT=$(stat -c %Y "$L/$P"); AGE=$(( $(date +%s) - MT ))
  # 5 s of grace: the restart lands in the same second as the install, and a 1 s
  # difference is not staleness. Staleness is the shell being OLDER than the
  # files it claims to be running.
  if [ "${NEW_AGE:--1}" -ge 0 ] && [ $((AGE - NEW_AGE)) -gt 5 ]; then
    echo "  *** $P se escribió hace ${AGE}s y el shell lleva ${NEW_AGE}s: CORRE LA VERSIÓN VIEJA. rc=1"
    STALE=1
  fi
done
[ "$STALE" = 0 ] && echo "  sí: el shell es más nuevo que todo lo desplegado"

echo "═══ 4. vida y errores ═══"
echo -n "  is-active: "; systemctl --user is-active inir.service
# Why the pattern is not "Failed to load": that phrase also appears in
# `quickshell.service.sni.item: Failed to load tray item ":1.x/..."`, which is
# Quickshell's system-tray reader warning that a StatusNotifierItem's owner had
# already exited. It arrives from a different module and says nothing about
# QML, so matching it reports ROJO on a perfectly healthy shell.
#
# A gate that cries wolf is worse than no gate: its word is worth nothing
# unless it is right in both directions.
#
# The QML failures it must catch are unambiguous instead: 'Type X unavailable',
# 'is not a type', 'cannot assign', 'is not a function', a capitalised property
# name, a parse Token error, or a shell exit status=255.
# Only since THIS shell started. A fixed lookback window reports ROJO for a
# crash that was already fixed, because the dead shell's errors are still
# inside the window.
SINCE=$(systemctl --user show inir.service -p ExecMainStartTimestamp --value 2>/dev/null)
[ -z "$SINCE" ] && SINCE='-45 seconds'
J=$(journalctl --user -u inir.service --since "$SINCE" --no-pager -o cat 2>/dev/null \
  | grep -aiE 'unavailable|not a type|cannot assign|is not a function|status=255|Property names cannot|Token|Expected' \
  | grep -avE 'AccountsService|tailscale|imgStatus|FaceAvatar|nm_applet|SNI|Binding loop|Cannot open')
if [ -n "$J" ]; then echo "$J" | sed 's/^/  *** /'; rc=1; else echo "  sin errores de carga"; fi

echo "═══ resultado: $([ $rc = 0 ] && echo VERDE || echo ROJO) ═══"
exit $rc