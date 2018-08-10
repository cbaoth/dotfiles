# ~/.zsh/aliases: Common aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc bashrc shell-script

# -- GENERAL -----------------------------------------------------------------
alias cpi='cp -i'
alias mvi='mv -i'
alias vim='vim -N'
alias vi='vim -N'
alias grep='grep --color'
#alias sws='echo 4 > /proc/acpi/sleep'
alias ps-all='ps uxaw --cols 64000'
alias ps-forest='ps aw --forest --cols 64000'
alias killall9='pkill -9 -x'
alias xdefaults-reload='xrdb -load ~/.Xdefaults'
alias blank-screen-x='xset dpms force off'
#alias screen='export TERM=xterm-debian; screen'
#alias ssh-ignorekeychange='ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no'
alias rsync-merge='rsync -abviuzP'
alias rsync-local='rsync -vurpl'
alias rsync-local-del='rsync -vurpl --delete'
alias rsync-local-sizeonly='rsync -vurpl --size-only'

# -- SYSTEM ------------------------------------------------------------------
#alias mount-nas='mount | grep "/media/nas[12]" && echo "ERROR: At least one of /media/nas[12] is already mounted! Use remount-nas to force remount." >&2 || (mount /media/nas1; mount /media/nas2)'
#alias remount-nas='sudo umount -f -l /media/nas1; sudo umount -f -l /media/nas2; mount /media/nas1; mount /media/nas2'
#alias mount-yavin='mount | grep "/media/yavin" && echo "ERROR: /media/yavin is already mounted! Use remount-yavin to force remount." >&2 || mount /media/yavin'
#alias remount-yavin='sudo umount -f /media/yavin && mount /media/yavin || losof '
#alias remount-yavin='sudo umount -f -l /media/yavin; mount /media/yavin'
alias disk-uuid-list='sudo blkid -c /dev/null'

# -- SECURITY ----------------------------------------------------------------
alias authlog-ssh-ip+user='sudo grep "Failed" /var/log/auth.log | sed "s/.*for\( invalid user\)* \([^ ]*\) from \([^ ]*\) .*/\3\t\2/" | grep -v sudo: | sort | uniq -c'
alias authlog-ssh-ip-all='sudo zcat /var/log/auth.log.* | grep "Failed" | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v sudo: | sort | uniq -c | sort -r'
alias authlog-ssh-ip='sudo grep "Failed" /var/log/auth.log | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v sudo: | sort | uniq -c'
alias authlog-ssh-user='sudo grep "Failed" /var/log/auth.log | sed "s/.*for\( invalid user\)* \([^ ]*\) .*/\2/" | grep -v sudo: | sort | uniq -c'
alias authlog-proxy-ip='sudo cat /var/log/oops/access.log | egrep "TCP_DENIED/555.*NULL/AUTH_MOD" | sed "s/.* \(.*\) TCP_DENIED\/555.*NULL\/AUTH_MOD.*/\1/g" | grep -v sudo: | sort | uniq -c'
#alias authlog-ftp-ip='sudo grep "Failed" /var/log/auth.log | ...'
# sudo egrep "ftpd.*authentication failure" /var/log/auth.log | sed "s/.*ftpd:.*authentication failure.*rhost=\(([0-9]{1,3}\.){3}[0-9]{1,3}\).*/\1/g"

# -- MAIL --------------------------------------------------------------------
#alias fetchmail='fetchmail --mda "formail -s procmail" -f $HOME/.fetchmailrc'
alias fetchmail='fetchmail --mda "/usr/bin/spamc -e /usr/lib/dovecot/deliver" -f $HOME/.fetchmailrc --bad-header accept'

# -- DEV ---------------------------------------------------------------------
alias ocamli='ledit ocaml'
alias cmucl="rlwrap -b \$BREAK_CHARS cmucl"
alias python-profile="python -m cProfile -s time"

