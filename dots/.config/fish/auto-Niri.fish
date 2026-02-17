# Auto start Niri on tty1
if test -z "$DISPLAY" ;and test "$XDG_VTNR" -eq 1
    mkdir -p ~/.cache
    exec niri-session > ~/.cache/niri.log 2>&1
end
