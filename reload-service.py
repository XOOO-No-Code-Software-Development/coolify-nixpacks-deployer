#!/usr/bin/env python3
"""
System Reload Service
Runs on port 9000 to handle hot reload requests
Completely independent of user's backend code
"""

import os
import subprocess
import json
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
            result = subprocess.run(
                ['bash', 'reload-source.sh', chat_id, version_id],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=os.path.dirname(os.path.abspath(__file__))
            )
            
            response = {
                "success": result.returncode == 0,
                "chatId": chat_id,
                "versionId": version_id,
                "message": "Reload completed" if result.returncode == 0 else "Reload failed",
                "output": result.stdout,
                "error": result.stderr if result.returncode != 0 else None
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
        """Health check endpoint"""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy", "service": "reload"}).encode())
        else:
            self.send_error(404, "Not Found")

def run_server():
    """Start the reload service"""
    server = HTTPServer(('0.0.0.0', PORT), ReloadHandler)
    print(f"[Reload Service] 🚀 Starting on port {PORT}")
    print(f"[Reload Service] 📡 Endpoint: POST /reload?chatId=X&versionId=Y")
    print(f"[Reload Service] 💚 Health check: GET /health")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"[Reload Service] 🛑 Shutting down...")
        server.shutdown()

if __name__ == '__main__':
    run_server()
