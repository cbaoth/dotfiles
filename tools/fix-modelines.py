#!/usr/bin/env python3
# -*- mode: python; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=python:et:ts=2:sts=2:sw=2
#
# fix-modelines.py: Normalize shell script editor modelines (order, content, completeness).
#
# Usage:
#   ./fix-modelines.py [OPTIONS] [FILE ...]         # process specific files
#   find bin/ -type f | ./fix-modelines.py [OPTIONS]  # or via stdin
#
# Default mode: update files in-place.  Use -n/--dry-run to preview changes.

import argparse
import difflib
import re
import sys
from pathlib import Path

# {{{ = CONSTANTS =============================================================

SCAN_LINES = 15  # Only look for existing modelines within the first N lines

# File extensions that are definitively not shell scripts — always skip.
# Note: Some of these might contain shell code (e.g. .conf files may be sourced
# by shell scripts), but in such cases one can simply add a bash/sh modeline
# since this check is performed first.
SKIP_EXTENSIONS = {
  '.md', '.adoc', '.txt', '.rst',
  '.json', '.yaml', '.yml', '.toml', '.ini', '.xml', '.conf',
  '.html', '.htm', '.css', '.js', '.ts',
  '.py', '.rb', '.pl', '.php', '.java', '.go', '.rs', '.c', '.h', '.cpp',
  '.bat', '.cmd', '.ps1', '.vbs',
  '.properties', '.cfg', '.env',
  '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico',
  '.pdf', '.zip', '.tar', '.gz', '.bz2', '.xz',
}

# Basenames of well-known zsh config files (no extension).
ZSH_CONFIGS = {
  '.zshrc', '.zlogin', '.zlogout', '.zshenv', '.zprofile',
}

# Basenames of well-known bash/sh config files (no extension).
# Files shared across shells (e.g. .profile, .common_env) → bash as safest default.
BASH_CONFIGS = {
  '.bashrc', '.bash_profile', '.bash_logout', '.bashenv',
  '.profile', '.common_env',
}

# ANSI colour codes.
_ANSI_RED    = '\033[31m'
_ANSI_YELLOW = '\033[33m'
_ANSI_GREEN  = '\033[32m'
_ANSI_BLUE   = '\033[34m'
_ANSI_CYAN   = '\033[36m'
_ANSI_GRAY   = '\033[90m'
_ANSI_RESET  = '\033[0m'

# File extensions that suggest a shell script but might be missing a header.
SHELL_EXTENSIONS = {'.sh', '.zsh', '.bash'}

# }}} = CONSTANTS =============================================================

# {{{ = REGEX PATTERNS ========================================================

# Detection patterns (match existing modelines of any content).
RE_EMACS      = re.compile(r'^#\s+-\*-\s+mode:\s+sh[\s;]')
RE_VIM        = re.compile(r'^#\s+vim:\s+ft=(?:bash|zsh|sh)\b')
RE_CODE       = re.compile(r'^#\s+code:\s+language=(?:bash|zsh|sh|shellscript)\b')
RE_SHELLCHECK = re.compile(r'^#\s+shellcheck\s+shell=(?:bash|zsh|sh)\b')

# Shebang: capture just the shell name.
# Broad on purpose — matches standard and non-standard paths (e.g. #!/bin/env bash)
# so misplaced or non-portable shebangs are still detected and moved to line 1.
RE_SHEBANG = re.compile(r'^#!\s*(?:\S*/)?(?:env\s+)?(bash|zsh|sh)\b')

# Extractors for shell value from existing modelines.
RE_EMACS_SHELL      = re.compile(r'sh-shell:\s*(bash|zsh|sh)\b')
RE_VIM_SHELL        = re.compile(r'\bft=(bash|zsh|sh)\b')
RE_CODE_SHELL       = re.compile(r'\blanguage=(bash|zsh|sh|shellscript)\b')
RE_SHELLCHECK_SHELL = re.compile(r'\bshell=(bash|zsh|sh)\b')

# }}} = REGEX PATTERNS ========================================================

# {{{ = HELPERS ===============================================================

def _warn(msg: str) -> None:
  print(f'{_ANSI_YELLOW}warning: {msg}{_ANSI_RESET}', file=sys.stderr)


def _err(msg: str) -> None:
  print(f'{_ANSI_RED}error: {msg}{_ANSI_RESET}', file=sys.stderr)


def _find_shebang(lines: list[str]) -> tuple[int, str | None]:
  """Scan the first SCAN_LINES for a shell shebang. Returns (line_index, shell) or (-1, None)."""
  for i, line in enumerate(lines[:SCAN_LINES]):
    m = RE_SHEBANG.match(line.rstrip())
    if m:
      return i, m.group(1)
  return -1, None


