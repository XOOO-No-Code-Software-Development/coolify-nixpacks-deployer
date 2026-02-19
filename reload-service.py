#!/usr/bin/env python3
"""
System Reload Service
Runs on port 9000 to handle hot reload requests
Completely independent of user's backend code
"""

import os
import subprocess
import json
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 9000

class ReloadHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[Reload Service] {format % args}")
    
    def do_POST(self):
        """Handle POST /reload?chatId=X&versionId=Y"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path != '/reload':
            self.send_error(404, "Not Found")
            return
        
        # Parse query parameters
        params = parse_qs(parsed_path.query)
        chat_id = params.get('chatId', [None])[0]
        version_id = params.get('versionId', [None])[0]
        
        if not chat_id or not version_id:
            self.send_error(400, "Missing chatId or versionId")
            return
        
        print(f"[Reload Service] 🔄 Reloading chat={chat_id}, version={version_id}")
        
        # Execute reload script
        try:
            # Execute reload script with real-time output streaming
            result = subprocess.run(
                ['bash', 'reload-source.sh', chat_id, version_id],
                timeout=60,
                cwd=os.path.dirname(os.path.abspath(__file__))
            )
            
            response = {
                "success": result.returncode == 0,
                "chatId": chat_id,
                "versionId": version_id,
                "message": "Reload completed" if result.returncode == 0 else "Reload failed"
            }
            
            self.send_response(200 if result.returncode == 0 else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
            
            if result.returncode == 0:
                print(f"[Reload Service] ✅ Reload successful")
            else:
                print(f"[Reload Service] ❌ Reload failed: {result.stderr}")
            
        except subprocess.TimeoutExpired:
            print(f"[Reload Service] ⏱️  Reload timeout")
            self.send_error(504, "Reload timeout")
        except Exception as e:
            print(f"[Reload Service] ❌ Error: {str(e)}")
            self.send_error(500, str(e))
    
    def do_GET(self):
        """Handle GET / - Auto-reload with latest version"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy", "service": "reload"}).encode())
            return
        
        if parsed_path.path == '/' or parsed_path.path == '':
            # Auto-reload with latest version
            self._handle_auto_reload()
        else:
            self.send_error(404, "Not Found")
    
    def _handle_auto_reload(self):
        """Fetch latest version from v0 API and trigger reload"""
        print(f"[Reload Service] 🔄 Auto-reload triggered via GET /")
        
        # Get CHAT_ID from environment
        chat_id = os.getenv('CHAT_ID')
        if not chat_id:
            self.send_error(500, "CHAT_ID not configured")
            print(f"[Reload Service] ❌ CHAT_ID environment variable not set")
            return
        
        # Get v0 API credentials
        v0_api_key = os.getenv('V0_API_KEY')
        v0_api_url = os.getenv('V0_API_URL', 'https://api.v0.dev/v1')
        
        if not v0_api_key:
            self.send_error(500, "V0_API_KEY not configured")
            print(f"[Reload Service] ❌ V0_API_KEY not set")
            return
        
        print(f"[Reload Service] 📡 Fetching latest version for chat: {chat_id}")
        
        try:
            # Fetch chat details to get latest version
            chat_url = f"{v0_api_url}/chats/{chat_id}"
            req = urllib.request.Request(
                chat_url,
                headers={
                    'Authorization': f'Bearer {v0_api_key}',
                    'Content-Type': 'application/json'
                }
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                chat_data = json.loads(response.read().decode())
            
            # Extract latest version ID
            latest_version = chat_data.get('latestVersion')
            if not latest_version or not latest_version.get('id'):
                self.send_error(404, "No versions found for this chat")
                print(f"[Reload Service] ❌ No versions found")
                return
            
            version_id = latest_version['id']
            print(f"[Reload Service] ✅ Found latest version: {version_id}")
            print(f"[Reload Service] 📥 Downloading version files...")
            
            # Execute reload script
            # Execute reload script with real-time output streaming
            result = subprocess.run(
                ['bash', 'reload-source.sh', chat_id, version_id],
                timeout=60,
                cwd=os.path.dirname(os.path.abspath(__file__))
            )
            
            response_data = {
                "success": result.returncode == 0,
                "chatId": chat_id,
                "versionId": version_id,
                "message": "Auto-reload completed" if result.returncode == 0 else "Auto-reload failed"
            }
            
            self.send_response(200 if result.returncode == 0 else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response_data).encode())
            
            if result.returncode == 0:
                print(f"[Reload Service] ✅ Auto-reload successful")
            else:
                print(f"[Reload Service] ❌ Auto-reload failed: {result.stderr}")
        
        except urllib.error.HTTPError as e:
            error_msg = f"HTTP {e.code}: {e.reason}"
            print(f"[Reload Service] ❌ v0 API error: {error_msg}")
            self.send_error(502, f"v0 API error: {error_msg}")
        except urllib.error.URLError as e:
            print(f"[Reload Service] ❌ Network error: {str(e.reason)}")
            self.send_error(502, f"Network error: {str(e.reason)}")
        except subprocess.TimeoutExpired:
            print(f"[Reload Service] ⏱️  Reload timeout")
            self.send_error(504, "Reload timeout")
        except Exception as e:
            print(f"[Reload Service] ❌ Error: {str(e)}")
            self.send_error(500, str(e))

def run_server():
    """Start the reload service"""
    server = HTTPServer(('0.0.0.0', PORT), ReloadHandler)
    print(f"[Reload Service] 🚀 Starting on port {PORT}")
    print(f"[Reload Service] 📡 POST /reload?chatId=X&versionId=Y - Reload specific version")
    print(f"[Reload Service] 🔄 GET / - Auto-reload with latest version")
    print(f"[Reload Service] 💚 GET /health - Health check")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"[Reload Service] 🛑 Shutting down...")
        server.shutdown()

if __name__ == '__main__':
    run_server()
