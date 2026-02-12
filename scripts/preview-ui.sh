#!/bin/bash
# Preview UI script - builds app, launches in specific mode, and captures screenshot
#
# Usage:
#   ./scripts/preview-ui.sh terminal     # Preview terminal view
#   ./scripts/preview-ui.sh keyboard     # Preview terminal with keyboard
#   ./scripts/preview-ui.sh connections  # Preview connection list
#   ./scripts/preview-ui.sh new          # Preview new connection form
#   ./scripts/preview-ui.sh all          # Screenshot all modes

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUNDLE_ID="com.octerm.clauntty"
SIMULATOR="iPhone 17"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$PROJECT_DIR"

# Ensure screenshots directory exists
mkdir -p "$SCREENSHOTS_DIR"

build_app() {
    echo -e "${BLUE}Building app...${NC}"
    xcodebuild -project Clauntty.xcodeproj -scheme Clauntty \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -quiet build
    echo -e "${GREEN}Build complete${NC}"
}

boot_simulator() {
    echo -e "${BLUE}Booting simulator...${NC}"
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    # Wait for boot
    sleep 2
}

install_app() {
    echo -e "${BLUE}Installing app...${NC}"
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Clauntty-*/Build/Products/Debug-iphonesimulator -name "Clauntty.app" -type d | head -1)
    if [ -z "$APP_PATH" ]; then
        echo "Error: Could not find built app"
        exit 1
    fi
    xcrun simctl install booted "$APP_PATH"
}

launch_and_screenshot() {
    local mode=$1
    local name=$2
    local wait_time=${3:-3}

    echo -e "${BLUE}Launching in $name mode...${NC}"

    # Terminate any existing instance
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
    sleep 1

    # Launch with preview argument
    if [ "$mode" = "none" ]; then
        xcrun simctl launch booted "$BUNDLE_ID"
    else
        xcrun simctl launch booted "$BUNDLE_ID" "$mode"
    fi

    # Wait for app to load
    sleep "$wait_time"

    # Capture screenshot
    local screenshot_path="$SCREENSHOTS_DIR/$name.png"
    xcrun simctl io booted screenshot "$screenshot_path"
    echo -e "${GREEN}Screenshot saved: $screenshot_path${NC}"
}

show_screenshot() {
    local path=$1
    if [ -f "$path" ]; then
        # Open in Preview (macOS)
        open "$path"
    fi
}

case "${1:-help}" in
    terminal)
        build_app
        boot_simulator
        install_app
        launch_and_screenshot "--preview-terminal" "terminal" 4
        show_screenshot "$SCREENSHOTS_DIR/terminal.png"
        ;;

    keyboard)
        build_app
        boot_simulator
        install_app
        launch_and_screenshot "--preview-keyboard" "keyboard" 4
        # TODO: Simulate tap to show keyboard
        echo -e "${YELLOW}Note: Tap terminal in simulator to show keyboard${NC}"
        show_screenshot "$SCREENSHOTS_DIR/keyboard.png"
        ;;

    connections)
        build_app
        boot_simulator
        install_app
        launch_and_screenshot "--preview-connections" "connections" 3
        show_screenshot "$SCREENSHOTS_DIR/connections.png"
        ;;

    new)
        build_app
        boot_simulator
        install_app
        launch_and_screenshot "--preview-new-connection" "new_connection" 3
        show_screenshot "$SCREENSHOTS_DIR/new_connection.png"
        ;;

    all)
        build_app
        boot_simulator
        install_app

        echo -e "${BLUE}Capturing all screenshots...${NC}"
        launch_and_screenshot "" "connections" 3
        launch_and_screenshot "--preview-terminal" "terminal" 4

        echo -e "${GREEN}All screenshots saved to: $SCREENSHOTS_DIR${NC}"
        open "$SCREENSHOTS_DIR"
        ;;

    quick)
        # Quick mode - skip build, just launch and screenshot
        boot_simulator
        launch_and_screenshot "${2:---preview-terminal}" "${3:-quick}" 3
        show_screenshot "$SCREENSHOTS_DIR/${3:-quick}.png"
        ;;

    *)
        echo "Usage: $0 {terminal|keyboard|connections|new|all|quick}"
        echo ""
        echo "Commands:"
        echo "  terminal    - Build and preview terminal view"
        echo "  keyboard    - Build and preview terminal with keyboard hint"
        echo "  connections - Build and preview connection list"
        echo "  new         - Build and preview new connection form"
        echo "  all         - Build and capture all screenshots"
        echo "  quick [mode] [name] - Skip build, just launch and screenshot"
        echo ""
        echo "Screenshots saved to: $SCREENSHOTS_DIR"
        exit 1
        ;;
esac

echo -e "${GREEN}Done!${NC}"
