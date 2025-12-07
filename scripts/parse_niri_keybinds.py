#!/usr/bin/env python3
"""
Parse niri config.kdl to extract keybinds for ii cheatsheet.
Outputs JSON with categorized keybinds.
"""

import json
import os
import re
import sys
from pathlib import Path


def get_niri_config_path():
    """Get the path to niri config, checking XDG and fallback."""
    xdg_config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    return Path(xdg_config) / "niri" / "config.kdl"


def parse_keybinds_from_block(binds_content: str) -> list[dict]:
    """Parse keybinds handling both single-line and multi-line formats."""
    keybinds = []
    lines = binds_content.split('\n')
    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty lines and comments
        if not line or line.startswith('//'):
            i += 1
            continue
        
        # Match keybind start: KEY_COMBO [options] { [action] }
        # Single line: Mod+Tab repeat=false { toggle-overview; }
        # Multi line: Alt+Tab { \n spawn ...; \n }
        
        match = re.match(r'^([A-Za-z0-9+_]+)\s*(.*?)(\{.*)$', line)
        if not match:
            i += 1
            continue
        
        key_combo = match.group(1)
        options = match.group(2).strip()
        rest = match.group(3)
        
        # Extract hotkey-overlay-title if present
        title_match = re.search(r'hotkey-overlay-title="([^"]+)"', options)
        overlay_title = title_match.group(1) if title_match else None
        
        # Check if action is on same line or spans multiple lines
        if re.search(r'\{[^}]+\}', rest):
            # Single line - action is complete
            action_match = re.search(r'\{\s*([^}]+)\s*\}', rest)
            action = action_match.group(1).strip().rstrip(';') if action_match else ''
        else:
            # Multi-line - collect until closing brace
            action_lines = []
            i += 1
            while i < len(lines):
                inner_line = lines[i].strip()
                if inner_line == '}':
                    break
                if inner_line and not inner_line.startswith('//'):
                    action_lines.append(inner_line.rstrip(';'))
                i += 1
            action = ' '.join(action_lines)
        
        # Parse key combo
        parts = key_combo.split('+')
        mods = []
        key = parts[-1]
        
        for part in parts[:-1]:
            if part in ('Mod', 'Super'):
                mods.append('Super')
            elif part in ('Alt', 'Shift', 'Ctrl'):
                mods.append(part)
            else:
                mods.append(part)
        
        # Handle XF86 keys
        if key.startswith('XF86Audio'):
            key = key.replace('XF86Audio', '').replace('RaiseVolume', 'Vol+').replace('LowerVolume', 'Vol-')
        elif key.startswith('XF86MonBrightness'):
            key = key.replace('XF86MonBrightness', 'Brightness').replace('Up', '+').replace('Down', '-')
        elif key.startswith('XF86'):
            key = key.replace('XF86', '')
        
        # Generate comment - prefer overlay title
        comment = overlay_title if overlay_title else generate_comment(action)
        
        keybinds.append({
            'mods': mods,
            'key': key,
            'action': action,
            'comment': comment
        })
        
        i += 1
    
    return keybinds


# Comprehensive action mappings
ACTION_MAP = {
    # System
    'toggle-overview': 'Niri Overview',
    'quit': 'Quit Niri',
    'toggle-keyboard-shortcuts-inhibit': 'Toggle shortcuts inhibit',
    'power-off-monitors': 'Power off monitors',
    'show-hotkey-overlay': 'Niri hotkey overlay',
    
    # Window management
    'close-window': 'Close window',
    'maximize-column': 'Maximize column',
    'fullscreen-window': 'Fullscreen',
    'toggle-window-floating': 'Toggle floating',
    'center-column': 'Center column',
    'consume-or-expel-window-left': 'Consume/expel left',
    'consume-or-expel-window-right': 'Consume/expel right',
    'expel-window-from-column': 'Expel from column',
    'consume-window-into-column': 'Consume into column',
    
    # Focus
    'focus-column-left': 'Focus left',
    'focus-column-right': 'Focus right',
    'focus-window-up': 'Focus up',
    'focus-window-down': 'Focus down',
    'focus-column-first': 'Focus first column',
    'focus-column-last': 'Focus last column',
    'focus-monitor-left': 'Focus monitor left',
    'focus-monitor-right': 'Focus monitor right',
    'focus-monitor-up': 'Focus monitor up',
    'focus-monitor-down': 'Focus monitor down',
    
    # Move
    'move-column-left': 'Move left',
    'move-column-right': 'Move right',
    'move-window-up': 'Move up',
    'move-window-down': 'Move down',
    'move-column-to-first': 'Move to first',
    'move-column-to-last': 'Move to last',
    'move-column-to-monitor-left': 'Move to monitor left',
    'move-column-to-monitor-right': 'Move to monitor right',
    'move-column-to-monitor-up': 'Move to monitor up',
    'move-column-to-monitor-down': 'Move to monitor down',
    
    # Workspaces
    'focus-workspace-up': 'Previous workspace',
    'focus-workspace-down': 'Next workspace',
    'move-column-to-workspace-up': 'Move to prev workspace',
    'move-column-to-workspace-down': 'Move to next workspace',
    'move-workspace-up': 'Move workspace up',
    'move-workspace-down': 'Move workspace down',
    
    # Screenshots
    'screenshot': 'Screenshot',
    'screenshot-screen': 'Screenshot screen',
    'screenshot-window': 'Screenshot window',
}

