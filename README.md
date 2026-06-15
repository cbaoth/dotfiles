# My Dot-Files

Andreas Weyer <dev@cbaoth.de>

## Summary

My core configuration (dot) files, shell functions and utility scripts.

### Repository Structure

```
dotfiles/        Actual dotfiles symlinked to $HOME (zsh, bash, vim, X11, etc.)
bin/             User utility scripts (added to PATH via ~/bin/)
system-scripts/  System/admin scripts (some require root)
lib/             Shared shell libraries (commons.sh)
tools/           Repo tooling: link.sh, fix-modelines.py, etc.
docs/            Documentation and TODO
_archive/        Archived scripts pending review (not in PATH)
```

- `ZSH` is the leading shell.
- `Bash` configs exist for rare cases in which zsh is not available, they are
  not regularly maintained and usually outdated (consolidation is however a
  backlog topic).
- Portability is a core goal: the `dotfiles/` + `bin/` + `lib/` + `tools/link.sh`
  approach is intentionally dependency-free and should work without additional
  packages or root access.
- Restricted-host support matters: basic setup should still be usable on
  systems with only `bash` available (no `zsh`, no extra tooling).
- If not clearly `ZSH` related, all alias, function, etc. files should be `Bash` compatible _(but not always POSIX compliant)_.
- All files use the `" \{\{\{( .*)?$"` _(or `{{{ }}}` in short)_ folding comment pattern _(use e.g. [emacs](https://www.emacswiki.org/emacs/FoldingMode), [VS Code](https://marketplace.visualstudio.com/items?itemName=zokugun.explicit-folding), [eclipse](https://stackoverflow.com/a/6947590))_

> **Note:** See [docs/TODO.md](docs/TODO.md) for the full task/improvement list.

### Dot-files

| File / Folder | App | Description |
|---|---|---|
| `dotfiles/.zshenv` | [ZSH](https://en.wikipedia.org/wiki/Z_shell) | Common ZSH login shell environment (variables). |
| `dotfiles/.zlogout` | ZSH | Common ZSH logout cleanup |
| `dotfiles/.zshrc` | ZSH | Common ZSH config |
| `dotfiles/.zsh.d/zshrc-freebsd.zsh` / `zshrc-motoko.zsh` / `zshrc-puppet.zsh` / `zshrc-saito.zsh` / `zshrc-11001001_org.zsh` | ZSH | OS, distribution, and/or host specific ZSH configs. |
| `dotfiles/.zsh.d/aliases.zsh` | SH | Common aliases |
| `dotfiles/.zsh.d/aliases-freebsd.zsh` / `aliases-linux.zsh` / `aliases-linux_wsl.zsh` | SH | OS, distribution, and/or host specific aliases. |
| `dotfiles/.bashrc` | [Bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) | Common Bash config _(rarely maintained)_. |
| `dotfiles/.xsession` | X, Wayland | Used by the display manager. Loads `.profile` and `.xinitrc`. |
| `dotfiles/.xinitrc` | [X](https://en.wikipedia.org/wiki/X_Window_System), [Wayland](https://en.wikipedia.org/wiki/Wayland_(display_server_protocol)) | Loaded from inside `.xsession` or when starting `xinit`. |
| `dotfiles/.xsession.d/common` / `default` / `saito` | X, Wayland | Common, default and host specific xsession initialization scripts loaded from inside `.xinitrc`. The `common` script is always loaded, the host specific script `.xsession.d/{hostname}` is loaded if existing, else the fallback `default` is loaded. |
| `dotfiles/.Xresources` / `.Xresources.d/saito` | X, Wayland | Common and host specific [X Resources](https://en.wikipedia.org/wiki/X_resources). The `.Xresources` file is loaded from inside `.xsession.d/common`. If a host specific `.Xresources.d/{hostname}` exists, it is merged into the common resources. |
| `dotfiles/.imwheelrc` | [IMWheel](http://imwheel.sourceforge.net/) | General and app specific mouse button/wheel mappings. |
| `dotfiles/.vimrc` | [VIM](https://www.vim.org/) | VIM configuration |
| `dotfiles/.config/mpv/config` / `input.conf` | [mpv](https://en.wikipedia.org/wiki/Mpv_(media_player)) | MPV configuration and key bindings. |
| `dotfiles/.mplayer/config` / `input.conf` | [MPlayer](https://en.wikipedia.org/wiki/MPlayer) | Old MPlayer configuration and key bindings (switched to `mpv`). |

#### Host / OS specific zsh files

Custom host / OS specific ZSH configurations, aliases, functions, xsessions and xresources can be created and they are dynamically loaded in case of a match. This provides a convenient way to enrich the environment in case of a specific host / os without messing around with the core files.

This is the sequence in which zshrc's, aliases and functions are loaded from within `.zshrc`:

```bash
 # top of zshrc (always loaded)
 .zsh.d/aliases.zsh
 lib/functions.sh

 # bottom of zshrc (loaded in given sequence if host/os matches)
 .zsh.d/functions-${OS}.zsh
 .zsh.d/functions-${HOST}.zsh
 .zsh.d/functions-${HOST}-${OS}.zsh
 .zsh.d/functions-${HOST}-${OS}_wsl.zsh

 .zsh.d/aliases-${OS}.zsh
 .zsh.d/aliases-${HOST}.zsh
 .zsh.d/aliases-${HOST}-${OS}.zsh
 .zsh.d/aliases-${HOST}-${OS}_wsl.zsh

 .zsh.d/zshrc-${OS}.zsh
 .zsh.d/zshrc-${HOST}.zsh
 .zsh.d/zshrc-${HOST}-${OS}.zsh
 .zsh.d/zshrc-${HOST}-${OS}_wsl.zsh
```

The special suffix `_wsl` is used on [Windows Subsystem Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux), this allows the `-linux` files to be loaded in addition to (followed by) a WSL specific `-linux_wsl` file.

Some examples can be seen in the [Dot-files](#dot-files) list above.

### User Scripts (`bin/`)

| File | Description |
|---|---|
| `bin/media-keys` | Script to be used from within X (e.g. media key mappings) for media player control (play/pause, prev/next song) and pulse audio volume control (+/-5% and toggle mute) optionally showing an OSD. |
| `bin/apt-update` | Quietly update apt package indexes and store a timestamp. |
| `bin/exif-move-to-rating-dirs` | Organize image files into a directory hierarchy based on EXIF star ratings (0-5) and color labels. Features smart caching, directory mapping with regex patterns, and move/copy modes. See `bin/exif-move-to-rating-dirs.d/README.adoc` for full documentation. |
| `bin/smfetch` | Fetch RTMP and direct HTTP media links from broadcaster pages using wget and rtmpdump. |
| `bin/aria2c-d` | aria2c downloader wrapper. |
| `bin/diff-ini` | Diff INI files. |
| `bin/ff-copy` | Firefox copy utility. |
| `bin/ff-copy-mpv-bookmarks` | Copy MPV bookmarks from Firefox. |
| `bin/getbyext` | Get files by extension from a given URL using wget. |
| `bin/gif-cycle` | GIF frame cycling utility. |
| `bin/gif-delay` | GIF frame delay inspector/modifier. |
| `bin/git-fix-chmod` | Fix Git file permissions (chmod). |
| `bin/image-concat` | Concatenate images. |
| `bin/mpv-find` | Find media files and play with mpv. |
| `bin/netshare-bench` | Benchmark mounted network shares (NFS/CIFS/SMB) using `fio` and `iozone`. Tests sequential/random I/O, parallel photo-app reads (Lightroom/XnView MP workload), directory traversal (readdir/getattr RPC load), and network latency. Useful for comparing protocols and configuration tuning (LAN vs. Wi-Fi, server/client settings). All output is logged to a timestamped file alongside stdout. |
| `bin/rsync-parallel-backup` | Parallel rsync backup. |
| `bin/rsynclt` | rsync with limited throughput. |
| `bin/wget-p` | Parallel file fetching wrapper for wget. |
| `bin/while-read` | Execute a command for each line read from stdin. |
| `bin/xsuspend` | Suspend the X session. |

### System / Admin Scripts (`system-scripts/`)

Scripts intended for system administrators or privileged operations (some require root).

| File | Description |
|---|---|
| `system-scripts/backup` | System backup script with exclusion list; supports full and incremental backups. |
| `system-scripts/bedtime-shutdown/bedtime-shutdown.sh` | Force system shutdown at a configured bedtime with grace periods, desktop notifications, and emergency overrides. See `system-scripts/bedtime-shutdown/README.adoc` for full documentation. |
| `system-scripts/dbbackup` | Backup script for MySQL and PostgreSQL databases. |
| `system-scripts/fail2ban-summary-mail` | Send a weekly Fail2Ban summary email from recent log data (intended for cron). |
| `system-scripts/nextcloud-maintenance` | Run routine Nextcloud maintenance tasks (DB indices, repair, integrity checks, app updates). Intended for cron with cronic. |
| `system-scripts/nordvpn-ipv6-watcher/nordvpn-ipv6-watcher` | Restore IPv6 after NordVPN 5.x disables it system-wide (daemon + systemd unit). See `system-scripts/nordvpn-ipv6-watcher/README.adoc`. |
| `system-scripts/openvpn-client-cfg` | Generate OpenVPN client configuration bundles from server PKI assets; manage static IPs, CCD, and certificate revocation. |

### Repository Tooling (`tools/`)

| File | Description |
|---|---|
| `tools/link.sh` | Symlink all files in `dotfiles/` to the user's home directory. Missing directories are created in the process. Existing files that would be overwritten are moved to a backup location. |
| `tools/permissions.sh` | Update dotfile repo file permissions. |
| `tools/fix-modelines.py` | Normalize and deduplicate editor modelines (Emacs, Vim, VS Code, ShellCheck) across shell scripts. |
| `tools/fix-style.sh` | Apply style fixes to shell scripts. |
| `README.adoc` | This file. |

## Shell Functions

Some of the shell functions contained in `lib/functions.sh` will be described in the following chapters.

### Print

| Function | Description |
|---|---|
| **`p_usg`** _USAGE.._ | Print a _Usage_ text. |
| **`p_msg`** _MSG.._ | Print an info message. |
| **`p_war`** _MSG.._ | Print a warning message. |
| **`p_err`** _MSG.._ | Print an error message _(stderr)_. |
| **`p_dbg`** _DBG_LVL SHOW_AT_LVL MSG.._ | Print a debug msg if the given debug level is reached. A global debug level can be set via the `DBG_LVL` variable, in this case `p_dbg` will use the higher level `max(arg-level, global-level)`, meaning whichever is larger. As a result the global level can be used to globally raise, but never to lower the locally used debug level. So simply set the `DBG_LVL` argument to `0` if only the global level should be considered. |
| **`p_yes`** / **`p_no`** | Print _yes_ in green and _no_ in red color. |
| **`py_print`** [-i import] PY_CODE.. | Route the given `code` through the _python3_ `print` function. Use `-i` to import additional packages. |

#### Colors

| Function | Description |
|---|---|
| **`p_colortable`** | Print 256 ansi color table. |
| **`tputs`** _STYLE.._ | Execute multiple `tput` commands in sequence. |
| **`tp`** _STYLE.._ | Set one or more tput colors and text effects by (short) name. All values are looked up from a map _(no need to run an external process)_. |

### Shell Functions

| Function | Description |
|---|---|
| **`func_name`** | Returns the current function's name: `${FUNCNAME[0]}` on `bash`, `${funcstack[1]}` on `zsh`. |
| **`func_caller`** | Returns the function's caller name _(if caller is a function)_: `${FUNCNAME[1]}` on `bash`, `${funcstack[2]}` on `zsh`. |

### Predicates

| Function | Description |
|---|---|
| **`is_zsh`** | `true` if `zsh` session, else: `false` |
| **`is_bash`** | `true` if `bash` session, else: `false` |
| **`is_su`** | `true` if root (super user) session, else: `false` |
| **`is_sudo`** | `true` if in sudo mode, else: `false` |
| **`is_sudo_cached`** | `true` if sudo has cached credentials, else: `false` |
| **`is_ssh`** | `true` if ssh session, else: `false` |
| **`is_int`** _NUMBER.._ | `true` if all given numbers are integers _(only digits)_, else: `false`. Ignores leading/trailing spaces, accepts leading +/- sign. |
| **`is_decimal`** _NUMBER.._ | `true` if all given numbers are decimals _(only digits, MUST contain decimal separator '.')_, else: `false`. Ignores leading/trailing spaces, accepts leading +/- sign. |
| **`is_number`** _NUMBER.._ | `true` if all given numbers a either integers or decimals _(only digits, CAN contain decimal separator '.')_, else: `false`. Ignores leading/trailing spaces, accepts leading +/- sign. |
| **`is_positive`** _NUMBER.._ | `true` if all numbers do _NOT_ start with a `-`, else: `false`. Ignores leading/trailing spaces. _Note: This doesn't check if the arguments are numbers (it simply checks for a leading `-`, should always be used in combination with `is_int/decimal/number`)._ |

### Queries

| Function | Description |
|---|---|
| **`q_yesno`** _QUESTION_ | Print the `QUESTION` and asks for (y)es/(n)o input. Returns true if answer is `yes`, else: `false`. |
| **`q_overwrite`** _FILE_ | Checks if the given file exists, if so asks wether to overwrite it via (y)es/(n)o input. Returns `true` only if `FILE` exists AND if answer is `yes`, else: `false`. |

### Arrays

| Function | Description |
|---|---|
| **`join_by`** _DELIMITER ARRAY.._ | Join array / arguments using the given delimiter. On ZSH consider using `${(j:del:)array}`. Note that on `zsh` the same can be achived via `${(j:.:)ip}`. |

### Command

| Function | Description |
|---|---|
| **`cmd_delay`** _DELAY COMMAND.._ | Execute a command with a delay (using `sleep` format, e.g. `3m` for 3 minutes). _Sleep timer example:_ `cmd_delay 45m systemctl suspend`. |
| **`while_read`** _COMMAND.._ | Monitor input _(read lines)_ and execute command in foreground using input as command argument. _Example: `while_read wget` to download all entered urls._ |
| **`while_read_bg`** _COMMAND.._ | Monitor input _(read lines)_ and execute command in background _(job)_ using input as command argument. _Example: `while_read_bg wget` to download all entered urls._ |
| **`while_read_xclip`** [OPTION..] _COMMAND.._ | Monitor X clipboard and execute command using clipboard content as command argument. _Example:_ `while_read_xclip -b -m '^https?://.*' tee -a links.txt "<<<'{}'" \| wget -nv -c -i -` _to append all http(s) URLs read vom clipboard to a file named `links.txt` and download them using wget._ |

### Math

| Function | Description |
|---|---|
| **`calc`** _EXPR.._ | A simple wrapper for `dc`. Set the decimal scale using the `-s` option (default: 0). |
| **`py_calc`** _PY_CODE.._ | Routes `PY_CODE` through python3's `print` function with `from math import *`. Apart from this additional import it's basically the same as `py_print` so this is also possible _(even without the math. prefix)_. |

### Internet

| Function | Description |
|---|---|
| **`ytp`** _URL.._ | Download media files using [youtube-dl](https://rg3.github.io/youtube-dl/) and [aria2c](https://aria2.github.io/) _(4 concurrent downloads, 4 threads per host)_ using the same output file names provide by `youtube-dl` using the following pattern: `%(title)s [%(id)s].%(ext)s`. _Note that this is basically the same as the alias `yt` but using `aria2c` for parallel download instead of the integrated, single threaded downloader. When multiple formats are available, all `yt*` commands will favor free codecs starting with the highest quality streams (rough codec/format priority: vp9/opus/vp8/vorbis/webm/ogg/*)._ |
| **`ytap`** _URL.._ | The same as `ytp` above, but downloads audio stream only preferably to a ogg(opus/vorbis) file. _Note that this is basically the same as the alias `yta` but using `aria2c` for parallel download._ |

### Multimedia

| Function | Description |
|---|---|
| **`mpv_find`** _DIR [OPTION..] [-a MPV-ARG..]_ | Find any media file _(default: `.avi,.mkv,.mp4,.webm`, regex match can be changed)_ and play them using [mpv](https://mpv.io/). Allows sorting, fs tree recursion, list-only _(stdout, no playback)_, 'resuming' _(from a given index)_, and passing additional arguments to `mpv`. _Example: `mpv_find -r -s -R -a --no-resume-playback` will play all videos in the current, and all subfolders, in random order, ignoring mpv's `remsue-playback` function._ |
| **`to_mp3`** _INFILE [BITRATE [OUTFILE]]_ | Convert the given `INFILE` to mp3 using [ffmpeg](https://www.ffmpeg.org/) (`INFILE` may be any media file containing an audio stream processable by `ffmpeg`). A bitrate of `160k` and default output file name `{infilename}-audio.mp3` ise used if no specific options are provided. |
| **`to_opus`** _[-b BITRATE] INFILE [OPUSENC_ARG..]_ | Convert the given `INFILE` to opus using [opusenc](https://opus-codec.org) (infile may be any media file containing audio readable by `opusenc`). If no arguments are provided it uses the default `opusenc` vbr bitrate of _"64kbps per mono stream, 96kbps per coupled pair"_. The output file is `{infilename}.opus` _(currently not changeable)_. |
| **`ff_concat`** _OUTFILE INFILE.._ | Concatenates all `INFILEs` into `OUTFILE` using `ffmpeg`. |
| **`ff_crop`** _INFILE CROP [OUTFILE]_ | Crop `INFILE` video using the given `ffmpeg crop` format _(e.g. `640:352:0:64`)_ to the default outfil `{infilename}_CROP.{infileext}`. Requires imagemagick's `identify`. |

#### Images

| Function | Description |
|---|---|
| **`gif_delay`** _FILE_ | Returns all frame indexes of a gif `FILE` with their respective delays (speed). It is optionally possible to only list the delays `--delay-only` or to print only the _(rounded)_ average 1/100 sec delay `--average` of all frames. In the `--help` examples are provided on how to change the speed of a gif file using imagemagick's [convert](https://www.imagemagick.org/script/convert.php). Requires imagemagick's [identify](https://www.imagemagick.org/script/identify.php). |
| **`image_concat`** _FILE.._ | Concatenate images. _TODO: Needs further improvement._ |
| **`image_dimensions`** _FILE.._ | Returns dimensions given images in format: `{file-name}\|{w}\|{h}\|{w}x{h}\|{w*x}\|{min(w,h)}\|{max(w,h)}` (width, height, pixels, shortest/longest edge, etc.). The delimiter `|` can be changed. Requires imagemagick's `identify`. |

## Appendix

Icon pack by [Icons8](https://icons8.com/)