# -- NETWORK -----------------------------------------------------------------
alias wget="wget -U \"$UAGENT\""
alias axel="axel -U \"$UAGENT\" -a"
#alias epic='TERM=rxvt && su yasuo -c '\''epic4 yasuo irc.tu-ilmenau.de'\'''
#alias bx='bitchx -b -l .bitchxrc cbaoth irc.openprojects.net'
alias ftp="ftp -p"
#alias nfs_reshare='sudo pkill -HUP mountd'
#alias nfs_reshare='sudo service nfs-kernel-server restart; sudo service idmapd restart'
alias nfs-reexport='exportfs -ra'
alias proxy-set-tor="export http_proxy=http://localhost:8118"
alias wget-m="wget -U \"$UAGENT\" -m -k -K -E -np -N"
#alias vncsrv='tightvncserver -geometry 1024x768 -depth 24 :1'
#alias vncsrv16='tightvncserver -geometry 1024x768 -depth 16 :1'
#alias vncsrv-desktop='sudo x11vnc -display :0 -noxdamage -forever -usepw -ncache 10'
alias scp2='scp -P 8090'
alias ssh2='ssh -p 8090'
#alias fh='echo sudo pw:; sudo ssh -f -L 25:wien.fh-trier.de:25 weyera@dublin.fh-trier.de "sleep 86400"'
#alias ssh-tunnel-yavin-mysql='ssh -f yav.in -p 8090 -L 23306:127.0.0.1:3306 -N'
#alias ssh-tunnel-yavin-oracle='ssh -f yav.in -p 8090 -L 21521:127.0.0.1:1521 -N'
#alias ssh-tunnel-yavin-pgsql='ssh -f yav.in -p 8090 -L 25432:127.0.0.1:5432 -N'
#alias ssh-tunnel-yavin-vnc='ssh -f yav.in -p 8090 -L 25901:127.0.0.1:5901 -N'
#alias ssh-tunnel-yavin-proxy='ssh -f yav.in -p 8090 -L 23128:127.0.0.1:3128 -N'
#alias ssh-tunnel-hetznerbak='ssh -f yav.in -p 8090 -L 24021:u13368.your-backup.de:21 -N'
#alias vncap='vncviewer -autopass'
alias wake-saito='wakeonlan bc:5f:f4:9f:08:dc'
alias wake-motoko='wakeonlan 1C:1B:0D:E7:BE:B3'

# -- xorg --------------------------------------------------------------------
alias xerrorlog-tail='tail -f ~/.x11startlog ~/.xsession-errors ~/.xmonad/xmonad.errors'
alias xpropc="xprop | awk '/WM_CLASS/{print \$4\".\"\$3}' | sed 's/[,\"]//g'"
alias xprop-class='xprop WM_CLASS | cut -d\" -f2'
alias xprop-name='xprop WM_CLASS | cut -d\" -f4'
alias xprop-type='xprop _NET_WM_WINDOW_TYPE | cut -d_ -f10'
alias xprop-title='xprop WM_NAME | cut -d\" -f2'
alias xprop-role='xprop WM_WINDOW_ROLE | cut -d\" -f2'
alias xprop2="xprop|grep -E '^(WM_CLASS|WM_NAME|WM_WINDOW_ROLE)' | sed -r 's/^WM_(WINDOW_)?([^_(\s]+)(\([^)]*\))?/\2/g ; s/^NAME/TITLE/g ; s/\s*=\s*/\t/g ; s/CLASS\t\"(.*)\", \"(.*)\"/CLASS\t"\1"\nNAME\t"\2"/g'"

