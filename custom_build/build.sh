#!/usr/bin/env bash
#
# Builds a Custom (Single Property) version of the Eluvio Media Wallet Roku channel.
#
# Usage:
#   ./build.sh          Build a sideloadable zip into custom_build/build/
#   ./build.sh -v       Verify configuration only (no build)
#   ./build.sh -d       Build, then install & run on a Roku device (like F5 in VS Code).
#                       Device is taken from .vscode/.env in the repo root (ROKU_IP/ROKU_PW);
#                       already-exported env vars take precedence.
#
# Configuration is read from custom_build/config/custom.properties.
# Channel poster + splash images go in custom_build/config/images/ (see README.md there).

set -euo pipefail
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

VERIFY_ONLY=false
DEPLOY=false
while getopts "vd" opt; do
    case $opt in
        v) VERIFY_ONLY=true ;;
        d) DEPLOY=true ;;
        *) exit 1 ;;
    esac
done

##############################
# Validate configuration
##############################
CONFIG_FILE="config/custom.properties"
[ -f "$CONFIG_FILE" ] || fail "$CONFIG_FILE not found"
# shellcheck disable=SC1090
source "$CONFIG_FILE"

[ -n "${APP_TITLE:-}" ] || fail "APP_TITLE is required (in $CONFIG_FILE)"
[ -n "${PROPERTY_ID:-}" ] || fail "PROPERTY_ID is required (in $CONFIG_FILE)"
[ -n "${MAJOR_VERSION:-}" ] && [ -n "${MINOR_VERSION:-}" ] && [ -n "${BUILD_VERSION:-}" ] \
    || fail "MAJOR_VERSION, MINOR_VERSION and BUILD_VERSION are required (in $CONFIG_FILE)"

IMAGES=(
    channel-poster_fhd.jpg channel-poster_hd.jpg channel-poster_sd.jpg
    splash-screen_fhd.jpg splash-screen_hd.jpg splash-screen_sd.jpg
)
for img in "${IMAGES[@]}"; do
    [ -f "config/images/$img" ] || fail "Missing image: custom_build/config/images/$img (see custom_build/config/images/README.md)"
done

[ -d ../node_modules/brighterscript ] || fail "brighterscript not installed. Run \"npm install\" in the repo root first."

echo -e "${GREEN}Configuration verified: \"$APP_TITLE\" v$MAJOR_VERSION.$MINOR_VERSION.$BUILD_VERSION -> $PROPERTY_ID${NC}"
if $VERIFY_ONLY; then
    exit 0
fi

##############################
# Copy and customize sources
##############################
# build/ mirrors the repo root layout: source/ (patched copy) -> dist/ (compiled)
BUILD_DIR="build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -R ../source "$BUILD_DIR/source"

# Patch manifest (title, version, splash color)
sed \
    -e "s|^title=.*|title=$APP_TITLE|" \
    -e "s|^major_version=.*|major_version=$MAJOR_VERSION|" \
    -e "s|^minor_version=.*|minor_version=$MINOR_VERSION|" \
    -e "s|^build_version=.*|build_version=$BUILD_VERSION|" \
    -e "s|^splash_color=.*|splash_color=${SPLASH_COLOR:-#000000}|" \
    ../source/manifest > "$BUILD_DIR/source/manifest"

# Runtime config consumed by CustomBuild.bs
cat > "$BUILD_DIR/source/config/custom_build.json" <<EOF
{
    "property_id": "$PROPERTY_ID"
}
EOF

# Branding images
cp config/images/channel-poster_*.jpg "$BUILD_DIR/source/images/poster/"
cp config/images/splash-screen_*.jpg "$BUILD_DIR/source/images/splash/"

##############################
# Compile + zip
##############################
cat > "$BUILD_DIR/bsconfig.json" <<EOF
{
    "rootDir": "source",
    "stagingDir": "dist",
    "retainStagingDir": true,
    "createPackage": false,
    "autoImportComponentScript": true,
    "diagnosticFilters": [
        "**/SGDEX/**",
        "**/SGDEX.brs"
    ],
    "files": ["**/*"]
}
EOF
(cd "$BUILD_DIR" && ../../node_modules/.bin/bsc)

SAFE_TITLE=$(echo "$APP_TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')
ZIP_NAME="${SAFE_TITLE}_v${MAJOR_VERSION}.${MINOR_VERSION}.${BUILD_VERSION}.zip"
rm -f "$BUILD_DIR/$ZIP_NAME"
(cd "$BUILD_DIR/dist" && zip -rq "../$ZIP_NAME" . -x '*.DS_Store')

echo -e "${GREEN}Build complete: custom_build/build/$ZIP_NAME${NC}"

##############################
# Optional: install & run on device
##############################
if $DEPLOY; then
    # Use the same device config as the VS Code launch configuration (.vscode/.env).
    # Already-exported ROKU_IP/ROKU_PW take precedence.
    if [ -z "${ROKU_IP:-}" ] || [ -z "${ROKU_PW:-}" ]; then
        # shellcheck disable=SC1091
        [ -f ../.vscode/.env ] && source ../.vscode/.env
    fi
    [ -n "${ROKU_IP:-}" ] && [ -n "${ROKU_PW:-}" ] || fail "Set ROKU_IP and ROKU_PW (in .vscode/.env or as env vars) to deploy"

    echo "Installing on $ROKU_IP..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --user "rokudev:$ROKU_PW" --digest \
        -F "mysubmit=Install" -F "archive=@$BUILD_DIR/$ZIP_NAME" "http://$ROKU_IP/plugin_install")
    [ "$HTTP_CODE" = "200" ] || fail "Install failed (HTTP $HTTP_CODE). Is the device at $ROKU_IP in developer mode?"

    # Installing normally auto-launches the channel; launch explicitly in case it didn't
    # (e.g. the device was showing a dialog).
    sleep 2
    if ! curl -s --max-time 5 "http://$ROKU_IP:8060/query/active-app" | grep -q 'id="dev"'; then
        curl -s -d '' "http://$ROKU_IP:8060/launch/dev" > /dev/null || true
    fi
    echo -e "${GREEN}Installed and running on $ROKU_IP (debug console: telnet $ROKU_IP 8085)${NC}"
fi
