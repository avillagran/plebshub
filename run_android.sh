#!/bin/bash
# Run PlebsHub on Android device/emulator
#
# Usage:
#   ./run_android.sh              # Uses default device
#   ./run_android.sh J75T59BAZD45TG85  # Uses specific device ID

set -e

DEVICE_ID="${1:-android}"

echo "🔍 Connected Android devices:"
flutter devices | grep -i android || true

echo ""
echo "🚀 Building and running on device: $DEVICE_ID"
flutter run -d "$DEVICE_ID"
