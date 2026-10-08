#!/bin/bash
# Translation management script - convenient wrapper

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSLATIONS_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$(dirname "$TRANSLATIONS_DIR")"

show_help() {
    echo "Translation Management Tool - Convenient Wrapper"
    echo ""
    echo "Usage: $0 [options] <command>"
    echo ""
    echo "Commands:"
    echo "  extract      Discover literal Translation.tr source strings (informational)"
    echo "  update       Legacy source-driven locale maintenance (manual)"
    echo "  clean        Remove locale keys not present in canonical en_US"
    echo "  sync         Sync locale keys from canonical en_US"
    echo "  status       Validate source coverage and locale structure"
    echo ""
    echo "Options:"
    echo "  -l, --lang LANG     Specify language (e.g.: zh_CN)"
    echo "  -t, --trans-dir DIR Translation files directory (default: $TRANSLATIONS_DIR)"
    echo "  -s, --source-dir DIR Source code directory (default: $SOURCE_DIR)"
    echo "  -y, --yes           Skip all confirmation prompts (auto-confirm)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 extract                    # Extract translatable texts"
    echo "  $0 update -l zh_CN           # Update Chinese translations"
    echo "  $0 update                    # Update all translations"
    echo "  $0 clean                     # Clean unused keys"
    echo "  $0 sync                      # Sync keys across all languages"
    echo "  $0 status                    # Show translation status"
}

show_status() {
    echo "Analyzing canonical runtime localization..."
    echo ""
    echo "=== Canonical Catalog ==="
    python3 - "$TRANSLATIONS_DIR/en_US.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
print(f"  en_US: {len(data)} canonical keys")
PY
    echo ""
    echo "=== Locale Guides ==="
    python3 "$SCRIPT_DIR/l10n.py" audit-guides
    echo ""
    echo "=== Source Coverage ==="
    python3 "$SCRIPT_DIR/l10n.py" audit-source
    echo ""
    echo "=== Locale Structure ==="
    python3 "$SCRIPT_DIR/l10n.py" audit-all
    echo ""
    echo "The legacy extract command is discovery-only; canonical status is defined above."
}

# Parse command line arguments
LANG_CODE=""
COMMAND=""
YES_FLAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--lang)
            LANG_CODE="$2"
            shift 2
            ;;
        -t|--trans-dir)
            TRANSLATIONS_DIR="$2"
            shift 2
            ;;
        -s|--source-dir)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -y|--yes)
            YES_FLAG="-y"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        extract|update|clean|sync|status)
            if [ -n "$COMMAND" ]; then
                echo "Error: Only one command can be specified"
                exit 1
            fi
            COMMAND="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ -z "$COMMAND" ]; then
    echo "Error: A command must be specified"
    show_help
    exit 1
fi

# Check dependencies
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required"
    exit 1
fi

# Build base arguments
BASE_ARGS="--translations-dir $TRANSLATIONS_DIR --source-dir $SOURCE_DIR"

case $COMMAND in
    extract)
        echo "Extracting translatable texts..."
        python3 "$SCRIPT_DIR/translation-manager.py" $BASE_ARGS $YES_FLAG --extract-only --show-temp
        ;;
    update)
        echo "Legacy source-driven translation maintenance..."
        echo "Note: en_US.json is canonical; use status/audit-source before accepting catalog changes."
        if [ -n "$LANG_CODE" ]; then
            python3 "$SCRIPT_DIR/translation-manager.py" $BASE_ARGS $YES_FLAG --language "$LANG_CODE"
        else
            python3 "$SCRIPT_DIR/translation-manager.py" $BASE_ARGS $YES_FLAG
        fi
        ;;
    clean)
        echo "Cleaning unused translation keys..."
        python3 "$SCRIPT_DIR/translation-cleaner.py" $BASE_ARGS $YES_FLAG --clean
        ;;
    sync)
        echo "Syncing translation keys..."
        python3 "$SCRIPT_DIR/translation-cleaner.py" $BASE_ARGS $YES_FLAG --sync
        ;;
    status)
        show_status
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
