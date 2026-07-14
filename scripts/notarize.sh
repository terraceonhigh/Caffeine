#!/usr/bin/env bash
# Submit one artifact (.app or .dmg) to Apple's notary service, wait for the
# verdict, and staple the ticket on success. On anything other than "Accepted",
# dump the notary log (which names the actual reason) and fail — otherwise a
# rejection surfaces downstream as a useless "Error 65" from stapler.
#
# Usage: scripts/notarize.sh <path-to-.app-or-.dmg>
# Requires env: APPLE_ID, APPLE_TEAM_ID, APPLE_APP_SPECIFIC_PASSWORD
set -euo pipefail

ARTIFACT="$1"
SUBMIT="$ARTIFACT"

# notarytool wants a zip for a .app bundle; a .dmg is submitted directly.
if [[ "$ARTIFACT" == *.app ]]; then
    SUBMIT="${ARTIFACT%.app}.zip"
    ditto -c -k --keepParent "$ARTIFACT" "$SUBMIT"
fi

OUT="$(xcrun notarytool submit "$SUBMIT" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait --output-format json)"
echo "$OUT"

ID="$(printf '%s' "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')"
STATUS="$(printf '%s' "$OUT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["status"])')"

if [ "$STATUS" != "Accepted" ]; then
    echo "::error::Notarization returned '$STATUS' for $ARTIFACT — notary log follows:"
    xcrun notarytool log "$ID" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" || true
    exit 1
fi

xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
