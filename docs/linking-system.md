# Dotfiles Linking System

## Overview

The dotfiles repository uses **symlink-based configuration management** to maintain a single source of truth for all shell configurations, scripts, and system dotfiles. This document explains why, how, and when to use the linking system.

### Why Symlinks?

Symlinks provide several key benefits:

- **Single source**: One repository is the source of truth; no duplication of config files
- **Portable**: Configuration travels with the repo; easy to sync across machines via git
- **Version controlled**: All changes tracked, rollback capability, audit trail
- **Consistent**: Same config on all machines ensures predictable behavior
- **Easy updates**: `git pull && dotfiles-link` keeps everything current

Alternatives like file copying lead to inconsistency; manual edits in `$HOME` break version control.

### High-Level Architecture

The linking system operates in two modes:

#### Part 1: Nested Dotfiles (Hierarchical)

Recursively mirrors the directory structure from `dotfiles/` subdirectory into `$HOME`:

```
dotfiles/.zshrc          →  ~/.zshrc
dotfiles/.config/sway/   →  ~/.config/sway/
dotfiles/.zsh.d/         →  ~/.zsh.d/
```

**Features:**
- Nested directories created as needed
- Files symlinked individually
- Patterns in `.linkignore` exclude files from linking
- Conflicting files automatically backed up

#### Part 2: Flat Directory Syncing (Utility Scripts)

Symlinks all files from `bin/` and `lib/` repo directories to corresponding `$HOME` directories (flat, no nesting):

```
bin/my-script   →  ~/bin/my-script
lib/commons.sh  →  ~/lib/commons.sh
```

**Features:**
- Flat file syncing (no subdirectories)
- **Stale link cleanup**: Removes broken symlinks when source files are deleted
- Preserves external/custom symlinks (not created by this script)
- Logs and tracks all operations

## Using the Linking System

### When to Run

**You must run the linking script after:**

- Creating new scripts in `bin/`
- Creating executable files in `lib/`
- Creating or modifying dotfiles in `dotfiles/`
- Renaming, moving, or deleting any of the above
- Fresh checkout of the repository
- After a `git pull` that modified files

Failing to run the script results in:
- New/modified files invisible in your environment
- Stale symlinks pointing to deleted files
- Confusion during testing/debugging ("why doesn't this work?")

### How to Run

#### Primary: User-Facing Function

The recommended way is via the `dotfiles-link` shell function (defined in `~/.aliases`, **works in both bash and zsh**):

```bash
dotfiles-link              # Run linking and update shell command cache
dotfiles-link --dry-run    # Preview changes without applying
dotfiles-link -vv          # Verbose output (info-level)
dotfiles-link --help       # Show available options
```

**How it works:**
- Resolves repo root by following the `~/.aliases` symlink (symlink-safe)
- Calls `tools/link.sh` with your arguments
- Refreshes the shell's command cache:
  - `hash -r` in bash
  - `rehash` in zsh
- Available immediately after sourcing `~/.aliases` (loaded by both `.bashrc` and `.zshrc`)

**Shell-agnostic:** Unlike the previous zsh-only implementation, this function works in any shell that sources `~/.aliases`.

#### Direct Script Invocation

If the alias is unavailable:

```bash
./tools/link.sh [--dry-run|-n] [-v|-vv|--verbose[=N]] [--help|-h]
```

Command-line options:
- `-n, --dry-run`: Preview changes; do not modify filesystem
- `-v`: Verbosity level 1 (info)
- `-vv`: Verbosity level 2 (debug)
- `--verbose=N`: Set verbosity explicitly (0=quiet, 1=info, 2=debug, max 3)
- `-h, --help`: Show usage

### Safety Features

#### Automatic Backups

Before modifying or overwriting any file, the script creates a timestamped backup:

```
~/.local/state/dotfiles-link/backups/run-20260603T120045/
```

Backups are organized hierarchically and include:
- Files that were regular files but are now symlinks
- Symlinks pointing to the wrong target
- Conflicting directory structures

**Backup retention:** The script keeps the 10 most recent backup directories and automatically deletes older ones.

**Manual backup recovery:**

