#!/bin/bash
# Visual testing script for Clauntty
# Captures screenshots and compares against golden images

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GOLDEN_DIR="$PROJECT_DIR/Tests/Golden"
ACTUAL_DIR="/tmp/clauntty_visual"
SIMULATOR="iPhone 17"
BUNDLE_ID="com.octerm.clauntty"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

mkdir -p "$ACTUAL_DIR"

usage() {
    echo "Usage: $0 [capture|compare|update] [test_name]"
    echo ""
    echo "Commands:"
    echo "  capture <name>  - Capture screenshot as <name>.png"
    echo "  compare <name>  - Compare current screenshot against golden <name>.png"
    echo "  update <name>   - Update golden screenshot <name>.png with current"
    echo "  list            - List available golden screenshots"
    echo ""
    echo "Examples:"
    echo "  $0 capture terminal_empty    # Capture current state"
    echo "  $0 compare terminal_empty    # Compare against golden"
    echo "  $0 update terminal_empty     # Update golden with current"
}

ensure_simulator() {
    echo "Ensuring simulator is booted..."
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
}

capture() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Please provide a screenshot name${NC}"
        exit 1
    fi

    ensure_simulator

    echo "Capturing screenshot: $name.png"
    xcrun simctl io booted screenshot "$ACTUAL_DIR/$name.png"
    echo -e "${GREEN}Saved to: $ACTUAL_DIR/$name.png${NC}"
}

compare() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Please provide a screenshot name${NC}"
        exit 1
    fi

    local golden="$GOLDEN_DIR/$name.png"
    local actual="$ACTUAL_DIR/$name.png"

    if [ ! -f "$golden" ]; then
        echo -e "${YELLOW}Golden screenshot not found: $golden${NC}"
        echo "Run '$0 update $name' to create it"
        exit 1
    fi

    # Capture current state
    ensure_simulator
    xcrun simctl io booted screenshot "$actual"

    # Compare using ImageMagick
    if ! command -v compare &> /dev/null; then
        echo -e "${YELLOW}ImageMagick not installed. Install with: brew install imagemagick${NC}"
        echo "Skipping pixel comparison, showing files:"
        echo "  Golden: $golden"
        echo "  Actual: $actual"
        exit 0
    fi

    DIFF=$(compare -metric AE "$actual" "$golden" null: 2>&1 || true)

    if [ "$DIFF" = "0" ]; then
        echo -e "${GREEN}Visual test PASSED (0 pixel diff)${NC}"
    else
        echo -e "${RED}Visual test FAILED ($DIFF pixels differ)${NC}"
        compare "$actual" "$golden" "$ACTUAL_DIR/${name}_diff.png" 2>/dev/null || true
        echo "  Diff saved to: $ACTUAL_DIR/${name}_diff.png"
        exit 1
    fi
}

update() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Please provide a screenshot name${NC}"
        exit 1
    fi

    ensure_simulator

    echo "Updating golden screenshot: $name.png"
    xcrun simctl io booted screenshot "$GOLDEN_DIR/$name.png"
    echo -e "${GREEN}Updated: $GOLDEN_DIR/$name.png${NC}"
}

list_golden() {
    echo "Golden screenshots in $GOLDEN_DIR:"
    if [ -d "$GOLDEN_DIR" ] && [ "$(ls -A "$GOLDEN_DIR" 2>/dev/null)" ]; then
        ls -la "$GOLDEN_DIR"/*.png 2>/dev/null || echo "  (no .png files)"
    else
        echo "  (empty)"
    fi
}

case "$1" in
    capture)
        capture "$2"
        ;;
    compare)
        compare "$2"
        ;;
    update)
        update "$2"
        ;;
    list)
        list_golden
        ;;
    *)
        usage
        exit 1
        ;;
esac
