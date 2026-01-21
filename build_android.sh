#!/bin/bash
# Build and install PlebsHub on Android in release mode
#
# Usage:
#   ./build_android.sh                    # Uses default device
#   ./build_android.sh J75T59BAZD45TG85   # Uses specific device ID

set -e

DEVICE_ID="${1:-}"

echo "🔨 Building release APK..."
flutter build apk --release

echo ""
echo "📱 Installing on device..."
if [ -n "$DEVICE_ID" ]; then
    flutter install --release -d "$DEVICE_ID"
else
    flutter install --release
fi

echo ""
echo "✅ Done! App installed in release mode."