```bash
# List recent backups
ls -lt ~/.local/state/dotfiles-link/backups/

# Restore from a backup if needed
cp ~/.local/state/dotfiles-link/backups/run-*/path/to/file ~/actual/path/
```

#### Idempotence

Running the script multiple times is safe:
- Symlinks already pointing to the correct target are skipped
- No changes are made if everything is already correct
- Perfect for automation (cron, CI/CD, shell startup)

#### Stale Link Cleanup

When syncing `bin/` and `lib/`:
- Any symlinks in `~/bin` or `~/lib` pointing to deleted repo files are automatically removed
- External/custom symlinks (not pointing into the repo) are preserved
- Prevents accumulation of broken links

## Configuration

### Sync Directories

The `tools/link-config.conf` file defines which directories to sync:

```bash
declare -A SYNC_DIRS=(
  ["${REPO_ROOT}/bin"]="$HOME/bin"
  ["${REPO_ROOT}/lib"]="$HOME/lib"
)
```

**To add a new sync directory:**

1. Edit `tools/link-config.conf`
2. Add a new entry to `SYNC_DIRS`: `["${REPO_ROOT}/new_dir"]="$HOME/.new_dir"`
3. Run `dotfiles-link` to apply

Example: If you create `scripts/` and want it synced to `~/.local/bin/`:

```bash
declare -A SYNC_DIRS=(
  ["${REPO_ROOT}/bin"]="$HOME/bin"
  ["${REPO_ROOT}/lib"]="$HOME/lib"
  ["${REPO_ROOT}/scripts"]="$HOME/.local/bin"
)
```

### Ignore Patterns

The `.linkignore` file (in `tools/`) specifies patterns to exclude from linking. Patterns use sed regular expression syntax.

Example: If you want to exclude a specific file pattern from the nested `dotfiles/` linking:

```
# tools/.linkignore
# One pattern per line

^\.local/  # Exclude .local/ and everything under it
^_.*       # Exclude _archive, _local, etc. (underscore-prefixed dirs)
```

Patterns only affect the nested `dotfiles/` scanning. The flat `bin/` and `lib/` syncing is not filtered by `.linkignore`.

## Troubleshooting

### New File Not Appearing in $HOME

**Symptom:** You created `bin/my-new-script` or `dotfiles/.zshrc.local`, but it's not in `$HOME`.

**Solution:** Run `dotfiles-link`. The script does not automatically monitor for new files; you must invoke it explicitly after file system changes.

**Prevention:** Always run `dotfiles-link` immediately after creating/modifying files.

### Testing New Script and Changes Don't Take Effect

**Symptom:** You created `bin/test-script`, sourced it in a shell session, but the changes don't appear.

**Root causes:**
- File not symlinked (did you run `dotfiles-link`?)
- Shell command cache is stale (old version is still loaded)

**Diagnostic:**

```bash
# Check if symlink exists
ls -l ~/bin/test-script

# If no symlink, run:
dotfiles-link

# If symlink exists, rehash the shell's command cache:
rehash  # zsh
hash -r # bash
```

### Stale/Broken Symlinks Still Present

**Symptom:** You deleted a file from `bin/` or `lib/`, but the symlink in `$HOME/bin` or `$HOME/lib` still exists and is broken.

**Solution:** Run `dotfiles-link`. The script's stale link cleanup will remove broken symlinks pointing to deleted files.

```bash
dotfiles-link

# Verify the broken link is gone:
ls -l ~/bin/deleted-script  # Should give "No such file"
```

### I Manually Copied/Symlinked a File for Testing

**Symptom:** You manually ran `cp` or `ln -s` to work around a missing symlink or as a quick test, and now the linking state is inconsistent.

**Solution:** Always delegate to the linking script:

```bash
# Remove your manual link/copy:
rm ~/bin/manual-link

# Let the script re-create it properly:
dotfiles-link
```

**Why:** Manual links create orphaned files that the script won't clean up, and inconsistency can lead to confusion in future sessions.

### Backup Location Too Large or in Wrong Place

**Symptom:** `~/.local/state/dotfiles-link/backups/` is growing too large, or you prefer a different backup location.