def _normalize_shebang(shebang_line: str, shell: str) -> str:
  """Return the canonical shebang for the given shell, preserving the original line ending.

  Canonical form: #!/usr/bin/env SHELL
  Any other form (e.g. #!/bin/bash, #!/bin/env zsh) is rewritten.
  """
  canonical = f'#!/usr/bin/env {shell}'
  # Preserve whatever line ending the original had (\n, \r\n, or none).
  ending = shebang_line[len(shebang_line.rstrip('\r\n')):]
  current = shebang_line.rstrip('\r\n')
  if current == canonical:
    return shebang_line  # already correct, no change
  return canonical + (ending or '\n')

# }}} = HELPERS ===============================================================

# {{{ = MODELINE GENERATION ===================================================

def make_modelines(shell: str, sourced: bool) -> list[str]:
  """Return the 4 canonical modeline strings for the given shell and file type.

  Args:
    shell:   One of 'bash', 'zsh', 'sh'.
    sourced: True if the file has no shebang (sourced / rc file).
  Returns:
    List of 4 modeline strings, each ending with '\\n', in style-guide order:
    emacs, vim, code, shellcheck.
  """
  sc_shell   = 'bash' if shell == 'zsh' else shell
  sc_disable = ' disable=SC2148' if sourced else ''
  return [
    f'# -*- mode: sh; sh-shell: {shell}; indent-tabs-mode: nil; tab-width: 2 -*-\n',
    f'# vim: ft={shell}:et:ts=2:sts=2:sw=2\n',
    f'# code: language={shell} insertSpaces=true tabSize=2\n',
    f'# shellcheck shell={sc_shell}{sc_disable}\n',
  ]

# }}} = MODELINE GENERATION ===================================================

# {{{ = FILE ELIGIBILITY ======================================================

def _has_null_bytes(raw: bytes) -> bool:
  return b'\x00' in raw


def is_eligible(path: Path, lines: list[str]) -> tuple[bool, str]:
  """Return (eligible, reason) for the given file.

  eligible: True if the file looks like a shell script worth processing.
  reason:   Human-readable explanation when eligible is False; empty string otherwise.

  Eligibility criteria (any one makes the file eligible):
  - Contains at least one recognised shell modeline in the first SCAN_LINES
    (explicit opt-in: takes precedence over extension-based skipping, so e.g.
    a .conf file that is a sourced shell script can be processed once modelines
    are present)
  - Has a bash/zsh/sh shebang anywhere in the first SCAN_LINES

  Files with a known non-shell extension and no modelines are always skipped.
  Files with a shell-suggestive extension (.sh/.zsh/.bash) but neither shebang
  nor modelines emit a warning — they likely have a missing header.
  """
  suffix = path.suffix.lower()
  scan = lines[:SCAN_LINES]
  # Shell modelines are an explicit opt-in — always eligible regardless of extension.
  # This allows non-standard extensions (e.g. .conf) used as sourced shell files.
  for line in scan:
    stripped = line.rstrip()
    if (RE_EMACS.match(stripped) or RE_VIM.match(stripped)
        or RE_CODE.match(stripped) or RE_SHELLCHECK.match(stripped)):
      return True, ''
  # Skip known non-shell extensions (only reached if no modelines found above)
  if suffix in SKIP_EXTENSIONS:
    return False, (f"extension '{suffix}' is in the non-shell exclude list; "
                   f"add a shell modeline to override, or use --force")
  # Shebang anywhere in scan window
  shebang_idx, _ = _find_shebang(lines)
  if shebang_idx >= 0:
    return True, ''
  # Warn for shell-extension files that lack any shell header
  if suffix in SHELL_EXTENSIONS:
    _warn(f'{path}: .{suffix[1:]} file has no shell shebang or modelines, consider adding a shebang or changing the file extension (if not a standalone executable script)')
  return False, f"no shell shebang or modeline found in first {SCAN_LINES} lines"

# }}} = FILE ELIGIBILITY ======================================================

# {{{ = SHELL DETECTION =======================================================

def _shell_from_modelines(lines: list[str]) -> str | None:
  """Try to infer shell from existing modelines (emacs/vim/code preferred over shellcheck)."""
  for line in lines[:SCAN_LINES]:
    s = line.rstrip()
    if RE_EMACS.match(s):
      m = RE_EMACS_SHELL.search(s)
      if m:
        return m.group(1)
    if RE_VIM.match(s):
      m = RE_VIM_SHELL.search(s)
      if m:
        return m.group(1)
    if RE_CODE.match(s):
      m = RE_CODE_SHELL.search(s)
      if m:
        v = m.group(1)
        return 'bash' if v == 'shellscript' else v
  # shellcheck is last since it always says 'bash' even for zsh files
  return None