# IPC target/function mappings
IPC_MAP = {
    ('altSwitcher', 'next'): 'Next window',
    ('altSwitcher', 'previous'): 'Previous window',
    ('overlay', 'toggle'): 'ii Overlay',
    ('overview', 'toggle'): 'ii Overview',
    ('clipboard', 'toggle'): 'Clipboard',
    ('lock', 'activate'): 'Lock screen',
    ('region', 'screenshot'): 'Screenshot region',
    ('region', 'ocr'): 'OCR region',
    ('region', 'search'): 'Reverse image search',
    ('wallpaperSelector', 'toggle'): 'Wallpaper selector',
    ('settings', 'open'): 'Settings',
    ('cheatsheet', 'toggle'): 'Cheatsheet',
    ('panelFamily', 'cycle'): 'Cycle panel style',
    ('audio', 'volumeUp'): 'Volume up',
    ('audio', 'volumeDown'): 'Volume down',
    ('audio', 'mute'): 'Mute audio',
    ('audio', 'micMute'): 'Mute microphone',
    ('brightness', 'increment'): 'Brightness up',
    ('brightness', 'decrement'): 'Brightness down',
    ('mpris', 'playPause'): 'Play/Pause',
    ('mpris', 'next'): 'Next track',
    ('mpris', 'previous'): 'Previous track',
    ('notifications', 'clearAll'): 'Clear notifications',
    ('gamemode', 'toggle'): 'Toggle game mode',
}

# App detection
TERMINALS = ['foot', 'kitty', 'alacritty', 'wezterm', 'ghostty', 'konsole', 'gnome-terminal']
FILE_MANAGERS = ['dolphin', 'nautilus', 'thunar', 'nemo', 'pcmanfm', 'ranger']
BROWSERS = ['firefox', 'zen-browser', 'chromium', 'brave', 'vivaldi']


def generate_comment(action: str) -> str:
    """Generate a human-readable comment from the action."""
    action = action.strip()
    
    # Direct niri actions
    if action in ACTION_MAP:
        return ACTION_MAP[action]
    
    # Focus/move workspace N
    ws_match = re.match(r'(focus-workspace|move-column-to-workspace)\s+(\d+)', action)
    if ws_match:
        ws_action = 'Focus' if 'focus' in ws_match.group(1) else 'Move to'
        return f'{ws_action} workspace {ws_match.group(2)}'
    
    # Spawn commands
    if action.startswith('spawn'):
        # ii IPC calls
        ipc_match = re.search(r'ipc.*call.*"(\w+)".*"(\w+)"', action)
        if ipc_match:
            target, func = ipc_match.groups()
            return IPC_MAP.get((target, func), f'{target} {func}')
        
        # Terminal
        if any(term in action for term in TERMINALS):
            return 'Terminal'
        
        # File manager
        if any(fm in action for fm in FILE_MANAGERS):
            return 'File manager'
        
        # Browser
        if any(br in action for br in BROWSERS):
            return 'Browser'
        
        # Volume (wpctl)
        if 'wpctl' in action:
            if 'set-volume' in action:
                return 'Volume up' if '+' in action else 'Volume down'
            if 'set-mute' in action:
                return 'Mute toggle'
        
        # Brightness
        if 'brightnessctl' in action or 'light' in action:
            return 'Brightness up' if '+' in action or 'inc' in action else 'Brightness down'
        
        # Close window script
        if 'close-window' in action:
            return 'Close window'
        
        # Generic spawn - extract app name
        spawn_match = re.search(r'spawn\s+"([^"]+)"', action)
        if spawn_match:
            app = spawn_match.group(1)
            if '/' in app:
                app = app.split('/')[-1]
            return app
    
    return action[:30] + '...' if len(action) > 30 else action


