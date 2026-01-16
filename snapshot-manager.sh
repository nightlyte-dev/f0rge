#!/bin/bash

# snapshot-manager.sh - Manage btrfs snapshots for f0rge testing
# Usage: ./snapshot-manager.sh [command]
# Commands:
#   list       - List all f0rge test snapshots
#   clean      - Remove all f0rge test snapshots
#   rollback   - Interactive rollback to a snapshot
#   delete     - Delete a specific snapshot

SNAPSHOT_DIR="/.snapshots"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${YELLOW}This script needs root privileges.${NC}"
  exec sudo "$0" "$@"
fi

# Verify btrfs is available
if ! command -v btrfs &> /dev/null; then
  echo -e "${RED}Error: btrfs-progs not installed!${NC}"
  exit 1
fi

# List snapshots
list_snapshots() {
  echo -e "${BLUE}f0rge Test Snapshots:${NC}"
  echo ""
  
  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    echo -e "${YELLOW}No snapshot directory found${NC}"
    return
  fi
  
  SNAPSHOTS=$(ls -1 "$SNAPSHOT_DIR" 2>/dev/null | grep "f0rge-test" || true)
  
  if [[ -z "$SNAPSHOTS" ]]; then
    echo -e "${YELLOW}No f0rge snapshots found${NC}"
    return
  fi
  
  echo -e "${GREEN}Name${NC}                          ${GREEN}Date${NC}          ${GREEN}Size${NC}"
  echo "────────────────────────────────────────────────────────────"
  
  while IFS= read -r snapshot; do
    if [[ -n "$snapshot" ]]; then
      SIZE=$(du -sh "$SNAPSHOT_DIR/$snapshot" 2>/dev/null | cut -f1)
      DATE=$(echo "$snapshot" | sed 's/f0rge-test-//' | sed 's/\([0-9]\{8\}\)-\([0-9]\{6\}\)/\1 \2/')
      printf "%-30s %-14s %s\n" "$snapshot" "$DATE" "$SIZE"
    fi
  done <<< "$SNAPSHOTS"
}

# Clean all snapshots
clean_snapshots() {
  echo -e "${YELLOW}Cleaning all f0rge test snapshots...${NC}"
  
  if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    echo -e "${YELLOW}No snapshot directory found${NC}"
    return
  fi
  
  SNAPSHOTS=$(ls -1 "$SNAPSHOT_DIR" 2>/dev/null | grep "f0rge-test" || true)
  
  if [[ -z "$SNAPSHOTS" ]]; then
    echo -e "${YELLOW}No f0rge snapshots to clean${NC}"
    return
  fi
  
  COUNT=$(echo "$SNAPSHOTS" | wc -l)
  echo -e "${RED}This will delete $COUNT snapshot(s)${NC}"
  read -p "Are you sure? [y/N]: " CONFIRM
  
  if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
    echo "Cancelled"
    return
  fi
  
  while IFS= read -r snapshot; do
    if [[ -n "$snapshot" ]]; then
      echo "Deleting: $snapshot"
      btrfs subvolume delete "$SNAPSHOT_DIR/$snapshot"
    fi
  done <<< "$SNAPSHOTS"
  
  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Delete specific snapshot
delete_snapshot() {
  list_snapshots
  echo ""
  read -p "Enter snapshot name to delete: " SNAPSHOT_NAME
  
  if [[ -z "$SNAPSHOT_NAME" ]]; then
    echo -e "${RED}No snapshot name provided${NC}"
    return
  fi
  
  if [[ ! -d "$SNAPSHOT_DIR/$SNAPSHOT_NAME" ]]; then
    echo -e "${RED}Snapshot not found: $SNAPSHOT_NAME${NC}"
    return
  fi
  
  read -p "Delete $SNAPSHOT_NAME? [y/N]: " CONFIRM
  
  if [[ "$CONFIRM" =~ ^[Yy] ]]; then
    btrfs subvolume delete "$SNAPSHOT_DIR/$SNAPSHOT_NAME"
    echo -e "${GREEN}✓ Snapshot deleted${NC}"
  else
    echo "Cancelled"
  fi
}

# Interactive rollback
rollback_snapshot() {
  list_snapshots
  echo ""
  echo -e "${MAGENTA}Select a snapshot to rollback to:${NC}"
  read -p "Enter snapshot name: " SNAPSHOT_NAME
  
  if [[ -z "$SNAPSHOT_NAME" ]]; then
    echo -e "${RED}No snapshot name provided${NC}"
    return
  fi
  
  if [[ ! -d "$SNAPSHOT_DIR/$SNAPSHOT_NAME" ]]; then
    echo -e "${RED}Snapshot not found: $SNAPSHOT_NAME${NC}"
    return
  fi
  
  echo ""
  echo -e "${RED}⚠ WARNING: Manual rollback required!${NC}"
  echo ""
  echo -e "${YELLOW}To rollback to this snapshot:${NC}"
  echo ""
  echo "1. Boot from live USB/ISO"
  echo "2. Mount your btrfs partition:"
  echo "   mount /dev/sdXY /mnt  # Replace sdXY with your partition"
  echo ""
  echo "3. Backup current root:"
  echo "   mv /mnt/@ /mnt/@-old-$(date +%Y%m%d)"
  echo ""
  echo "4. Restore snapshot:"
  echo "   btrfs subvolume snapshot $SNAPSHOT_DIR/$SNAPSHOT_NAME /mnt/@"
  echo ""
  echo "5. Reboot and remove old root:"
  echo "   sudo btrfs subvolume delete /@-old-$(date +%Y%m%d)"
  echo ""
  echo -e "${BLUE}Alternative (if using GRUB with btrfs):${NC}"
  echo "Some distros support booting directly into snapshots via GRUB"
  echo ""
}

# Show usage
show_usage() {
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  list       - List all f0rge test snapshots"
  echo "  clean      - Remove all f0rge test snapshots"
  echo "  rollback   - Show rollback instructions for a snapshot"
  echo "  delete     - Delete a specific snapshot"
  echo "  help       - Show this help message"
}

# Main script logic
case "${1:-list}" in
  list)
    list_snapshots
    ;;
  clean)
    clean_snapshots
    ;;
  rollback)
    rollback_snapshot
    ;;
  delete)
    delete_snapshot
    ;;
  help|--help|-h)
    show_usage
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    echo ""
    show_usage
    exit 1
    ;;
esac
