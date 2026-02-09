# Fish Shell Configuration for ii Wallpaper Theming
# This file sets up fish syntax highlighting to match the kitty terminal theme
# Colors are dynamically loaded from ~/.config/kitty/current-theme.conf

# Function to read colors from kitty theme file
function __ii_read_kitty_color --argument color_name
    if test -f ~/.config/kitty/current-theme.conf
        set -l color_value (grep "^$color_name\\s" ~/.config/kitty/current-theme.conf | awk '{print $2}' | head -1)
        if test -n "$color_value"
            echo $color_value
        end
    end
end

# Function to setup fish colors based on kitty theme
function __ii_setup_fish_colors
    # Read colors from kitty theme
    set -l foreground (__ii_read_kitty_color foreground)
    set -l background (__ii_read_kitty_color background)
    set -l color_red (__ii_read_kitty_color color1)
    set -l color_green (__ii_read_kitty_color color2)
    set -l color_yellow (__ii_read_kitty_color color3)
    set -l color_blue (__ii_read_kitty_color color4)
    set -l color_magenta (__ii_read_kitty_color color5)
    set -l color_cyan (__ii_read_kitty_color color6)
    set -l color_white (__ii_read_kitty_color color7)
    
    # Use terminal colors as fallback if theme file not readable
    if test -z "$foreground"
        # Fall back to terminal color names which will use kitty's theme
        set foreground normal
        set color_red red
        set color_green green
        set color_yellow yellow
        set color_blue blue
        set color_magenta magenta
        set color_cyan cyan
        set color_white white
    end
    
    # Fish syntax highlighting colors - using hex values when available
    # This ensures fish colors match the terminal exactly
    set -U fish_color_normal $foreground
    set -U fish_color_command $color_blue
    set -U fish_color_param $color_cyan
    set -U fish_color_keyword $color_magenta
    set -U fish_color_quote $color_green
    set -U fish_color_redirection $color_yellow
    set -U fish_color_end $color_white
    set -U fish_color_error $color_red
    set -U fish_color_comment brblack
    set -U fish_color_match --background=$color_blue
    set -U fish_color_search_match --background=$color_blue
    set -U fish_color_operator $color_yellow
    set -U fish_color_escape $color_magenta
    set -U fish_color_cwd $color_blue
    set -U fish_color_cwd_root $color_red
    set -U fish_color_valid_path --underline
    set -U fish_color_autosuggestion brblack
    set -U fish_color_user $color_green
    set -U fish_color_host $color_cyan
    set -U fish_color_host_remote $color_yellow
    set -U fish_color_cancel $color_red
    set -U fish_color_option $color_cyan
    
    # Pager colors (for tab completion)
    set -U fish_pager_color_progress $color_white
    set -U fish_pager_color_prefix $color_blue
    set -U fish_pager_color_completion $foreground
    set -U fish_pager_color_description brblack
    set -U fish_pager_color_selected_background --background=$color_blue
    set -U fish_pager_color_selected_prefix $color_blue
    set -U fish_pager_color_selected_completion $foreground
    set -U fish_pager_color_selected_description brblack
    
    # Selection and visual mode colors
    set -U fish_color_selection --background=$color_blue
    set -U fish_color_history_current --bold
    
    # Update timestamp to track last reload
    set -U __ii_fish_theme_last_reload (date +%s)
end

# Function to check if theme needs reload (called on every prompt)
function __ii_check_theme_reload --on-event fish_prompt
    if test -f ~/.cache/fish_theme_reload
        set -l last_reload (cat ~/.cache/fish_theme_reload 2>/dev/null || echo 0)
        if test "$last_reload" != "$__ii_fish_theme_last_reload"
            __ii_setup_fish_colors
        end
    end
end

# Setup colors on shell start
__ii_setup_fish_colors

# Function to reload kitty terminal colors
function __ii_reload_kitty_theme
    # Try to reload kitty config via remote control using the standard socket path
    if test -S /tmp/kitty-socket
        kitty @ --to unix:/tmp/kitty-socket load-config 2>/dev/null
        echo "Kitty theme reloaded via /tmp/kitty-socket"
    else if test -S /tmp/kitty
        kitty @ --to unix:/tmp/kitty load-config 2>/dev/null
        echo "Kitty theme reloaded via /tmp/kitty"
    else
        # Try alternative socket locations
        for socket in /tmp/kitty-*
            if test -S $socket
                kitty @ --to unix:$socket load-config 2>/dev/null
                echo "Kitty theme reloaded via $socket"
            end
        end
    end
end

# Function to reload fish colors (call this when wallpaper changes)
function ii_reload_fish_theme
    __ii_setup_fish_colors
    __ii_reload_kitty_theme
    echo "Fish and kitty themes synchronized with wallpaper colors"
end

# Make reload function available globally
function reload_fish_theme
    ii_reload_fish_theme
end
