#!/bin/bash
# The same gate locally and in CI: secrets, lint, then build and unit tests.
# Pick a simulator with: DESTINATION='id=<simulator id>' scripts/check.sh
# (list them with: xcrun simctl list devices available). With several OS
# versions installed, a bare device name can match nothing, so the default
# is the first available iPhone simulator, by id.
set -e
cd "$(dirname "$0")/.."

if [ -z "${DESTINATION:-}" ]; then
  SIMULATOR_ID=$(xcrun simctl list devices available | grep -m1 "iPhone" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
  DESTINATION="id=$SIMULATOR_ID"
fi

echo "check: secrets"
scripts/check-secrets.sh

if command -v swiftlint >/dev/null 2>&1; then
  echo "check: swiftlint"
  swiftlint lint --strict --quiet
else
  echo "check: swiftlint not installed, skipping lint"
fi

echo "check: build and test ($DESTINATION)"
xcodebuild test \
  -project Crossdrive.xcodeproj \
  -scheme Crossdrive \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

echo "check: passed"
