import requests
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse

DOMAIN = "yourdomain.com"
FRP_API = "http://admin:your_password@frps:7500/api/proxy/http"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        target_domain = params.get('domain', [''])[0]

        # 1. Basic security check
        if not target_domain.endswith(DOMAIN):
            self.send_response(403)
            self.end_headers()
            return

        # 2. Check if the app is actually connected in FRP
        # We extract 'appname' from 'appname.yourdomain.com'
        subdomain = target_domain.replace(f".{DOMAIN}", "")
        
        try:
            r = requests.get(FRP_API)
            proxies = r.json().get('proxies', [])
            # Look for a proxy that matches our subdomain
            is_active = any(p['name'] == subdomain and p['status'] == 'online' for p in proxies)
            
            if is_active:
                self.send_response(200) # App is running! Issue SSL.
            else:
                self.send_response(404) # App is offline. No SSL.
        except Exception:
            self.send_response(500)
            
        self.end_headers()

HTTPServer(('0.0.0.0', 8000), Handler).serve_forever()