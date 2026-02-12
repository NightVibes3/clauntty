#!/bin/bash
# Install Facebook IDB for simulator automation
# IDB runs inside the simulator - won't take over your screen

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Installing Facebook IDB...${NC}"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found. Please install it first: https://brew.sh${NC}"
    exit 1
fi

# Check for uv
if ! command -v uv &> /dev/null; then
    echo -e "${RED}uv not found. Please install it first: https://docs.astral.sh/uv/${NC}"
    exit 1
fi

# Install idb_companion via Homebrew (from Facebook tap)
echo -e "${BLUE}Installing idb_companion...${NC}"
brew tap facebook/fb 2>/dev/null || true
brew install idb-companion 2>/dev/null || brew upgrade idb-companion 2>/dev/null || true

# Install fb-idb Python client via uv
echo -e "${BLUE}Installing fb-idb Python client...${NC}"
uv tool install fb-idb 2>/dev/null || uv tool upgrade fb-idb 2>/dev/null || true

# Verify installation
echo ""
echo -e "${BLUE}Verifying installation...${NC}"

if command -v idb_companion &> /dev/null; then
    echo -e "${GREEN}✓ idb_companion installed${NC}"
else
    echo -e "${RED}✗ idb_companion not found${NC}"
    exit 1
fi

if command -v idb &> /dev/null; then
    echo -e "${GREEN}✓ idb client installed${NC}"
else
    echo -e "${RED}✗ idb client not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}IDB installation complete!${NC}"
echo ""
echo "Usage:"
echo "  ./scripts/sim.sh boot              # Boot simulator and connect IDB"
echo "  ./scripts/sim.sh tap 196 400       # Tap at coordinates"
echo "  ./scripts/sim.sh test-keyboard     # Test keyboard accessory bar"
echo "  ./scripts/sim.sh help              # See all commands"