# -- multimedia --------------------------------------------------------------
#alias alevt='alevt -vbi /dev/v4l/vbi0 -parent 100'
#alias esound='esddsp -s togusa'
#alias mplayer-esd='mplayer -ao esd:togusa'
#alias mplayer-de='mplayer -vf pp=lb'
#alias mplayer-cache='mplayer -cache 15000'
#alias mplayer-cropdetect='mplayer -vo null -vf cropdetect'
#alias mplayer-webcam='mplayer tv:// -tv driver=v4l2:width=640:height=480:device=/dev/video0 -fps 15 -nosound'
#alias mplayer-slowcpu='mplayer -framedrop -ni -vfm ffmpeg -lavdopts lowres=1:fast:skiploopfilter=all'
#alias mencoder-dvd2mpeg2='echo mencoder -nocache dvd://[track] -mc 0 -ovc copy -oac copy -of mpeg -mpegopts format=dvd:tsaf -noskip -o [outfile]'
#alias mplayer-streamdump='mplayer -dumpstream -dumpfile'
#alias mplayer-tv='DISPLAY=:1 && mplayer -zoom -ao oss:/dev/dsp2'
alias mpv-nr='mpv --no-resume-playback'
# http://askubuntu.com/a/634655
alias yt="youtube-dl -f 'bestvideo[vcodec=vp9]+bestaudio[acodec=opus]/bestvideo[vcodec=vp9]+bestaudio[acodec=vorbis]/bestvideo[vcodec=vp8]+bestaudio[acodec=opus]/bestvideo[vcodec=vp8]+bestaudio[acodec=vorbis]/bestvideo[ext=webm]+bestaudio[ext=webm]/bestvideo[ext=webm]+bestaudio[ext=ogg]/best[ext=webm]/bestvideo+bestaudio/best' -o '%(title)s [%(id)s].%(ext)s'"
alias yta="youtube-dl -f 'bestaudio[acodec=opus]/bestaudio[acodec=vorbis]/best[ext=webm]/best[ext=ogg]/best' -x -o '%(title)s [%(id)s].ogg'"
#alias wall-video='pkill -9 xwinwrap; xwinwrap -ni -o 0.6 -fs -s -st -sp -ov -b -nf -- mplayer -wid WID -quiet -loop 0 -nosound'
#alias wall-video='pkill -9 xwinwrap; xwinwrap -ni -o 1 -fs -s -st -sp -ov -b -nf -- mplayer -wid WID -quiet -loop 0 -nosound'
#alias wall-glmatrix='xwinwrap -ov -fs -- /usr/lib/xscreensaver/glmatrix -root -window-id WID'
#alias mixer='rexima'
#alias mp3blaster='mp3blaster -a ~/playlist.lst -s=/dev/dsp2'
#alias record='sound-recorder -c 2 -s 44100 -b 16 -P -S 40:00 -f wav'
#alias tts='festival --tts'
#alias vdrsd="sudo vdr -Psc -P'softdevice -vo xv:'"
#alias kaffeine-channel-list="cat ~/.kde/share/apps/kaffeine/channels.dvb|sed 's/^\([^|]*\)|/\1 - /g;s/|.*//g'|grep -Ev '^\s*#'|sort"
#alias ape2mp3='for f in *.ape; do mac "$f" - -d | lame -m j -h --preset fast standard  - "${f%*.ape}.mp3"; done'
#alias ripit-vbr2='ripit --vbrmode new -b 0 -q 2 -o ./'
#alias mp3gain-track='mp3gain -k -d 93.5 -r'
#alias mp3gain-track='echo "ape2id3.py -v -f"; mp3gain -k -d 89 -r'
alias mp3gain-track='echo "ape2id3.py -v -f"; replaygain -r 89 --no-album'
#alias mp3gain-album='mp3gain -k -d 93.5 -a'
#alias mp3gain-album='echo "ape2id3.py -v -f"; mp3gain -k -d 89 -a'
alias mp3gain-album='echo "ape2id3.py -v -f"; replaygain -r 89'
alias vorbisgain-track='vorbisgain -s'
alias vorbisgain-album='vorbisgain -a -s'
alias pa-loopback-on='pactl load-module module-loopback latency_msec=10'
alias pa-loopback-off='pactl unload-module module-loopback'
# http://wiki.hydrogenaudio.org/index.php?title=Foobar2000:ID3_Tag_Mapping
alias id3-rec-clean='find -type f -iname "*.mp3" -exec eyeD3 --remove-comments --set-text-frame="TENC:" --set-text-frame="TOWN:" --set-url-frame="WPAY:" --set-url-frame="WORS:" --set-url-frame="WCOM:" --set-url-frame="WOAF:" --to-v2.4 {} \;'
alias id3-rec-to-utf8='find -type f -iname "*.mp3" -exec eyeD3 --set-encoding=utf8 --force-update {} \;'
alias id3-rec-remove-v1='find -type f -iname "*.mp3" -exec eyeD3 --remove-v1 {} \;'
alias mkvdts2ac3-default='mkvdts2ac3.sh --compress none -p 19 -d'
alias exif-date-rename='exiv2 -v -F -k -r %Y-%m-%d_%H%M%S_:basename:'
#alias dvdburn='growisofs -Z /dev/dvd -r -J'
#alias dvdburn='echo "growisofs -dvd-compat -Z /dev/dvd2=file.iso"'
#alias cdisoburn='sudo cdrecord dev=ATAPI:/dev/hdc driveropts=burnfree -dao'

