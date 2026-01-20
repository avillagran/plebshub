#!/usr/bin/env bash
set -euo pipefail

# run_macos.sh - Run macOS app without Apple Developer certificate
#
# Usage:
#   ./run_macos.sh          # Build and run
#   ./run_macos.sh run      # Just run (no rebuild)
#   ./run_macos.sh flutter  # Use flutter run directly (recommended)

MODE="${1:-flutter}"

APP_DIR="build/macos/Build/Products/Debug"
APP_NAME="plebshub.app"
APP_PATH="$APP_DIR/$APP_NAME"

echo "=== PlebsHub macOS Runner ==="

case "$MODE" in
  flutter)
    echo ">>> Using flutter run (recommended for dev)..."
    exec flutter run -d macos
    ;;
  build)
    echo ">>> Building and launching..."
    flutter build macos --debug

    # Remove quarantine
    xattr -cr "$APP_PATH"

    # Open via Finder (bypasses some Gatekeeper checks)
    echo ">>> Opening app..."
    open "$APP_PATH"
    ;;
  run)
    if [[ ! -d "$APP_PATH" ]]; then
      echo "ERROR: App not found. Run './run_macos.sh build' first"
      exit 1
    fi
    xattr -cr "$APP_PATH"
    open "$APP_PATH"
    ;;
  *)
    echo "Usage: ./run_macos.sh [flutter|build|run]"
    echo "  flutter - Use flutter run directly (recommended)"
    echo "  build   - Build and open app bundle"
    echo "  run     - Just open existing app bundle"
    exit 1
    ;;
esac
