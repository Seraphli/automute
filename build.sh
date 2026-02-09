#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== AutoMute Build Script ==="

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Install Xcode Command Line Tools.${NC}"
    exit 1
fi

if ! command -v pod &> /dev/null; then
    echo -e "${RED}Error: CocoaPods not found. Install with: gem install cocoapods${NC}"
    exit 1
fi

# Extract signing certificates from keychain
echo ""
echo "Finding code signing certificates..."

CERT_LIST=$(security find-identity -v -p codesigning | grep -E '^\s+[0-9]+\)' | sed 's/.*"\(.*\)"/\1/')

if [ -z "$CERT_LIST" ]; then
    echo -e "${RED}Error: No code signing certificates found in keychain.${NC}"
    exit 1
fi

IFS=$'\n' read -rd '' -a CERTS <<< "$CERT_LIST" || true

if [ ${#CERTS[@]} -eq 1 ]; then
    SELECTED_CERT="${CERTS[0]}"
    echo "Found certificate: $SELECTED_CERT"
else
    echo "Found ${#CERTS[@]} certificates:"
    for i in "${!CERTS[@]}"; do
        echo "  $((i+1))) ${CERTS[$i]}"
    done
    read -p "Select certificate (1-${#CERTS[@]}): " CERT_INDEX
    SELECTED_CERT="${CERTS[$((CERT_INDEX-1))]}"
fi

# Extract Team ID (OU field) from certificate X.509 subject
TEAM_ID=$(security find-certificate -c "$SELECTED_CERT" -p | openssl x509 -noout -subject | sed 's/.*OU = \([^,]*\).*/\1/')
# Extract Organization (O field) from certificate X.509 subject
ORG_NAME=$(security find-certificate -c "$SELECTED_CERT" -p | openssl x509 -noout -subject | sed 's/.*O = \([^,]*\).*/\1/')

if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}Error: Could not extract Team ID from certificate.${NC}"
    exit 1
fi

ORG_LOWER=$(echo "$ORG_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')
MAIN_BUNDLE_ID="com.${ORG_LOWER}.automute"
HELPER_BUNDLE_ID="com.${ORG_LOWER}.automute.helper"
GROUP_ID="group.com.${ORG_LOWER}.automute"

echo ""
echo "Team ID:      $TEAM_ID"
echo "Organization: $ORG_NAME"
echo "Main app:     $MAIN_BUNDLE_ID"
echo "Helper:       $HELPER_BUNDLE_ID"
echo "Group:        $GROUP_ID"

# Update project configuration
echo ""
echo "Updating project configuration..."

PBXPROJ="automute.xcodeproj/project.pbxproj"

# Replace DEVELOPMENT_TEAM (all occurrences)
sed -i '' "s/DEVELOPMENT_TEAM = [^;]*/DEVELOPMENT_TEAM = ${TEAM_ID}/g" "$PBXPROJ"

# Replace main app PRODUCT_BUNDLE_IDENTIFIER (lines without helper/Helper in value)
sed -i '' '/[Hh]elper/!s|PRODUCT_BUNDLE_IDENTIFIER = "[^"]*"|PRODUCT_BUNDLE_IDENTIFIER = "'"${MAIN_BUNDLE_ID}"'"|' "$PBXPROJ"
sed -i '' '/[Hh]elper/!s|PRODUCT_BUNDLE_IDENTIFIER = [^";][^;]*;|PRODUCT_BUNDLE_IDENTIFIER = '"${MAIN_BUNDLE_ID}"';|' "$PBXPROJ"

# Replace helper PRODUCT_BUNDLE_IDENTIFIER (lines with helper/Helper in value)
sed -i '' '/[Hh]elper/s|PRODUCT_BUNDLE_IDENTIFIER = "[^"]*"|PRODUCT_BUNDLE_IDENTIFIER = "'"${HELPER_BUNDLE_ID}"'"|' "$PBXPROJ"
sed -i '' '/[Hh]elper/s|PRODUCT_BUNDLE_IDENTIFIER = [^";][^;]*;|PRODUCT_BUNDLE_IDENTIFIER = "'"${HELPER_BUNDLE_ID}"'";|' "$PBXPROJ"

# Replace constants in MJConstants.h
sed -i '' 's|MJ_HELPER_BUNDLE_ID = @"[^"]*"|MJ_HELPER_BUNDLE_ID = @"'"${HELPER_BUNDLE_ID}"'"|' common/MJConstants.h
sed -i '' 's|MJ_SHARED_GROUP_ID = @"[^"]*"|MJ_SHARED_GROUP_ID = @"'"${GROUP_ID}"'"|' common/MJConstants.h

# Replace application-groups in entitlements files
sed -i '' 's|<string>group\.[^<]*</string>|<string>'"${GROUP_ID}"'</string>|' automute/automute.entitlements
sed -i '' 's|<string>group\.[^<]*</string>|<string>'"${GROUP_ID}"'</string>|' "AutoMute Helper/AutoMute_Helper.entitlements"

echo -e "${GREEN}Configuration updated.${NC}"

# Run pod install
echo ""
echo "Running pod install..."
pod install
if [ $? -ne 0 ]; then
    echo -e "${RED}pod install failed!${NC}"
    exit 1
fi

# Build Release
echo ""
echo "Building Release configuration..."
xcodebuild -workspace automute.xcworkspace -scheme AutoMute -configuration Release -derivedDataPath build CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build
if [ $? -ne 0 ]; then
    echo ""
    echo -e "${YELLOW}Automatic signing failed. Retrying with ad-hoc signing...${NC}"
    echo -e "${YELLOW}Note: Some features (e.g., launch at login) may not work without proper signing.${NC}"
    rm -rf build
    xcodebuild -workspace automute.xcworkspace -scheme AutoMute -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" build
    if [ $? -ne 0 ]; then
        echo -e "${RED}Build failed!${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Build succeeded!${NC}"

# Ask to copy to /Applications
APP_PATH="build/Build/Products/Release/AutoMute.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    read -p "Copy AutoMute.app to /Applications? (y/N) " COPY_CONFIRM
    if [[ "$COPY_CONFIRM" =~ ^[Yy]$ ]]; then
        cp -R "$APP_PATH" /Applications/
        echo -e "${GREEN}Copied to /Applications/AutoMute.app${NC}"
    fi
else
    echo -e "${RED}Warning: Build output not found at ${APP_PATH}${NC}"
fi

echo ""
echo "Done!"