**Current behavior:**
- Backups stored in `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-link/backups/`
- Follows XDG Base Directory spec
- Last 10 backup directories are retained

To change backup location, edit `tools/link.sh` (lines 23-24):

```bash
BACKUP_BASE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-link/backups"
BAKDIR="${BACKUP_BASE_DIR}/run-$(date +%Y%m%dT%H%M%S)"
```

For example, to use `/tmp/`:

```bash
BACKUP_BASE_DIR="/tmp/dotfiles-link-backups"
```

## For Developers & AI Agents

### Key Pattern for New Features

When adding new scripts or configurations:

1. **Create file** in appropriate location:
   - New shell script → `bin/my-script`
   - New dotfile config → `dotfiles/.config/app/config`

2. **Run linking immediately:**
   ```bash
   dotfiles-link -vv
   ```

3. **Verify it's available** before testing:
   ```bash
   ls -l ~/bin/my-script  # Should show symlink to repo
   ```

4. **Then test** your new feature

**Why this order prevents confusion:**
- You know the file is available where you expect it
- Testing failures are due to code/config, not missing symlinks
- Debugging is faster and more accurate

### Never Manually Link (Except Debugging)

**Don't:**

```bash
# Manual workaround (creates orphans, inconsistency)
ln -s /home/cbaoth/dotfiles/bin/my-script ~/bin/my-script
cp /home/cbaoth/dotfiles/dotfiles/.zshrc ~/.zshrc
```

**Do:**

```bash
# Let the script manage everything
dotfiles-link
```

**Why:** Manual approaches bypass the script's safety checks (backups, stale link cleanup, validation) and can leave orphaned files that future runs won't understand.

### Recognizing When Linking is Needed

If you encounter mysterious test failures or missing functionality while developing:

1. **Check:** Is the file actually in `$HOME` where the code expects it?
   ```bash
   ls -l ~/.config/app/config  # or wherever
   ```

2. **Diagnose:** If the file is a symlink, does it point to the correct repo location?
   ```bash
   readlink ~/.config/app/config
   ```

3. **If not linked:** Run `dotfiles-link`

4. **If symlink is stale (points to non-existent file):** Run `dotfiles-link` to clean up

This pattern eliminates false debugging sessions caused by assumption mismatches.

### Cleanup After Manual Intervention

If you manually linked something while debugging:

1. Remove the manual link:
   ```bash
   rm ~/.local/test-config  # or wherever
   ```

2. Run the linking script to ensure consistency:
   ```bash
   dotfiles-link
   ```

3. Document (if needed) what the debugging discovered so future iterations aren't needed

## Design Decisions

### Why Not Use GNU Stow or chezmoi?

This repository intentionally keeps the linking system dependency-free:

- **Pure shell**: No external tools required (works on any POSIX system with bash)
- **Lightweight**: Single script, ~300 lines, easy to understand and modify
- **Portable**: Works on systems where `stow` or `chezmoi` aren't available
- **Clear semantics**: Simple backup/cleanup logic, no hidden complexity

If the dotfiles setup becomes significantly more complex (e.g., template rendering, conditional deployments, multi-user scenarios), reconsidering these tools may be worthwhile. Until then, the custom solution offers good value for this use case.

### Why Separate Nested and Flat Syncing?

**Nested** (`dotfiles/`):
- Preserves directory structure (important for configs like `.config/sway/config`)
- Supports selective exclusion via `.linkignore`
- Handles root-level dotfiles (`.zshrc`, `.vimrc`, etc.)

**Flat** (`bin/`, `lib/`):
- No directory nesting (keeps `$HOME/bin` clean, predictable)
- Automatic stale link cleanup (safe when scripts are deleted)
- Preserves external/custom symlinks (e.g., system tools you symlinked for convenience)

Combining them would make the script more complex and lose these benefits.

## Related

- `CLAUDE.md` — Quick reference for everyday use
- `tools/link.sh` — Implementation (well-commented)
- `tools/link-config.conf` — Configuration (sync directory pairs)
- `tools/.linkignore` — Patterns to exclude from linking
- `README.md` — Repository overview and quick-start
