#!/bin/bash
#
# install_on_simulator.sh – builds the demo Login app and installs it on an iPhone simulator,
# so the Execution Tool has an app to drive.
#
# Usage: ./install_on_simulator.sh [SIMULATOR-UDID]
#
set -euo pipefail
cd "$(dirname "$0")"

UDID="${1:-${SIMULATOR_UDID:-}}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | grep 'iPhone' | grep '(Booted)' | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
fi
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | grep 'iPhone' | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
fi
[[ -n "$UDID" ]] || { echo "error: no iPhone simulator found." >&2; exit 1; }

echo "Building SampleLoginApp…"
xcodebuild build \
  -project SampleLoginApp.xcodeproj \
  -scheme SampleLoginApp \
  -destination "id=$UDID" \
  -derivedDataPath build \
  -quiet

echo "Installing on simulator $UDID…"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/SampleLoginApp.app
echo "Installed com.example.automation.SampleLoginApp"
