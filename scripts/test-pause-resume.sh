#!/bin/bash
# Test script for Phase 2 network optimization (pause/resume/idle)
#
# Tests:
# 1. Tab switching: inactive tab pauses, active tab resumes
# 2. App background: all sessions pause
# 3. App foreground: only active session resumes
# 4. Idle detection: verify idle notification after 2s of inactivity
#
# Usage:
#   ./scripts/test-pause-resume.sh <connection_name>
#
# Prerequisites:
#   - rtach deployed with pause/resume/idle support
#   - Connection profile saved in app

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUNDLE_ID="com.octerm.clauntty"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Connection name (required argument)
CONNECTION_NAME="${1:-}"
if [ -z "$CONNECTION_NAME" ]; then
    echo -e "${RED}Usage: $0 <connection_name>${NC}"
    echo "Example: $0 devbox"
    exit 1
fi

LOG_FILE="/tmp/clauntty_pause_test.log"
RESULTS_FILE="/tmp/clauntty_pause_results.txt"

# Clear previous results
> "$RESULTS_FILE"

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    echo "PASS: $1" >> "$RESULTS_FILE"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    echo "FAIL: $1" >> "$RESULTS_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Start log streaming in background
start_log_stream() {
    log "Starting log stream..."
    xcrun simctl spawn booted log stream --level debug \
        --predicate 'subsystem == "com.clauntty" AND (message CONTAINS "pause" OR message CONTAINS "resume" OR message CONTAINS "idle" OR message CONTAINS "backgrounded" OR message CONTAINS "activated")' \
        > "$LOG_FILE" 2>&1 &
    LOG_PID=$!
    sleep 1
}

stop_log_stream() {
    if [ -n "$LOG_PID" ]; then
        kill $LOG_PID 2>/dev/null || true
        wait $LOG_PID 2>/dev/null || true
    fi
}

# Check logs for pattern
check_logs_for() {
    local pattern="$1"
    local description="$2"
    local timeout="${3:-5}"

    local start=$(date +%s)
    while true; do
        if grep -q "$pattern" "$LOG_FILE" 2>/dev/null; then
            pass "$description"
            return 0
        fi

        local now=$(date +%s)
        if [ $((now - start)) -ge $timeout ]; then
            fail "$description (pattern not found: $pattern)"
            return 1
        fi
        sleep 0.5
    done
}

# Count occurrences in logs
count_in_logs() {
    local pattern="$1"
    grep -c "$pattern" "$LOG_FILE" 2>/dev/null || echo 0
}

# Clear log file (for fresh test)
clear_logs() {
    > "$LOG_FILE"
}

cleanup() {
    log "Cleaning up..."
    stop_log_stream
    # Kill app if running
    xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================
# MAIN TEST SEQUENCE
# ============================================

echo ""
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  Pause/Resume/Idle Test Suite${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# Build and launch with 2 tabs
log "Building and launching app with 2 tabs..."
"$SCRIPT_DIR/sim.sh" debug "$CONNECTION_NAME" --tabs "0,new" --wait 10 --no-logs

# Start log streaming
start_log_stream
sleep 2

# ============================================
# TEST 1: Tab Switching
# ============================================
echo ""
echo -e "${CYAN}--- Test 1: Tab Switching ---${NC}"
clear_logs

log "Switching to tab 2..."
"$SCRIPT_DIR/sim.sh" tap-tab 2 2
sleep 2

# Check that session paused (tab 1 became inactive)
check_logs_for "paused output streaming" "Tab 1 paused when becoming inactive" 5

# Check that session resumed (tab 2 became active)
check_logs_for "resumed output streaming" "Tab 2 resumed when becoming active" 5

# ============================================
# TEST 2: Switch Back
# ============================================
echo ""
echo -e "${CYAN}--- Test 2: Switch Back ---${NC}"
clear_logs

log "Switching back to tab 1..."
"$SCRIPT_DIR/sim.sh" tap-tab 1 2
sleep 2

# Should see pause/resume again
check_logs_for "paused output streaming" "Tab 2 paused when becoming inactive" 5
check_logs_for "resumed output streaming" "Tab 1 resumed when becoming active" 5

# ============================================
# TEST 3: App Background
# ============================================
echo ""
echo -e "${CYAN}--- Test 3: App Background ---${NC}"
clear_logs

log "Pressing home button to background app..."
"$SCRIPT_DIR/sim.sh" button home
sleep 2

# Check that all sessions paused
check_logs_for "backgrounded: paused all" "All sessions paused on background" 5

# ============================================
# TEST 4: App Foreground
# ============================================
echo ""
echo -e "${CYAN}--- Test 4: App Foreground ---${NC}"
clear_logs

log "Reopening app..."
xcrun simctl launch booted "$BUNDLE_ID"
sleep 3

# Check that only active session resumed
check_logs_for "activated: resumed active session" "Only active session resumed on foreground" 5

# ============================================
# TEST 5: Idle Detection (if connected to rtach)
# ============================================
echo ""
echo -e "${CYAN}--- Test 5: Idle Detection ---${NC}"
clear_logs

log "Waiting for idle detection (3s of inactivity)..."
sleep 4

# Check for idle notification
if check_logs_for "idle notification" "Received idle notification from rtach" 5; then
    pass "Idle detection working"
else
    warn "Idle notification not detected (may need active rtach connection)"
fi

# ============================================
# RESULTS
# ============================================
echo ""
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  Test Results${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

PASS_COUNT=$(grep -c "^PASS:" "$RESULTS_FILE" 2>/dev/null || echo 0)
FAIL_COUNT=$(grep -c "^FAIL:" "$RESULTS_FILE" 2>/dev/null || echo 0)
TOTAL=$((PASS_COUNT + FAIL_COUNT))

echo -e "Passed: ${GREEN}$PASS_COUNT${NC} / $TOTAL"
echo -e "Failed: ${RED}$FAIL_COUNT${NC} / $TOTAL"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}Some tests failed. Check logs at: $LOG_FILE${NC}"
    echo ""
    echo "Failed tests:"
    grep "^FAIL:" "$RESULTS_FILE" | sed 's/^FAIL: /  - /'
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