# -- games -------------------------------------------------------------------
#alias wolfsp='wolfsp +setsv_cheats 1'
#alias cstrike-net='cd /data/WineX/Counter-Strike && winex cstrike.exe -console -noipx +connect'
#alias cstrike='cd /data/WineX/Counter-Strike && winex cstrike.exe -console -noipx'

# -- misc --------------------------------------------------------------------
alias cal-m='ncal -wM -m'
alias cal-y='ncal -ywM'
alias tr-tolower="tr '[A-Z]' '[a-z]'"
alias tr-toupper="tr '[a-z]' '[A-Z]'"
alias urlclean="sed 's/%3a/:/gi; s/%2f/\//gi; s/[?&].*//g; s/%26/&/gi; s/%3d/:/gi; s/%3f/?/gi'"
alias urlclean2="sed 's/%3a/:/gi; s/%2f/\//gi; s/%26/&/gi; s/%3d/:/gi; s/%3f/?/gi'"
alias usbsleep='sudo ~/bin/scsi-idle 900&'
alias rename-p2u="rename 's/\./_/g;s/_([^_]{1,5})$/.\$1/'"
alias rename-stripspecial="rename \"s/[^ \w()\[\]~&%#@.,+'-]/_/g\""
alias rename-stripspecial-rec="find . -type f -execdir rename \"s/^\.\///g;s/[^ \w()\[\]~&%#@.,+'-]/_/g;s/^/\.\//\" '{}' +"
alias rename-titlecase="rename 's/(^|[\s_-])([a-z])/\1\u\2/g'"
alias rename-camelcase="rename 's/(^|[\s_-])([a-z])/\u\2/g'"
alias sed-titlecase="sed -r 's/(^|[\s_-])([a-z])/\1\u\2/g'"
alias sed-camelcase="sed -r 's/(^|[\s_-])([a-z])/\u\2/g'"
alias rm-dupes='jdupes -dN'
alias rm-dupes-rec='jdupes -dNrO'
alias mysqlr='mysql -u root -p'
#alias opera-cache-big="echo ~/.opera/cache/sesn/ >&2; find ~/.opera/cache/sesn/ -maxdepth 1 -size +1M -printf '%CY-%Cm-%Cd %CH:%CM %f %s\n' |sort -r"
#alias urldecode="sed -r 's/%([0-9A-F][0-9A-F])/\\\\x\1/g' | while read l; do echo -e \"$l\"; done"
alias urldecode="sed -r 's/%([0-9A-F][0-9A-F])/\\\\\\\\x\1/g' | while read l; do echo -e \"\$l\"; done"
#alias audacious-playlist-urldecode="awk -F '[<>]' '/<location>/{print $3}'|sed 's/^file:\/\///g' |sed -r 's/%([0-9A-F][0-9A-F])/\\\\x\1/g' | xargs -n1 echo -e"
alias cat-utf16-to-utf8='iconv -f utf-16 -t utf-8'
alias cat-utf16-to-iso-8859-1='iconv -f utf-16 -t ISO-8859-1'
alias cat-utf8-to-iso-8859-1='iconv -f utf-8 -t ISO-8859-1'
alias nice-java='ionice -n 19 `pgrep java`; renice -n 19 -p `pgrep java`'
alias rpm-extract='rpm2cpio "$1" | cpio -ivd'