def categorize_keybind(kb: dict) -> str:
    """Determine category for a keybind based on its action/comment."""
    comment = kb['comment'].lower()
    action = kb.get('action', '').lower()
    
    # System
    if any(x in comment for x in ['niri overview', 'quit niri', 'inhibit', 'power off', 'hotkey overlay']):
        return 'System'
    
    # ii Shell
    if any(x in comment for x in ['ii ', 'clipboard', 'lock screen', 'wallpaper', 'settings', 'cheatsheet', 'panel style']):
        return 'ii Shell'
    if re.search(r'ipc.*call.*(overlay|overview|clipboard|lock|wallpaper|settings|cheatsheet|panelfamily)', action):
        return 'ii Shell'
    
    # Window Switcher
    if 'window' in comment and ('next' in comment or 'previous' in comment):
        return 'Window Switcher'
    if 'altswitcher' in action:
        return 'Window Switcher'
    
    # Screenshots
    if any(x in comment for x in ['screenshot', 'ocr', 'image search']):
        return 'Screenshots'
    
    # Applications
    if any(x in comment for x in ['terminal', 'file manager', 'browser']):
        return 'Applications'
    if any(x in action for x in TERMINALS + FILE_MANAGERS + BROWSERS):
        return 'Applications'
    
    # Window Management
    if any(x in comment for x in ['close', 'maximize', 'fullscreen', 'floating', 'consume', 'expel', 'center']):
        return 'Window Management'
    if 'close-window' in action:
        return 'Window Management'
    
    # Focus
    if 'focus' in comment and 'workspace' not in comment:
        return 'Focus'
    
    # Move Windows
    if 'move' in comment and 'workspace' not in comment and 'track' not in comment:
        return 'Move Windows'
    
    # Workspaces
    if 'workspace' in comment:
        return 'Workspaces'
    
    # Media
    if any(x in comment for x in ['volume', 'mute', 'play', 'pause', 'track', 'audio', 'microphone']):
        return 'Media'
    if 'mpris' in action or 'audio' in action:
        return 'Media'
    
    # Brightness
    if 'brightness' in comment:
        return 'Brightness'
    
    return 'Other'


def find_binds_block(content: str) -> str | None:
    """Find the binds { } block handling nested braces."""
    match = re.search(r'\bbinds\s*\{', content)
    if not match:
        return None
    
    start = match.end()
    depth = 1
    i = start
    
    while i < len(content) and depth > 0:
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
        i += 1
    
    return content[start:i-1] if depth == 0 else None


def parse_niri_config(config_path: Path) -> dict:
    """Parse the niri config and extract keybinds."""
    if not config_path.exists():
        return {'error': f'Config not found: {config_path}', 'children': []}
    
    content = config_path.read_text()
    binds_content = find_binds_block(content)
    if not binds_content:
        return {'error': 'No binds block found', 'children': []}
    
    keybinds = parse_keybinds_from_block(binds_content)
    keybinds_by_category = {}
    
    for kb in keybinds:
        category = categorize_keybind(kb)
        if category not in keybinds_by_category:
            keybinds_by_category[category] = []
        keybinds_by_category[category].append({
            'mods': kb['mods'],
            'key': kb['key'],
            'comment': kb['comment']
        })
    
    category_order = [
        'System', 'ii Shell', 'Window Switcher', 'Screenshots',
        'Applications', 'Window Management', 'Focus', 'Move Windows',
        'Workspaces', 'Media', 'Brightness', 'Other'
    ]
    
    children = []
    for cat in category_order:
        if cat in keybinds_by_category and keybinds_by_category[cat]:
            children.append({
                'name': cat,
                'children': [{'keybinds': keybinds_by_category[cat]}]
            })
    
    return {'children': children, 'configPath': str(config_path)}


def main():
    config_path = get_niri_config_path()
    if len(sys.argv) > 1:
        config_path = Path(sys.argv[1])
    
    result = parse_niri_config(config_path)
    print(json.dumps(result))


if __name__ == '__main__':
    main()
