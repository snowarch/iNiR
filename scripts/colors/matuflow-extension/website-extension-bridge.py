#!/usr/bin/env python3
import sys
import os
import requests
import argparse
import time

def sync_theme(url, file_path):
    """Reads the local file and pushes it to the RAM cache of the bridge server."""
    # Expand tildes (~) automatically to avoid errors in matugen/shell hooks
    file_path = os.path.expanduser(file_path)
    
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return False
    
    try:
        with open(file_path, 'r') as f:
            css_content = f.read()
        
        headers = {'Content-Type': 'text/css'}
        response = requests.post(f"{url}/api/bridge/reload", data=css_content, headers=headers)
        
        if response.status_code == 200:
            print(f"Successfully pushed theme ({len(css_content)} bytes)")
            return True
        else:
            print(f"Failed to push theme. Server returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"Error during sync: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="MatuFlow Theme Bridge CLI")
    parser.add_argument("--url", default="http://localhost:50131", help="The URL of the MatuFlow dashboard")
    parser.add_argument("--file", default=os.path.expanduser("~/.local/state/quickshell/user/generated/palette.css"), help="Path to the system CSS file")
    parser.add_argument("--reload", action="store_true", help="One-shot sync and exit (perfect for matugen post_theme)")
    parser.add_argument("--watch", action="store_true", help="Run as a background service and watch for file changes")
    
    args = parser.parse_args()

    # Normalize URL
    url = args.url.rstrip('/')

    if args.reload:
        sync_theme(url, args.file)
        sys.exit(0)

    if args.watch:
        print(f"Bridge service started. Watching {args.file}...")
        print("Press Ctrl+C to stop.")
        last_mtime = 0
        while True:
            try:
                if os.path.exists(args.file):
                    current_mtime = os.path.getmtime(args.file)
                    if current_mtime != last_mtime:
                        sync_theme(url, args.file)
                        last_mtime = current_mtime
                time.sleep(1) # Check every second
            except KeyboardInterrupt:
                print("\nBridge stopped.")
                break
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
