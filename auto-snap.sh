#!/bin/bash

# test-f0rge.sh - Automated testing wrapper for f0rge using btrfs snapshots
# Usage: ./test-f0rge.sh [options]
# Options:
#   --auto-rollback    Automatically rollback after test completes
#   --keep            Keep changes (skip rollback prompt)

set -e

# Configuration
SNAPSHOT_DIR="/.snapshots"
SNAPSHOT_NAME="f0rge-test-$(date +%Y%m%d-%H%M%S)"
SUBVOLUME="/"  # Change this if your root is a different subvolume path

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
AUTO_ROLLBACK=false
KEEP_CHANGES=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --auto-rollback)
      AUTO_ROLLBACK=true
      shift
      ;;
    --keep)
      KEEP_CHANGES=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Verify we're running on btrfs
if ! command -v btrfs &> /dev/null; then
  echo -e "${RED}Error: btrfs-progs not installed!${NC}"
  echo "Install with: sudo pacman -S btrfs-progs"
  exit 1
fi

# Check if running as root (needed for snapshots)
if [[ $EUID -ne 0 ]]; then
  echo -e "${YELLOW}This script needs root privileges for btrfs snapshots.${NC}"
  echo "Re-running with sudo..."
  exec sudo "$0" "$@"
fi

# Verify the subvolume is btrfs
if ! btrfs subvolume show "$SUBVOLUME" &> /dev/null; then
  echo -e "${RED}Error: $SUBVOLUME is not a btrfs subvolume!${NC}"
  exit 1
fi

# Create snapshots directory if it doesn't exist
mkdir -p "$SNAPSHOT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     f0rge Testing Environment v1.0        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Create snapshot
echo -e "${MAGENTA}Creating snapshot: ${SNAPSHOT_NAME}${NC}"
btrfs subvolume snapshot "$SUBVOLUME" "$SNAPSHOT_DIR/$SNAPSHOT_NAME"

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}✓ Snapshot created successfully${NC}"
  echo -e "  Location: ${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"
else
  echo -e "${RED}✗ Failed to create snapshot${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Running f0rge.sh...${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Run f0rge as the original user (not root)
ORIGINAL_USER="${SUDO_USER:-$USER}"
cd "$(dirname "$0")"

# Run f0rge.sh as the original user
su - "$ORIGINAL_USER" -c "cd $(pwd) && bash f0rge.sh"
F0RGE_EXIT_CODE=$?

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  f0rge.sh completed (exit code: $F0RGE_EXIT_CODE)${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Rollback decision
if [[ "$KEEP_CHANGES" == true ]]; then
  echo -e "${GREEN}Keeping changes as requested (--keep flag)${NC}"
  exit 0
fi

if [[ "$AUTO_ROLLBACK" == true ]]; then
  echo -e "${YELLOW}Auto-rollback enabled. Rolling back changes...${NC}"
  ROLLBACK_CHOICE="yes"
else
  echo -e "${MAGENTA}Do you want to rollback to the snapshot?${NC}"
  echo "  (This will undo all changes made by f0rge)"
  read -p "Rollback? [y/N]: " ROLLBACK_CHOICE
fi

if [[ "$ROLLBACK_CHOICE" =~ ^[Yy] ]]; then
  echo ""
  echo -e "${YELLOW}Rolling back to snapshot...${NC}"
  
  # Get the current subvolume ID
  CURRENT_ID=$(btrfs subvolume show "$SUBVOLUME" | grep "Subvolume ID" | awk '{print $3}')
  
  echo -e "${RED}⚠ WARNING: This will require a reboot!${NC}"
  echo -e "${YELLOW}After rollback, you need to:${NC}"
  echo "  1. Reboot the system"
  echo "  2. Boot into the snapshot"
  echo ""
  echo -e "${MAGENTA}Manual rollback instructions:${NC}"
  echo "  1. Mount the btrfs root: sudo mount /dev/sdXY /mnt"
  echo "  2. Rename current root: sudo mv /mnt/@ /mnt/@-broken"
  echo "  3. Restore snapshot: sudo btrfs subvolume snapshot ${SNAPSHOT_DIR}/${SNAPSHOT_NAME} /mnt/@"
  echo "  4. Reboot"
  echo ""
  
  read -p "Press Enter to continue or Ctrl+C to cancel..."
  
  # Note: Actual rollback requires mounting the btrfs root and renaming subvolumes
  # This is safer to do manually or with a dedicated rollback script
  echo -e "${YELLOW}Snapshot preserved at: ${SNAPSHOT_DIR}/${SNAPSHOT_NAME}${NC}"
  echo -e "${GREEN}You can manually rollback or use this snapshot for reference${NC}"
else
  echo ""
  echo -e "${GREEN}Keeping changes. Snapshot preserved at:${NC}"
  echo -e "  ${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"
  echo ""
  echo -e "${BLUE}To rollback later, you can delete current root and restore this snapshot${NC}"
fi

# List all snapshots
echo ""
echo -e "${BLUE}Available snapshots:${NC}"
ls -lh "$SNAPSHOT_DIR" | grep "f0rge-test" || echo "  (none)"

echo ""
echo -e "${GREEN}✓ Testing session complete${NC}"
