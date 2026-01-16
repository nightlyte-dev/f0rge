# f0rge Testing Workflow with btrfs Snapshots

This directory contains tools for efficiently testing f0rge.sh using btrfs snapshots.

## Quick Start

```bash
# Make scripts executable
chmod +x test-f0rge.sh snapshot-manager.sh

# Run a test (creates snapshot, runs f0rge, asks about rollback)
sudo ./test-f0rge.sh

# List all test snapshots
sudo ./snapshot-manager.sh list

# Clean up old snapshots
sudo ./snapshot-manager.sh clean
```

## Scripts Overview

### `test-f0rge.sh` - Main Testing Wrapper

Automates the test cycle: snapshot → run f0rge → rollback decision

**Usage:**
```bash
# Interactive mode (default)
sudo ./test-f0rge.sh

# Auto-rollback after test
sudo ./test-f0rge.sh --auto-rollback

# Keep changes (no rollback prompt)
sudo ./test-f0rge.sh --keep
```

**What it does:**
1. Creates a timestamped btrfs snapshot
2. Runs f0rge.sh as your user
3. Asks if you want to rollback or keep changes
4. Preserves snapshot for later use

### `snapshot-manager.sh` - Snapshot Management

Manage your test snapshots easily.

**Commands:**
```bash
# List all f0rge test snapshots
sudo ./snapshot-manager.sh list

# Delete all test snapshots (with confirmation)
sudo ./snapshot-manager.sh clean

# Delete a specific snapshot
sudo ./snapshot-manager.sh delete

# Show rollback instructions
sudo ./snapshot-manager.sh rollback
```

## Typical Testing Workflow

### 1. Initial Test Run
```bash
# First test - see what happens
sudo ./test-f0rge.sh
```

- Script creates snapshot
- Runs f0rge.sh
- You review the results
- Decide: rollback or keep

### 2. Iterative Testing
```bash
# Make changes to f0rge.sh
vim f0rge.sh

# Test again with auto-rollback (fastest iteration)
sudo ./test-f0rge.sh --auto-rollback

# Make more changes
vim f0rge.sh

# Test again
sudo ./test-f0rge.sh --auto-rollback
```

### 3. Cleanup
```bash
# List accumulated snapshots
sudo ./snapshot-manager.sh list

# Clean up old test snapshots
sudo ./snapshot-manager.sh clean
```

## Important Notes

### About Rollbacks

The test script **preserves snapshots** but doesn't perform automatic rollback because:
- btrfs subvolume rollback requires unmounting the root filesystem
- Safe rollback requires booting from live media or using boot-time tools

For **quick testing**, you can:
1. Keep the VM in a "clean" snapshot state
2. Use `test-f0rge.sh --auto-rollback` repeatedly
3. Manually revert VM to clean state when needed

### Manual Rollback (if needed)

If you need to manually rollback to a snapshot:

```bash
# Boot from Arch ISO/live USB
mount /dev/sdXY /mnt  # Your root partition

# Backup current root
mv /mnt/@ /mnt/@-broken

# Restore from snapshot
btrfs subvolume snapshot /.snapshots/f0rge-test-YYYYMMDD-HHMMSS /mnt/@

# Reboot
reboot
```

## Tips for Efficient Testing

1. **Use auto-rollback for quick iterations:**
   ```bash
   sudo ./test-f0rge.sh --auto-rollback
   ```

2. **Keep snapshots of successful runs:**
   ```bash
   sudo ./test-f0rge.sh --keep
   # Then manually rename the snapshot for reference
   ```

3. **Test specific sections:**
   Edit f0rge.sh to comment out sections you're not testing

4. **Check snapshot disk usage:**
   ```bash
   sudo ./snapshot-manager.sh list
   ```

5. **VM strategy:**
   - Keep a "clean Arch" VM snapshot in Proxmox
   - Use btrfs snapshots for rapid f0rge testing
   - Restore Proxmox snapshot when you need a fresh start

## Disk Space

Btrfs snapshots are copy-on-write, so they only consume space for changed data:
- First snapshot: ~0-100MB (metadata only)
- After f0rge run: depends on packages installed
- Old snapshots: Clean regularly to free space

## Troubleshooting

### "Not a btrfs subvolume"
Make sure your root filesystem is btrfs:
```bash
df -T /
```

### Permission denied
Scripts need root privileges for btrfs operations:
```bash
sudo ./test-f0rge.sh
```

### Snapshot directory doesn't exist
Will be created automatically at `/.snapshots`

## Integration with Your Current Setup

Since you have a Proxmox VM with btrfs:
1. Take a Proxmox snapshot of the "clean Arch" state (as backup)
2. Use these scripts for day-to-day f0rge testing
3. Restore Proxmox snapshot only when you need a completely fresh start

This gives you the best of both worlds:
- **Fast**: btrfs snapshots for quick iteration (seconds)
- **Safe**: Proxmox backup for complete system restoration
