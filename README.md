<div id="header">

# My Dot-Files

<span id="author">Andreas Weyer</span>  
<span id="email" class="monospaced">\<<dev@cbaoth.de>\></span>  
<span id="revnumber">version 1.0,</span> <span id="revdate">2018-08-01</span>

<div id="toc">

<div id="toctitle">

Table of Contents

</div>

**JavaScript must be enabled in your browser to display the table of contents.**

</div>

</div>

<div id="content">

<div class="sect1">

## Summary

<div class="sectionbody">

<div class="paragraph">

My core configuration (dot) files, shell functions and utility scripts.

</div>

<div class="sect2">

### Repository Structure

<div class="listingblock">

<div class="content monospaced">

    dotfiles/        Actual dotfiles symlinked to $HOME (zsh, bash, vim, X11, etc.)
    bin/             User utility scripts (added to PATH via ~/bin/)
    system-scripts/  System/admin scripts (some require root)
    lib/             Shared shell libraries (commons.sh)
    tools/           Repo tooling: link.sh, fix-modelines.py, etc.
    docs/            Documentation and TODO
    _archive/        Archived scripts pending review (not in PATH)

</div>

</div>

<div class="ulist">

- <span class="monospaced">ZSH</span> is the leading shell.

- <span class="monospaced">Bash</span> configs exist for rare cases in which zsh is not available, they are not regularly maintained and usually outdated (consolidation is however a backlog topic).

- Portability is a core goal: the <span class="monospaced">dotfiles/</span> + <span class="monospaced">bin/</span> + <span class="monospaced">lib/</span> + <span class="monospaced">tools/link.sh</span> approach is intentionally dependency-free and should work without additional packages or root access.

- Restricted-host support matters: basic setup should still be usable on systems with only <span class="monospaced">bash</span> available (no <span class="monospaced">zsh</span>, no extra tooling).

- If not clearly <span class="monospaced">ZSH</span> related, all alias, function, etc. files should be <span class="monospaced">Bash</span> compatible *(but not always POSIX compliant)*.

