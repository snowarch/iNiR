import http.server
import socketserver
import json
import os
import sys
from datetime import datetime

# Configuration
PORT = 50131
DB_FILE = "theme_state.json"
RAM_CACHE = {
    "css": "",
    "updatedAt": datetime.now().isoformat()
}

def load_persistence():
    global RAM_CACHE
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, 'r') as f:
                RAM_CACHE = json.load(f)
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Loaded persisted theme from {DB_FILE}")
        except Exception as e:
            print(f"Error loading persistence: {e}")

def save_persistence():
    try:
        with open(DB_FILE, 'w') as f:
            json.dump(RAM_CACHE, f)
    except Exception as e:
        print(f"Error saving persistence: {e}")

class ThemeBridgeHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Enable CORS for local testing if needed
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def do_GET(self):
        # API Route: Get Theme
        if self.path == '/api/theme' or self.path.startswith('/api/theme?'):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.end_headers()
            self.wfile.write(json.dumps(RAM_CACHE).encode())
            return
        
        # Fallback to serving static files from 'extension/dashboard'
        # If in root, serve index.html
        if self.path == '/' or not os.path.exists(os.path.join('extension/dashboard', self.path.lstrip('/'))):
            self.path = '/index.html'
        
        # Change directory to extension/dashboard for simple serving
        original_dir = os.getcwd()
        os.chdir('extension/dashboard')
        try:
            return super().do_GET()
        finally:
            os.chdir(original_dir)

    def do_POST(self):
        # API Route: Bridge Reload
        if self.path == '/api/bridge/reload':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode('utf-8')
            
            if post_data:
                RAM_CACHE["css"] = post_data
                RAM_CACHE["updatedAt"] = datetime.now().isoformat()
                save_persistence()
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Bridge Reloaded: {len(post_data)} bytes cached in RAM (and persisted)")
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "success"}).encode())
            else:
                self.send_response(400)
                self.end_headers()
            return

        self.send_response(404)
        self.end_headers()

def run():
    # Load previous state if exists
    load_persistence()

    # Ensure extension/dashboard exists
    if not os.path.exists('extension/dashboard'):
        print("Error: 'extension/dashboard' folder not found. Please run 'npm run build' first.")
        # Create a dummy index if missing for first boot
        os.makedirs('extension/dashboard', exist_ok=True)
        with open('extension/dashboard/index.html', 'w') as f:
            f.write("<h1>Building application... please refresh in a moment.</h1>")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), ThemeBridgeHandler) as httpd:
        print(f"Python Theme Bridge running at http://0.0.0.0:{PORT}")
        print("Serving from RAM cache + 'extension/dashboard' folder")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down bridge...")
            httpd.shutdown()

if __name__ == "__main__":
    run()