def detect_shell(path: Path, lines: list[str]) -> str:
  """Detect the shell type for a file. Returns 'bash', 'zsh', or 'sh'."""
  # 1. Shebang (anywhere in first SCAN_LINES, not just line 1)
  _, shebang_shell = _find_shebang(lines)
  if shebang_shell:
    return shebang_shell

  # 2. File extension
  suffix = path.suffix.lower()
  if suffix == '.zsh':
    return 'zsh'
  if suffix in ('.bash',):
    return 'bash'
  # .sh stays ambiguous — fall through to other heuristics

  # 3. Known config file names
  name = path.name
  if name in ZSH_CONFIGS:
    return 'zsh'
  if name in BASH_CONFIGS:
    return 'bash'

  # 4. Parent directory name contains 'zsh'
  for part in path.parts:
    if 'zsh.d' in part or part == '.zsh.d':
      return 'zsh'

  # 5. Existing modelines
  detected = _shell_from_modelines(lines)
  if detected:
    return detected

  # 6. Fallback
  return 'bash'

# }}} = SHELL DETECTION =======================================================

# {{{ = PROCESSING ============================================================

def _is_modeline(line: str) -> bool:
  s = line.rstrip()
  return bool(
    RE_EMACS.match(s) or RE_VIM.match(s)
    or RE_CODE.match(s) or RE_SHELLCHECK.match(s)
  )


def process_file(
  path: Path,
  *,
  force_shell: str | None = None,
  dry_run: bool = False,
  verbose: int = 0,
  force: bool = False,
  fix_shebang: bool = True,
) -> str:
  """Process a single file. Returns a status string: 'ok', 'changed', 'skipped', 'error'.

  Side effect: writes the updated content to the file unless dry_run is True.
  """
  # Read file
  try:
    raw = path.read_bytes()
  except OSError as e:
    _err(f'{path}: {e}')
    return 'error'

  if _has_null_bytes(raw):
    if verbose >= 1:
      print(f'{_ANSI_YELLOW}skip (binary): {path}{_ANSI_RESET}', file=sys.stderr)
    return 'skipped'

  try:
    text = raw.decode('utf-8')
  except UnicodeDecodeError:
    try:
      text = raw.decode('latin-1')
    except UnicodeDecodeError:
      print(f'{_ANSI_YELLOW}skip (unreadable encoding): {path}{_ANSI_RESET}', file=sys.stderr)
      return 'skipped'

  lines = text.splitlines(keepends=True)

  # Eligibility check — is_eligible also emits warnings for suspicious files
  eligible, reason = (True, '') if force else is_eligible(path, lines)
  if not eligible:
    print(f'{_ANSI_YELLOW}skip (not a shell script): {path}{_ANSI_RESET}', file=sys.stderr)
    if verbose >= 2 and reason:
      print(f'{_ANSI_GRAY}  reason: {reason}{_ANSI_RESET}', file=sys.stderr)
    return 'skipped'

  # Locate shebang anywhere in first SCAN_LINES
  shebang_idx, shebang_shell = _find_shebang(lines)
  sourced = shebang_idx < 0

  # Warn if shebang exists but is not on line 1
  if shebang_idx > 0:
    _warn(f'{path}: shebang found on line {shebang_idx + 1}, moving to line 1')

  # Determine shell
  shell = force_shell or detect_shell(path, lines)

  # Warn if forced shell conflicts with shebang
  if force_shell and shebang_shell and shebang_shell != force_shell:
    _warn(f'{path}: --shell {force_shell} differs from shebang shell {shebang_shell}')

  # Build canonical modelines
  new_modelines = make_modelines(shell, sourced)

  # Extract shebang line; optionally normalize to #!/usr/bin/env SHELL.
  shebang_line = lines[shebang_idx] if shebang_idx >= 0 else None
  if shebang_line and fix_shebang:
    normalized = _normalize_shebang(shebang_line, shell)
    if normalized != shebang_line:
      _warn(f'{path}: non-standard shebang rewritten: {shebang_line.rstrip()!r} → {normalized.rstrip()!r}')
    shebang_line = normalized

  # Remove all modelines AND the shebang from the line list.
  clean = [
    line for i, line in enumerate(lines)
    if not _is_modeline(line) and i != shebang_idx
  ]

  # Re-prepend shebang (now always at index 0), then insert modelines after it.
  if shebang_line:
    clean = [shebang_line] + clean
    insert_at = 1
  else:
    insert_at = 0

  result = clean[:insert_at] + new_modelines + clean[insert_at:]

  # Detect change
  original = ''.join(lines)
  updated  = ''.join(result)

  if updated == original:
    if verbose >= 1:
      print(f'ok (no change): {path}')
    return 'ok'

  # Verbose: show diff
  if verbose >= 1:
    diff = difflib.unified_diff(
      lines, result,
      fromfile=f'a/{path}',
      tofile=f'b/{path}',
      lineterm='',
    )
    for diff_line in diff:
      if diff_line.startswith('---') or diff_line.startswith('+++'):
        print(f'{_ANSI_CYAN}{diff_line}{_ANSI_RESET}')
      elif diff_line.startswith('-'):
        print(f'{_ANSI_RED}{diff_line}{_ANSI_RESET}')
      elif diff_line.startswith('+'):
        print(f'{_ANSI_GREEN}{diff_line}{_ANSI_RESET}')
      else:
        print(diff_line)

  if dry_run:
    print(f'{_ANSI_BLUE}would change: {path}{_ANSI_RESET}')
  else:
    path.write_text(updated, encoding='utf-8')
    print(f'{_ANSI_BLUE}changed: {path}{_ANSI_RESET}')

  return 'changed'

