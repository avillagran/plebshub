#!/usr/bin/env bash
set -euo pipefail

# run_web.sh - Run Flutter web app
#
# Usage:
#   ./run_web.sh              # Run in Chrome (default)
#   ./run_web.sh chrome       # Run in Chrome
#   ./run_web.sh edge         # Run in Edge
#   ./run_web.sh server       # Run web server only (no browser)
#   ./run_web.sh build        # Build release for deployment
#   ./run_web.sh serve        # Build and serve release locally

MODE="${1:-chrome}"
PORT="${2:-8080}"

echo "=== PlebsHub Web Runner ==="

case "$MODE" in
  chrome)
    echo ">>> Running in Chrome (with CORS headers for SQLite WASM)..."
    exec flutter run -d chrome --web-port="$PORT" \
      --web-header=Cross-Origin-Opener-Policy=same-origin \
      --web-header=Cross-Origin-Embedder-Policy=require-corp
    ;;
  edge)
    echo ">>> Running in Edge (with CORS headers for SQLite WASM)..."
    exec flutter run -d edge --web-port="$PORT" \
      --web-header=Cross-Origin-Opener-Policy=same-origin \
      --web-header=Cross-Origin-Embedder-Policy=require-corp
    ;;
  server)
    echo ">>> Running web server only (with CORS headers)..."
    exec flutter run -d web-server --web-port="$PORT" \
      --web-header=Cross-Origin-Opener-Policy=same-origin \
      --web-header=Cross-Origin-Embedder-Policy=require-corp
    ;;
  build)
    echo ">>> Building release for deployment..."
    flutter build web --release
    echo ">>> Build complete: build/web/"
    echo "    Deploy the contents of build/web/ to your web server"
    ;;
  serve)
    echo ">>> Building and serving release locally..."
    flutter build web --release
    echo ">>> Serving at http://localhost:$PORT"
    echo "    (With CORS headers for SQLite WASM)"
    cd build/web && python3 -c "
import http.server
import socketserver

class WASMHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

    def guess_type(self, path):
        if path.endswith('.wasm'):
            return 'application/wasm'
        return super().guess_type(path)

with socketserver.TCPServer(('', $PORT), WASMHandler) as httpd:
    print('Server running at http://localhost:$PORT')
    httpd.serve_forever()
"
    ;;
  *)
    echo "Usage: ./run_web.sh [chrome|edge|server|build|serve] [port]"
    echo "  chrome  - Run in Chrome browser (default)"
    echo "  edge    - Run in Edge browser"
    echo "  server  - Run web server only, no browser"
    echo "  build   - Build release for deployment"
    echo "  serve   - Build release and serve locally"
    echo ""
    echo "  port    - Optional port number (default: 8080)"
    exit 1
    ;;
esac
