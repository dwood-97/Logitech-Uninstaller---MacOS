# Logitech G HUB Deep Uninstall Script (macOS)

This repository provides a **safe, defensive, and portable uninstall script** for **Logitech G HUB on macOS**.

If you're here, you've probably run into one or more of the following:

- G HUB refuses to quit ("App is open" but nothing appears in Force Quit)
- Screen goes black or UI freezes after killing Logitech processes
- G HUB updater/helper keeps relaunching itself
- Reinstalling G HUB hangs or fails
- Existing uninstall scripts do **not** work on your system

This script exists because **Logitech G HUB installs deep system-level services**, and force-killing them (`pkill -f`) can destabilize macOS (HID, input, WindowServer).

---

## Who This Is For

This script is intended for users who:

- Cannot uninstall Logitech G HUB normally
- Experience black screens or UI freezes when stopping G HUB
- Have partially deleted or corrupted G HUB installs
- Tried other uninstall scripts without success

---

## What This Script Does

- Uses **Logitech's own `lghub_updater --uninstall`** when available
- Safely unloads `launchd` agents and daemons (no screen blanking)
- Works across **multiple install paths**, including:
  - `/Applications`
  - `/System/Volumes/Data/Applications`
- Cleans up:
  - User-level leftovers
  - Shared folders
  - LaunchAgents / LaunchDaemons
  - Caches, logs, and preferences
- Includes **guardrails** to prevent deleting dangerous paths
- Supports:
  - `--dry-run`
  - Optional backups
  - Detailed logging for troubleshooting

---

## Requirements

- macOS (tested on Ventura / Sonoma)
- `bash`
- Terminal access
- Administrator privileges (`sudo`)

---

## Quick Start

```bash
git clone https://github.com/dwood-97/Logitech-Uninstaller---MacOS
cd ghub-uninstall
chmod +x uninstaller.sh
./uninstaller.sh --dry-run
```

Review the output carefully before proceeding.

---

## Installation

### Clone the repository

```bash
git clone https://github.com/dwood-97/Logitech-Uninstaller---MacOS
cd ghub-uninstall
chmod +x uninstaller.sh
```

---

## Usage

### Dry Run (Highly Recommended)

Prints all actions **without deleting anything**.

```bash
./uninstaller.sh --dry-run
```

Review the output carefully before proceeding.

### Full Uninstall (With Backup)

```bash
./uninstaller.sh
```

- Prompts for `sudo` once
- Creates a backup of user config files on your Desktop
- Writes a timestamped log file (path printed in output)

### Skip Backup (Advanced)

```bash
./uninstaller.sh --no-backup
```

---

## After Running

### Reboot Recommended

Even if everything looks fine, **reboot your Mac** to fully clear HID and input hooks.

### Verify Removal (Optional)

```bash
ps aux | grep -Ei 'lghub|ghub|logitech' | grep -v grep
```

If nothing prints, G HUB is fully removed.

---

## Log Files

Each run generates a log file similar to:

```
/tmp/ghub_uninstall_YYYYMMDD_HHMMSS.log
```

Attach this log when asking for help or opening issues.

---

## Why Not `pkill -f logi`?

Force-killing Logitech processes can:

- Kill active HID/input helpers
- Blank all displays
- Crash WindowServer
- Force a hard reboot

This script uses **`launchctl bootout`** and Logitech's own uninstaller instead — the safe and controlled approach.

---

## What This Script Does NOT Do

- Does **not** remove Logi Options+ unless GHUB-specific paths match
- Does **not** remove kernel extensions
- Does **not** disable SIP

A future flag may add a full Logitech purge, but that is intentionally **not the default**.

---

## Known Variations This Handles

- Different app bundle names (`lghub.app` vs `Logitech G HUB.app`)
- Framework vs `MacOS` updater layouts
- APFS synthetic `/Applications` paths
- Partially deleted or broken installs

---

## Disclaimer

This script deletes files and unloads system services.

- Read the script before running
- Use `--dry-run` first
- You run this at your own risk

That said, it is explicitly designed to **avoid the black-screen and instability issues** caused by other uninstall methods.

---

## Contributions

PRs welcome for:

- New macOS versions
- Additional leftover paths
- Edge cases from different Logitech installs

---

## TL;DR

If Logitech G HUB won't uninstall and other scripts failed — **this one is defensive, portable, logged, and safe**.

Enjoy your Logitech-free system! 🤘

## License

MIT License