# }}} = PROCESSING ============================================================

# {{{ = CLI ===================================================================

def build_parser() -> argparse.ArgumentParser:
  p = argparse.ArgumentParser(
    prog='fix-modelines.py',
    description=(
      'Normalize editor modelines in shell scripts.\n'
      'Enforces order: emacs → vim → code → shellcheck.\n'
      'Fixes content: shell type, indent settings, SC2148 for sourced files.\n'
      'Adds missing modelines; removes duplicates.'
    ),
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog=(
      'Examples:\n'
      '  # Dry-run with diff on all bin/ scripts:\n'
      '  ./fix-modelines.py -nv bin/*\n\n'
      '  # Apply to all shell files:\n'
      '  ./fix-modelines.py bin/* lib/* .zshrc .zsh.d/*.zsh\n\n'
      '  # Force zsh shell, process file that has no modelines yet:\n'
      '  ./fix-modelines.py --force --shell zsh .zshrc\n\n'
      '  # Via stdin:\n'
      '  find bin/ -type f | ./fix-modelines.py -n'
    ),
  )
  p.add_argument(
    'files', nargs='*', metavar='FILE',
    help='Files to process (reads from stdin if none given)',
  )
  p.add_argument(
    '-n', '--dry-run', action='store_true',
    help='Show what would change without writing files',
  )
  p.add_argument(
    '-v', '--verbose', action='count', default=0,
    help='-v: show ok files and diffs; -vv: also show per-file skip reasons',
  )
  p.add_argument(
    '-s', '--shell', choices=['bash', 'zsh', 'sh'], metavar='SHELL',
    help='Force shell type (bash|zsh|sh); skips auto-detection',
  )
  p.add_argument(
    '-f', '--force', action='store_true',
    help='Process any readable text file (skip shell-script eligibility checks)',
  )
  p.add_argument(
    '--no-fix-shebang', action='store_true',
    help='Do not rewrite non-standard shebangs (e.g. #!/bin/bash stays as-is); '
         'misplaced shebangs are still moved to line 1',
  )
  return p


def main() -> None:
  parser = build_parser()
  args   = parser.parse_args()

  if args.files:
    files = args.files
  elif not sys.stdin.isatty():
    files = sys.stdin.read().split()
  else:
    parser.print_help()
    sys.exit(1)

  counts = {'ok': 0, 'changed': 0, 'skipped': 0, 'error': 0}
  for f in files:
    status = process_file(
      Path(f),
      force_shell=args.shell,
      dry_run=args.dry_run,
      verbose=args.verbose,
      force=args.force,
      fix_shebang=not args.no_fix_shebang,
    )
    counts[status] += 1
    if status == 'ok' and args.verbose < 1:
      pass  # suppress OK lines unless -v

  total = sum(counts.values())
  c_changed = counts['changed']
  c_ok      = counts['ok']
  c_skipped = counts['skipped']
  c_error   = counts['error']
  changed_s = f'{_ANSI_BLUE}{c_changed} changed{_ANSI_RESET}'
  ok_s      = f'{_ANSI_GREEN}{c_ok} ok{_ANSI_RESET}'
  skipped_s = (f'{_ANSI_YELLOW}{c_skipped} skipped{_ANSI_RESET}' if c_skipped
               else f'{c_skipped} skipped')
  error_s   = (f'{_ANSI_RED}{c_error} error(s){_ANSI_RESET}' if c_error
               else f'{c_error} error(s)')
  print(f'\nDone: {total} file(s) — {changed_s}, {ok_s}, {skipped_s}, {error_s}')


# }}} = CLI ===================================================================

if __name__ == '__main__':
  main()
