# System Cleanup & File Management Script

A comprehensive Bash script for automating common system maintenance tasks including cache cleanup, duplicate file detection, and bulk file renaming.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [What It Does](#what-it-does)
- [Safety Features](#safety-features)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Features

✨ **Three main functions:**

1. **System Cleanup** - Removes cache files and old logs to free up disk space
2. **Duplicate Finder** - Identifies duplicate files based on content (SHA256 hash)
3. **Bulk Renamer** - Standardizes filenames to lowercase with consistent formatting

🛡️ **Safety First:**
- Dry-run mode by default (preview changes before applying)
- Comprehensive error handling
- Automatic cleanup of temporary files
- Collision detection for rename operations
- Safe handling of filenames with special characters

## Requirements

- **OS**: Linux or macOS
- **Bash**: Version 4.0 or higher
- **Utilities**: 
  - `sha256sum` (or `shasum` on macOS)
  - `stat`
  - `find`
  - Standard GNU coreutils

**Check your Bash version:**
```bash
bash --version
```

## Installation

1. **Download the script:**
   ```bash
   curl -O https://raw.githubusercontent.com/rustybladez/clean-my-system/refs/heads/main/cleanup.sh
   # OR
   wget https://raw.githubusercontent.com/rustybladez/clean-my-system/refs/heads/main/cleanup.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x cleanup.sh
   ```

3. **Optional - Move to your PATH:**
   ```bash
   sudo mv cleanup.sh /usr/local/bin/cleanup
   ```

## Usage

### Basic Usage

**Dry-run mode (safe preview - recommended first time):**
```bash
./cleanup.sh
```

**Actually execute the operations:**
1. Edit the script and change `DRY_RUN=true` to `DRY_RUN=false`
2. Run the script:
   ```bash
   ./cleanup.sh
   ```

### Running with sudo (for system-wide cleanup)

```bash
sudo ./cleanup.sh
```

**Note:** Only run with sudo if you need to clean system logs. The script will skip system-wide operations if not running as root.

## Configuration

Edit these variables at the top of the script:

```bash
# Directory to search for duplicate files
DUPLICATE_DIR="${HOME}/Documents"

# Directory where bulk renaming will occur
TARGET_DIR="${HOME}"

# Delete log files older than this many days (requires root)
LOG_DAYS=7

# Preview mode - set to false to actually execute operations
DRY_RUN=true
```

### Recommended Configurations

**For conservative cleanup:**
```bash
TARGET_DIR="${HOME}/Downloads"
DUPLICATE_DIR="${HOME}/Downloads"
LOG_DAYS=30
DRY_RUN=true
```

**For aggressive cleanup:**
```bash
TARGET_DIR="${HOME}"
DUPLICATE_DIR="${HOME}"
LOG_DAYS=7
DRY_RUN=false  # Be careful!
```

## What It Does

### 1. System Cleanup (`clean_system`)

Removes temporary and cache files to free up disk space:

**User-level cleanup (no sudo required):**
- `~/.cache/*` - General application cache
- `~/.mozilla/firefox/*/cache2/*` - Firefox browser cache
- `~/.config/google-chrome/Default/Cache/*` - Chrome browser cache

**System-level cleanup (requires sudo):**
- `/var/log/*.log` - Log files older than `LOG_DAYS`

**What it DOESN'T touch:**
- `/tmp/*` - System temporary directory (too risky)
- Important configuration files
- User documents or data

### 2. Duplicate File Finder (`find_duplicates`)

Intelligently identifies duplicate files:

**How it works:**
1. Scans `DUPLICATE_DIR` for files larger than 1MB
2. Groups files by size
3. Calculates SHA256 hashes only for files with matching sizes (efficient!)
4. Reports groups of files with identical content

**Example output:**
```
[2024-02-13 10:30:15] == Finding duplicates in /home/user/Documents ==
a1b2c3d4... /home/user/Documents/photo1.jpg
a1b2c3d4... /home/user/Documents/backup/photo1.jpg
e5f6g7h8... /home/user/Documents/report.pdf
e5f6g7h8... /home/user/Documents/final_report.pdf
[2024-02-13 10:30:45] Total duplicate groups: 2
```

**Note:** The script only *identifies* duplicates - it doesn't delete them automatically. You must manually review and delete.

### 3. Bulk File Renamer (`bulk_rename`)

Standardizes filenames in `TARGET_DIR`:

**Transformations applied:**
- Converts to lowercase: `MyFile.txt` → `myfile.txt`
- Replaces spaces with hyphens: `my file.txt` → `my-file.txt`
- Removes special characters: `my#file!.txt` → `myfile.txt`
- Preserves: letters, numbers, dots, underscores, hyphens

**Examples:**
```
Before                          After
──────────────────────────────────────────────────
"My Vacation Photos 2024.jpg"   my-vacation-photos-2024.jpg
"Project_Final (v2).docx"       project_final-v2.docx
"Budget $$ 2024.xlsx"           budget-2024.xlsx
```

**Safety features:**
- Detects naming collisions
- Uses `-n` flag to never overwrite existing files
- Reports statistics on completion

## Safety Features

### 1. Dry-Run Mode

**Enabled by default** - shows what *would* happen without making changes:

```
[DRY] rm -rf /home/user/.cache/*
[DRY] mv "My File.txt" "my-file.txt"
```

### 2. Error Handling

- `set -euo pipefail` - Exits on any error
- Directory existence checks
- File accessibility validation

### 3. Temporary File Management

```bash
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
```

Automatically cleans up temp files even if the script crashes.

### 4. Special Character Handling

Uses null-delimited lists (`-print0` and `-d ''`) to safely handle:
- Filenames with spaces
- Filenames with newlines
- Filenames with special characters

### 5. Collision Prevention

Checks if target filename exists before renaming:
```
WARNING: Collision detected - myfile.txt already exists, skipping MyFile.txt
```

## Examples

### Example 1: Clean Downloads Folder

```bash
# Edit the script
TARGET_DIR="$HOME/Downloads"
DUPLICATE_DIR="$HOME/Downloads"
DRY_RUN=true

# Run in dry-run mode first
./cleanup.sh

# Review output, then disable dry-run
DRY_RUN=false
./cleanup.sh
```

### Example 2: Find Duplicate Photos

```bash
# Edit the script
DUPLICATE_DIR="$HOME/Pictures"
DRY_RUN=true

# Run only the duplicate finder
# Comment out the other functions in main()
```

### Example 3: Standardize Document Names

```bash
# Edit the script
TARGET_DIR="$HOME/Documents/Reports"
DRY_RUN=true

# Preview changes
./cleanup.sh

# Apply changes
DRY_RUN=false
./cleanup.sh
```

### Example 4: System-wide Cleanup (Advanced)

```bash
# Run with sudo for system logs
sudo DRY_RUN=false ./cleanup.sh
```

## Troubleshooting

### "Permission denied" errors

**Problem:** Script can't access certain directories

**Solution:** 
```bash
# Run with sudo (be careful!)
sudo ./cleanup.sh

# OR modify TARGET_DIR to directories you own
TARGET_DIR="$HOME/MyFolder"
```

### stat command fails

**Problem:** Different `stat` syntax on macOS vs Linux

**Solution:** The script auto-detects and uses the correct syntax. If it still fails:
```bash
# Install GNU coreutils on macOS
brew install coreutils
```

### No duplicates found but you know they exist

**Problem:** Files are smaller than 1MB

**Solution:** Edit the script and change the size filter:
```bash
# In find_duplicates function, change:
find "$DUPLICATE_DIR" -type f -size +1M
# To:
find "$DUPLICATE_DIR" -type f -size +100k  # 100KB minimum
```

### Renamed files have missing extensions

**Problem:** Extension was removed due to special characters

**Solution:** The script preserves dots (.) by default. If extensions are missing, check the original filename for special characters.

### Script runs but nothing happens

**Problem:** DRY_RUN is still enabled

**Solution:** 
```bash
# Check the DRY_RUN variable
grep "DRY_RUN=" cleanup.sh

# Change to:
DRY_RUN=false
```

## Best Practices

1. **Always run in dry-run mode first**
   ```bash
   DRY_RUN=true
   ```

2. **Start with a small test directory**
   ```bash
   TARGET_DIR="$HOME/test_folder"
   ```

3. **Backup important data before bulk operations**
   ```bash
   cp -r ~/Documents ~/Documents.backup
   ```

4. **Review duplicate file lists carefully**
   - Open the files to verify they're actually duplicates
   - Keep the newest or highest quality version

5. **Check disk space before cleanup**
   ```bash
   df -h ~
   ```

6. **Schedule regular cleanups** (optional)
   ```bash
   # Add to crontab (weekly cleanup)
   0 2 * * 0 /path/to/cleanup.sh
   ```

## Output Interpretation

### Successful Run
```
[2024-02-13 10:00:00] Starting cleanup script (DRY_RUN=false)
[2024-02-13 10:00:01] == System cleanup ==
[2024-02-13 10:00:05] == Finding duplicates in /home/user/Documents ==
[2024-02-13 10:00:45] Total duplicate groups: 3
[2024-02-13 10:00:46] == Bulk renaming in /home/user ==
[2024-02-13 10:01:00] Renamed 42 files, 2 collisions avoided
[2024-02-13 10:01:00] Done.
```

### Dry-Run Output
```
[DRY] rm -rf /home/user/.cache/*
[DRY] mv "File Name.txt" "file-name.txt"
```
Each `[DRY]` line shows what *would* be executed.

## Performance Notes

- **Large directories**: May take several minutes for 100,000+ files
- **Hash calculation**: ~1-2 seconds per GB of duplicate file data
- **Memory usage**: Minimal - processes files iteratively
- **Disk I/O**: Intensive during duplicate detection phase

## Security Considerations

⚠️ **Important:**

1. **Never run untrusted scripts as root**
2. **Review the code before executing**
3. **Test on non-critical data first**
4. **Keep backups of important files**
5. **Use dry-run mode before any destructive operation**

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly with dry-run mode
4. Submit a pull request

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review the troubleshooting section above