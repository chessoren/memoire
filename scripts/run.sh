#!/bin/zsh
# Build + install + launch on the dedicated demo simulator. Extra args are passed as launch arguments.

cd "$(dirname $0)/.."
ID=$(cat scripts/.cache/sim-id)
xcodebuild -project Memoire.xcodeproj -scheme Memoire -destination "id=$ID" -derivedDataPath /tmp/memoire-dd build 2>&1 | grep -E "error:|BUILD" | head -30
xcrun simctl terminate $ID app.memoire.family 2>/dev/null || true
xcrun simctl install $ID /tmp/memoire-dd/Build/Products/Debug-iphonesimulator/Memoire.app
xcrun simctl launch $ID app.memoire.family "$@" >/dev/null