- All files use the <span class="monospaced">" \\\\\\( .\*)?\$"</span> *(or <span class="monospaced">{{{ }}}</span> in short)* folding comment pattern *(use e.g. [emacs](https://www.emacswiki.org/emacs/FoldingMode), [VS Code](https://marketplace.visualstudio.com/items?itemName=zokugun.explicit-folding), [eclipse](https://stackoverflow.com/a/6947590))*

</div>

<div class="admonitionblock">

<table>
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="icon"><div class="title">
Note
</div></td>
<td class="content">See <a href="docs/TODO.md">docs/TODO.md</a> for the full task/improvement list.</td>
</tr>
</tbody>
</table>

</div>

</div>

<div class="sect2">

### Dot-files

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 33%" />
<col style="width: 33%" />
<col style="width: 33%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>File / Folder</p></td>
<td class="tableblock halign-left valign-top"><p>App</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zshenv[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> <a href="https://en.wikipedia.org/wiki/Z_shell">ZSH</a></p></td>
<td class="tableblock halign-left valign-top"><p>Common ZSH login shell environment (variables).</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zlogout[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> ZSH</p></td>
<td class="tableblock halign-left valign-top"><p>Common ZSH logout cleanup</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zshrc[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> ZSH</p></td>
<td class="tableblock halign-left valign-top"><p>Common ZSH config</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zsh.d/zshrc-freebsd.zsh[]</span><br />
<span class="monospaced">link:dotfiles/.zsh.d/zshrc-motoko.zsh[]</span><br />
<span class="monospaced">link:dotfiles/.zsh.d/zshrc-puppet.zsh[]</span><br />
<span class="monospaced">link:dotfiles/.zsh.d/zshrc-saito.zsh[]</span><br />
<span class="monospaced">link:dotfiles/.zsh.d/zshrc-11001001_org.zsh[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> ZSH</p></td>
<td class="tableblock halign-left valign-top"><p>OS, distribution, and/or host specific ZSH configs.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zsh.d/aliases.zsh[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> SH</p></td>
<td class="tableblock halign-left valign-top"><p>Common aliases</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zsh.d/aliases-freebsd.zsh[]</span><br />
<span class="monospaced">link:dotfiles/.zsh.d/aliases-linux.zsh[]</span><br />
<span class="monospaced">link:dotfiles/.zsh.d/aliases-linux_wsl.zsh[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> SH</p></td>
<td class="tableblock halign-left valign-top"><p>OS, distribution, and/or host specific aliases.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.zsh.d/functions/functions.zsh[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> SH</p></td>
<td class="tableblock halign-left valign-top"><p>Common shell functions.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.bashrc[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/material/50/000000/console.png" alt="https://png.icons8.com/material/50/000000/console.png" /> </span> <a href="https://en.wikipedia.org/wiki/Bash_(Unix_shell)">Bash</a></p></td>
<td class="tableblock halign-left valign-top"><p>Common Bash config <em>(rarely maintained)</em>.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.xsession[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" alt="https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" /> </span> X, Wayland</p></td>
<td class="tableblock halign-left valign-top"><p>Used by the display manager. Loads <span class="monospaced">.profile</span> and <span class="monospaced">.xinitrc</span>.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.xinitrc[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" alt="https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" /> </span> <a href="https://en.wikipedia.org/wiki/X_Window_System">X</a>, <a href="https://en.wikipedia.org/wiki/Wayland_(display_server_protocol)">Wayland</a></p></td>
<td class="tableblock halign-left valign-top"><p>Loaded from inside <span class="monospaced">.xsession</span> or when starting <span class="monospaced">xinit</span>.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.xsession.d/common[]</span><br />
<span class="monospaced">link:dotfiles/.xsession.d/default[]</span><br />
<span class="monospaced">link:dotfiles/.xsession.d/saito[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" alt="https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" /> </span> X, Wayland</p></td>
<td class="tableblock halign-left valign-top"><p>Common, default and host specific xsession initialization scripts loaded from inside <span class="monospaced">.xinitrc</span>. The <span class="monospaced">common</span> script is always loaded, the host specific script <span class="monospaced">.xsession.d/{hostname}</span> is loaded if existing, else the fallback <span class="monospaced">default</span> is loaded.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.Xresources[]</span><br />
<span class="monospaced">link:dotfiles/.Xresources.d/saito[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" alt="https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" /> </span> X, Wayland</p></td>
<td class="tableblock halign-left valign-top"><p>Common and host specific <a href="https://en.wikipedia.org/wiki/X_resources">X Resources</a>. The <span class="monospaced">.Xresources</span> file is loaded from inside <span class="monospaced">.xsession.d/common</span>. If a host specific <span class="monospaced">.Xresources.d/{hostname}</span> exists, it is merged into the common resources.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.imwheelrc[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" alt="https://png.icons8.com/ios-glyphs/50/000000/delete-sign.png" /> </span> <a href="http://imwheel.sourceforge.net/">IMWheel</a></p></td>
<td class="tableblock halign-left valign-top"><p>General and app specific mouse button/wheel mappings.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.vimrc[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/metro/50/000000/edit.png" alt="https://png.icons8.com/metro/50/000000/edit.png" /> </span> <a href="https://www.vim.org/">VIM</a></p></td>
<td class="tableblock halign-left valign-top"><p>VIM configuration</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.config/mpv/config[]</span><br />
<span class="monospaced">link:dotfiles/.config/mpv/input.conf[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/windows/50/000000/tv-show.png" alt="https://png.icons8.com/windows/50/000000/tv-show.png" /> </span> <a href="https://en.wikipedia.org/wiki/Mpv_(media_player)">mpv</a></p></td>
<td class="tableblock halign-left valign-top"><p>MPV configuration and key bindings.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">link:dotfiles/.mplayer/config[]</span><br />
<span class="monospaced">link:dotfiles/.mplayer/input.conf[]</span></p></td>
<td class="tableblock halign-left valign-top"><p><span class="image"> <img src="./adoc_assets/https://png.icons8.com/windows/50/000000/tv-show.png" alt="https://png.icons8.com/windows/50/000000/tv-show.png" /> </span> <a href="https://en.wikipedia.org/wiki/MPlayer">MPlayer</a></p></td>
<td class="tableblock halign-left valign-top"><p>Old MPlayer configuration and key bindings (switched to <span class="monospaced">mpv</span>).</p></td>
</tr>
</tbody>
</table>

<div class="sect3">

#### Host / OS specific zsh files

<div class="paragraph">

Custom host / OS specific ZSH configurations, aliases, functions, xsessions and xresources can be created and they are dynamically loaded in case of a match. This provides a convenient way to enrich the environment in case of a specific host / os without messing around with the core files.

</div>

<div class="paragraph">

This is the sequence in which zshrc’s, aliases and functions are loaded from within <span class="monospaced">.zshrc</span>:

</div>

<div class="listingblock">

<div class="content monospaced">

     # top of zshrc (always loaded)
     .zsh.d/functions.zsh
     .zsh.d/aliases.zsh

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

</div>

</div>

<div class="paragraph">

The special suffix <span class="monospaced">\_wsl</span> is used on [Windows Subsystem Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux), this allows the <span class="monospaced">-linux</span> files to be loaded in addition to (followed by) a WSL specific <span class="monospaced">-linux_wsl</span> file.

</div>

<div class="paragraph">

Some examples can be seen in the [\[Dot-files\]](#Dot-files) list above.

</div>

</div>

</div>

<div class="sect2">

### User Scripts (<span class="monospaced">bin/</span>)

|  |  |
|----|----|
| File | Description |
| <span class="monospaced">link:bin/media-keys\[\]</span> | Script to be used from within X (e.g. media key mappings) for media player control (play/pause, prev/next song) and pulse audio volume control (+/-5% and toggle mute) optionally showing an OSD. |
| <span class="monospaced">link:bin/apt-update\[\]</span> | Quietly update apt package indexes and store a timestamp. |
| <span class="monospaced">link:bin/exif-move-to-rating-dirs\[\]</span> | Organize image files into a directory hierarchy based on EXIF star ratings (0-5) and color labels. Features smart caching, directory mapping with regex patterns, and move/copy modes. See <span class="monospaced">link:bin/exif-move-to-rating-dirs.d/README.md\[\]</span> for full documentation. |
| <span class="monospaced">link:bin/smfetch\[\]</span> | Fetch RTMP and direct HTTP media links from broadcaster pages using wget and rtmpdump. |
| <span class="monospaced">link:bin/aria2c-d\[\]</span> | aria2c downloader wrapper. |
| <span class="monospaced">link:bin/diff-ini\[\]</span> | Diff INI files. |
| <span class="monospaced">link:bin/ff-copy\[\]</span> | Firefox copy utility. |
| <span class="monospaced">link:bin/ff-copy-mpv-bookmarks\[\]</span> | Copy MPV bookmarks from Firefox. |
| <span class="monospaced">link:bin/getbyext\[\]</span> | Get files by extension from a given URL using wget. |
| <span class="monospaced">link:bin/gif-cycle\[\]</span> | GIF frame cycling utility. |
| <span class="monospaced">link:bin/gif-delay\[\]</span> | GIF frame delay inspector/modifier. |
| <span class="monospaced">link:bin/git-fix-chmod\[\]</span> | Fix Git file permissions (chmod). |
| <span class="monospaced">link:bin/image-concat\[\]</span> | Concatenate images. |
| <span class="monospaced">link:bin/mpv-find\[\]</span> | Find media files and play with mpv. |
| <span class="monospaced">link:bin/netshare-bench\[\]</span> | Benchmark mounted network shares (NFS/CIFS/SMB) using <span class="monospaced">fio</span> and <span class="monospaced">iozone</span>. Tests sequential/random I/O, parallel photo-app reads (Lightroom/XnView MP workload), directory traversal (readdir/getattr RPC load), and network latency. Useful for comparing protocols and configuration tuning (LAN vs. Wi-Fi, server/client settings). All output is logged to a timestamped file alongside stdout. |
| <span class="monospaced">link:bin/rsync-parallel-backup\[\]</span> | Parallel rsync backup. |
| <span class="monospaced">link:bin/rsynclt\[\]</span> | rsync with limited throughput. |
| <span class="monospaced">link:bin/wget-p\[\]</span> | Parallel file fetching wrapper for wget. |
| <span class="monospaced">link:bin/while-read\[\]</span> | Execute a command for each line read from stdin. |
| <span class="monospaced">link:bin/xsuspend\[\]</span> | Suspend the X session. |

</div>

<div class="sect2">

### System / Admin Scripts (<span class="monospaced">system-scripts/</span>)

<div class="paragraph">

Scripts intended for system administrators or privileged operations (some require root).

</div>

|  |  |
|----|----|
| File | Description |
| <span class="monospaced">link:system-scripts/backup\[\]</span> | System backup script with exclusion list; supports full and incremental backups. |
| <span class="monospaced">link:system-scripts/bedtime-shutdown/bedtime-shutdown.sh\[\]</span> | Force system shutdown at a configured bedtime with grace periods, desktop notifications, and emergency overrides. See <span class="monospaced">link:system-scripts/bedtime-shutdown/README.md\[\]</span> for full documentation. |
| <span class="monospaced">link:system-scripts/dbbackup\[\]</span> | Backup script for MySQL and PostgreSQL databases. |
| <span class="monospaced">link:system-scripts/fail2ban-summary-mail\[\]</span> | Send a weekly Fail2Ban summary email from recent log data (intended for cron). |
| <span class="monospaced">link:system-scripts/nextcloud-maintenance\[\]</span> | Run routine Nextcloud maintenance tasks (DB indices, repair, integrity checks, app updates). Intended for cron with cronic. |
| <span class="monospaced">link:system-scripts/openvpn-client-cfg\[\]</span> | Generate OpenVPN client configuration bundles from server PKI assets; manage static IPs, CCD, and certificate revocation. |

</div>

<div class="sect2">

### Repository Tooling (<span class="monospaced">tools/</span>)

|  |  |
|----|----|
| File | Description |
| <span class="monospaced">link:tools/link.sh\[\]</span> | Symlink all files in <span class="monospaced">dotfiles/</span> to the user’s home directory. Missing directories are created in the process. Existing files that would be overwritten are moved to a backup location. |
| <span class="monospaced">link:tools/permissions.sh\[\]</span> | Update dotfile repo file permissions. |
| <span class="monospaced">link:tools/fix-modelines.py\[\]</span> | Normalize and deduplicate editor modelines (Emacs, Vim, VS Code, ShellCheck) across shell scripts. |
| <span class="monospaced">link:tools/fix-style.sh\[\]</span> | Apply style fixes to shell scripts. |
| README.md | This file. |

</div>

</div>

</div>

<div class="sect1">

## Shell Functions

<div class="sectionbody">

<div class="paragraph">

Some of the shell functions contained in <span class="monospaced">link:.zsh.d/functions.zsh\[\]</span> will be described in the following chapters.

</div>

<div class="sect2">

### Print

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_usg* _USAGE.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print a <em>Usage</em> text.<br />
<span class="image"> <img src="./adoc_assets/func_p_usg_1.png" alt="func_p_usg_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_msg* _MSG.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print an info message.<br />
<span class="image"> <img src="./adoc_assets/func_p_msg_1.png" alt="func_p_msg_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_war* MSG..</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print a warning message.<br />
<span class="image"> <img src="./adoc_assets/func_p_war_1.png" alt="func_p_war_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_err* MSG..</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print an error message <em>(stderr)</em>.<br />
<span class="image"> <img src="./adoc_assets/func_p_err_1.png" alt="func_p_err_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_dbg* _DBG_LVL SHOW_AT_LVL MSG.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print a debug msg if the given debug level is reached.<br />
<span class="image"> <img src="./adoc_assets/func_p_dbg_1.png" alt="func_p_dbg_1.png" /> </span><br />
A global debug level can be set via the <span class="monospaced">DBG_LVL</span> variable, in this case <span class="monospaced">p_dbg</span> will use the higher level <span class="monospaced">max(arg-level, global-level)</span>, meaning whichever is larger. As a result the global level can be used to globally raise, but never to lower the locally used debug level.<br />
<span class="image"> <img src="./adoc_assets/func_p_dbg_2.png" alt="func_p_dbg_2.png" /> </span><br />
So simply set the <span class="monospaced">DBG_LVL</span> argument to <span class="monospaced">0</span> if only the global level should be considered. <span class="image"> <img src="./adoc_assets/func_p_dbg_3.png" alt="func_p_dbg_3.png" /> </span><br />
<span class="image"> <img src="./adoc_assets/func_p_dbg_4.png" alt="func_p_dbg_4.png" /> </span><br />
</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_yes*</span><br />
<span class="monospaced">*p_no*</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print <em>yes</em> in green and <em>no</em> in red color.<br />
<span class="image"> <img src="./adoc_assets/func_p_yes-no_1.png" alt="func_p_yes-no_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*py_print* [-i import] PY_CODE..</span></p></td>
<td class="tableblock halign-left valign-top"><p>Route the given <span class="monospaced">code</span> through the <em>python3</em> <span class="monospaced">print</span> function.<br />
<span class="image"> <img src="./adoc_assets/func_py_print_1.png" alt="func_py_print_1.png" /> </span><br />
Use <span class="monospaced">-i</span> to import additional packages.<br />
<span class="image"> <img src="./adoc_assets/func_py_print_2.png" alt="func_py_print_2.png" /> </span></p></td>
</tr>
</tbody>
</table>

<div class="sect3">

#### Colors

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*p_colortable*</span></p></td>
<td class="tableblock halign-left valign-top"><p>Print 256 ansi color table.<br />
<span class="image"> <img src="./adoc_assets/func_p_colortable_1.png" alt="func_p_colortable_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*tputs* _STYLE.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Execute multiple <span class="monospaced">tput</span> commands in sequence. <em>Example:</em><br />
<span class="image"> <img src="./adoc_assets/func_tputs_1.png" alt="func_tputs_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*tp* _STYLE.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Set one or more tput colors and text effects by (short) name. All values are looked up from a map <em>(no need to run an external process)</em>.<br />
<span class="image"> <img src="./adoc_assets/func_tp_1.png" alt="func_tp_1.png" /> </span></p></td>
</tr>
</tbody>
</table>

</div>

</div>

<div class="sect2">

### Shell Functions

|  |  |
|----|----|
| Function | Description |
| <span class="monospaced">\*func_name\*</span> | Returns the current function’s name: <span class="monospaced">\${FUNCNAME\[0\]}</span> on <span class="monospaced">bash</span>, <span class="monospaced">\${funcstack\[1\]}</span> on <span class="monospaced">zsh</span>. |
| <span class="monospaced">\*func_caller\*</span> | Returns the function’s caller name *(if caller is a function)*: <span class="monospaced">\${FUNCNAME\[1\]}</span> on <span class="monospaced">bash</span>, <span class="monospaced">\${funcstack\[2\]}</span> on <span class="monospaced">zsh</span>. |

</div>

<div class="sect2">

### Predicates

|  |  |
|----|----|
| Function | Description |
| <span class="monospaced">\*is_zsh\*</span> | <span class="monospaced">true</span> if <span class="monospaced">zsh</span> session, else: <span class="monospaced">false</span> |
| <span class="monospaced">\*is_bash\*</span> | <span class="monospaced">true</span> if <span class="monospaced">bash</span> session, else: <span class="monospaced">false</span> |
| <span class="monospaced">\*is_su\*</span> | <span class="monospaced">true</span> if root (super user) session, else: <span class="monospaced">false</span> |
| <span class="monospaced">\*is_sudo\*</span> | <span class="monospaced">true</span> if in sudo mode, else: <span class="monospaced">false</span> |
| <span class="monospaced">\*is_sudo_cached\*</span> | <span class="monospaced">true</span> if sudo has cached credentials, else: <span class="monospaced">false</span> |
| <span class="monospaced">\*is_ssh\*</span> | <span class="monospaced">true</span> if ssh session, else: <span class="monospaced">false</span> |
| <span class="monospaced">\*is_int\* \_NUMBER..\_</span> | <span class="monospaced">true</span> if all given numbers are integers *(only digits)*, else: <span class="monospaced">false</span>. Ignores leading/trailing spaces, accepts leading +/- sign. |
| <span class="monospaced">\*is_decimal\* \_NUMBER..\_</span> | <span class="monospaced">true</span> if all given numbers are decimals *(only digits, MUST contain decimal separator *.*)*, else: <span class="monospaced">false</span>. Ignores leading/trailing spaces, accepts leading +/- sign. |
| <span class="monospaced">\*is_number\* \_NUMBER..\_</span> | <span class="monospaced">true</span> if all given numbers a either integers or decimals *(only digits, CAN contain decimal separator *.*)*, else: <span class="monospaced">false</span>. Ignores leading/trailing spaces, accepts leading +/- sign. |
| <span class="monospaced">\*is_positive\* \_NUMBER..\_</span> | <span class="monospaced">true</span> if all numbers do *NOT* start with a <span class="monospaced">-</span>, else: <span class="monospaced">false</span>. Ignores leading/trailing spaces. *Note: This doesn’t check if the arguments are numbers (it simply checks for a leading <span class="monospaced">-</span>, should always be used in combination with <span class="monospaced">is_int/decimal/number</span>).* |

</div>

<div class="sect2">

### Queries

|  |  |
|----|----|
| Function | Description |
| <span class="monospaced">\*q_yesno\* \_QUESTION\_</span> | Print the <span class="monospaced">QUESTION</span> and asks for (y)es/(n)o input. Returns true if answer is <span class="monospaced">yes</span>, else: <span class="monospaced">false</span>. |
| <span class="monospaced">\*q_overwrite\* \_FILE\_</span> | Checks if the given file exists, if so asks wether to overwrite it via (y)es/(n)o input. Returns <span class="monospaced">true</span> only if <span class="monospaced">FILE</span> exists AND if answer is <span class="monospaced">yes</span>, else: <span class="monospaced">false</span>. |

</div>

<div class="sect2">

### Arrays

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*join_by* _DELIMITER ARRAY.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Join array / arguments using the given delimiter. On ZSH consider using <span class="monospaced">${(j:del:)array}</span>.<br />
<span class="image"> <img src="./adoc_assets/func_join_by_1.png" alt="func_join_by_1.png" /> </span><br />
Note that on <span class="monospaced">zsh</span> the same can be achived via <span class="monospaced">${(j:.:)ip}</span>. <span class="image"> <img src="./adoc_assets/func_join_by_2.png" alt="func_join_by_2.png" /> </span></p></td>
</tr>
</tbody>
</table>

</div>

<div class="sect2">

### Command

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*cmd_delay* _DELAY COMMAND.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Execute a command with a delay (using <span class="monospaced">sleep</span> format, e.g. <span class="monospaced">3m</span> for 3 minutes). <em>Sleep timer example:</em> <span class="monospaced">cmd_delay 45m systemctl suspend</span>.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*while_read* _COMMAND.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Monitor input <em>(read lines)</em> and execute command in foreground using input as command argument. <em>Example: <span class="monospaced">while_read wget</span> to download all entered urls.</em></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*while_read_bg* _COMMAND.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Monitor input <em>(read lines)</em> and execute command in background <em>(job)</em> using input as command argument. <em>Example: <span class="monospaced">while_read_bg wget</span> to download all entered urls.</em></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*while_read_xclip* [OPTION..] _COMMAND.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Monitor X clipboard and execute command using clipboard content as command argument. <em>Example:</em><br />
<span class="monospaced">while_read_xclip -b -m '^https?://.*' tee -a links.txt "&lt;&lt;&lt;'{}'" | wget -nv -c -i -</span><br />
<em>to append all http(s) URLs read vom clipboard to a file named <span class="monospaced">links.txt</span> and download them using wget.</em></p></td>
</tr>
</tbody>
</table>

</div>

<div class="sect2">

### Math

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*calc* _EXPR.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>A simple wrapper for <span class="monospaced">dc</span>. Set the decimal scale using the <span class="monospaced">-s</span> option (default: 0).<br />
<span class="image"> <img src="./adoc_assets/func_calc_1.png" alt="func_calc_1.png" /> </span></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*py_calc* _PY_CODE.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Routes <span class="monospaced">PY_CODE</span> through python3’s <span class="monospaced">print</span> function with <span class="monospaced">from math import *</span>.<br />
<span class="image"> <img src="./adoc_assets/func_py_calc_1.png" alt="func_py_calc_1.png" /> </span><br />
Apart from this additional import it’s basically the same as <span class="monospaced">py_print</span> so this is also possible <em>(even without the math. prefix)</em>:<br />
<span class="image"> <img src="./adoc_assets/func_py_calc_2.png" alt="func_py_calc_2.png" /> </span></p></td>
</tr>
</tbody>
</table>

</div>

<div class="sect2">

### Internet

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*ytp* _URL.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Download media files using <span class="monospaced">https://rg3.github.io/youtube-dl/[youtube-dl]</span> and <span class="monospaced">https://aria2.github.io/[aria2c]</span> <em>(4 concurrent downloads, 4 threads per host)</em> using the same output file names provide by <span class="monospaced">youtube-dl</span> using the following pattern: <span class="monospaced">%(title)s [%(id)s].%(ext)s</span>.<br />
<em>Note that this is basically the same as the alias <span class="monospaced">yt</span> but using <span class="monospaced">aria2c</span> for parallel download instead of the integrated, single threaded downloader. When multiple formats are available, all <span class="monospaced">yt*</span> commands will favor free codecs starting with the highest quality streams _(rough codec/format priority: vp9/opus/vp8/vorbis/webm/ogg/*)</em>.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*ytap* _URL.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>The same as <span class="monospaced">ytp</span> above, but downloads audio stream only preferably to a ogg(opus/vorbis) file. <em>Note that this is basically the same as the alias <span class="monospaced">yta</span> but using <span class="monospaced">aria2c</span> for parallel download.</em></p></td>
</tr>
</tbody>
</table>

</div>

<div class="sect2">

### Multimedia

|  |  |
|----|----|
| Function | Description |
| <span class="monospaced">\*mpv_find\* \_DIR \[OPTION..\] \[-a MPV-ARG..\]\_</span> | Find any media file *(default: <span class="monospaced">.avi,.mkv,.mp4,.webm</span>, regex match can be changed)* and play them using <span class="monospaced">https://mpv.io/\[mpv\]</span>. Allows sorting, fs tree recursion, list-only *(stdout, no playback)*, *resuming* *(from a given index)*, and passing additional arguments to <span class="monospaced">mpv</span>. *Example: <span class="monospaced">mpv_find -r -s -R -a --no-resume-playback</span> will play all videos in the current, and all subfolders, in random order, ignoring mpv’s <span class="monospaced">remsue-playback</span> function.* |
| <span class="monospaced">\*to_mp3\* \_INFILE \[BITRATE \[OUTFILE\]\]\_</span> | Convert the given <span class="monospaced">INFILE</span> to mp3 using <span class="monospaced">https://www.ffmpeg.org/\[ffmpeg\]</span> (<span class="monospaced">INFILE</span> may be any media file containing an audio stream processable by <span class="monospaced">ffmpeg</span>). A bitrate of <span class="monospaced">160k</span> and default output file name <span class="monospaced">{infilename}-audio.mp3</span> ise used if no specific options are provided. |
| <span class="monospaced">\*to_opus\* \_\[-b BITRATE\] INFILE \[OPUSENC_ARG..\]\_</span> | Convert the given <span class="monospaced">INFILE</span> to opus using <span class="monospaced">https://opus-codec.org\[opusenc\]</span> (infile may be any media file containing audio readable by <span class="monospaced">opusenc</span>). If no arguments are provided it uses the default <span class="monospaced">opusenc</span> vbr bitrate of *"64kbps per mono stream, 96kbps per coupled pair". The output file is <span class="monospaced">{infilename}.opus</span> \_(currently not changeable)*. |
| <span class="monospaced">\*ff_concat\* \_OUTFILE INFILE..\_</span> | Concatenates all <span class="monospaced">INFILEs</span> into <span class="monospaced">OUTFILE</span> using <span class="monospaced">ffmpeg</span>. |
| <span class="monospaced">\*ff_crop\* \_INFILE CROP \[OUTFILE\]\_</span> | Crop <span class="monospaced">INFILE</span> video using the given <span class="monospaced">ffmpeg crop</span> format *(e.g. <span class="monospaced">640:352:0:64</span>)* to the default outfil <span class="monospaced">{infilename}\_CROP.{infileext}</span>. Requires imagemagick’s <span class="monospaced">identify</span>. |

<div class="sect3">

#### Images

<table class="tableblock frame-all grid-all" style="
width:100%;
">
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<tbody>
<tr>
<td class="tableblock halign-left valign-top"><p>Function</p></td>
<td class="tableblock halign-left valign-top"><p>Description</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*gif_delay* _FILE_</span></p></td>
<td class="tableblock halign-left valign-top"><p>Returns all frame indexes of a gif <span class="monospaced">FILE</span> with their respective delays (speed). It is optionally possible to only list the delays <span class="monospaced">--delay-only</span> or to print only the <em>(rounded)</em> average 1/100 sec delay <span class="monospaced">--average</span> of all frames. In the <span class="monospaced">--help</span> examples are provided on how to change the speed of a gif file using imagemagick’s <span class="monospaced">https://www.imagemagick.org/script/convert.php[convert]</span>. Requires imagemagick’s <span class="monospaced">https://www.imagemagick.org/script/identify.php[identify]</span>.</p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*image_concat* _FILE.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Concatenate images.<br />
<em>TODO: Needs further improvement.</em></p></td>
</tr>
<tr>
<td class="tableblock halign-left valign-top"><p><span class="monospaced">*image_dimensions* _FILE.._</span></p></td>
<td class="tableblock halign-left valign-top"><p>Returns dimensions given images in format: <span class="monospaced">{file-name}&amp;#124;{w}&amp;#124;{h}&amp;#124;{w}x{h}&amp;#124;{w*x}&amp;#124;{min(w,h)}&amp;#124;{max(w,h)}</span> (width, height, pixels, shortest/longest edge, etc.). The delimiter <span class="monospaced">&amp;#124;</span> can be changed. Requires imagemagick’s <span class="monospaced">identify</span>.</p></td>
</tr>
</tbody>
</table>

</div>

</div>

</div>

</div>

<div class="sect1">

## Appendix

<div class="sectionbody">

<div class="paragraph">

Icon pack by [Icons8](https://icons8.com/)

</div>

</div>

</div>

</div>

<div id="footnotes">

------------------------------------------------------------------------

</div>

<div id="footer">

<div id="footer-text">

Version 1.0  
Last updated 2026-05-31 17:23:05 CEST

</div>

</div>
