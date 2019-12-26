# ~/.zsh/functions.zsh: Common functions
# all functions are written in way that they work on both, zsh and bash

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script functions

# include commons lib (if not already the case)
if ! command -v "cl::cmd_p" >& /dev/null; then
  for f in {$_SCRIPT_PATH/,$_SCRIPT_PATH/lib,$HOME/lib}/commons.sh; do
    if [[ -f "$f" ]]; then
      source "$f"
      break
    fi
  done
fi
if ! command -v "cl::cmd_p" >& /dev/null; then
  printf "commons lib not found, unable to import functions.zsh, returning ..\n" >&2
  return 1
fi

# {{{ find files
# ----------------------------------------------------------------------------
find_greater_than () {
  [[ -z "$2" ]] || ! cl::is_int $1 && \
    cl::p_usg "find_greater_than <max> <dir>...\nmax (bytes)" && return 1
  min="$1"; shift
  for dir in "$@"; do
    find "$dir" -printf "%p %s\n"|while read l; do
      ((${l##*[ ]} == $min)) && echo $l;
    done
  done
}


find_between () {
  [[ -z "$3" ]] || ! cl::is_int $1 $2 && \
    cl::p_usg "$(cl::func_name) MIN MAX DIR...\nMIN|MAX (bytes)" && \
    return 1
  min="$1"; max="$2"; shift 2
  for dir in "$@"; do
    find "$dir" -printf "%p %s\n"|while read l; do
      size="${l##*[ ]}"
      (($size > $min)) && (($size < $max)) && echo $l;
    done
  done
}


find_less_than () {
  [[ -z "$2" ]] || ! cl::is_int $1 && \
    cl::p_usg "$(cl::func_name) MAX DIR..\nMAX (bytes)" && \
    return 1
  max="$1"; shift
  for dir in "$@"; do
    find "$dir" -printf "%p %s\n"|while read l; do
      ((${l##*[ ]} < $max)) && echo $l;
    done
  done
}


# OK - find and remove all empty files
rm_empty_files () {
  if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    cl::p_usg "$(cl::func_name) [-r] DIR"
    return 1
  fi
  local -a maxdepth=(-maxdepth 1)
  if [[ "${1:-}" = "-r" ]]; then
    unset maxdepth
    shift
  fi
  local -a dirs=(.)
  [[ -n "${1:-}" ]] && dirs="$@"
  for dir in "${dirs[@]}"; do
    find "$dir" ${maxdepth:+${maxdepth[@]}} -type f -empty -delete
  done
}


# OK - find and remove all empty dirs
rm_empty_dirs () {
  if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    cl::p_usg "$(cl::func_name) [DIR]"
    return 0
  fi
  local -a maxdepth=(-maxdepth 1)
  if [[ "${1:-}" = "-r" ]]; then
    unset maxdepth
    shift
  fi
  local -a dirs=(.)
  [[ -n "${1:-}" ]] && dirs="$@"
  for dir in "${dirs[@]}"; do
    find "$dir" ${maxdepth:+${maxdepth[@]}} -depth -type d -empty -delete
  done
}


# OK - find and remove all .thumbnails dirs
rm_thumbnail_dirs () {
  if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    cl::p_usg "$(cl::func_name) [DIR]"
    return 0
  fi
  local -a maxdepth=(-maxdepth 1)
  if [[ "${1:-}" = "-r" ]]; then
    unset maxdepth
    shift
  fi
  local -a dirs=(.)
  [[ -n "${1:-}" ]] && dirs="$@"
  for dir in "${dirs[@]}"; do
    find "$dir" ${maxdepth:+${maxdepth[@]}} -type d -iname ".thumbnails" -exec rm -rf {} \;
  done
}

# ----------------------------------------------------------------------------
# }}} find files
# {{{ string
# ----------------------------------------------------------------------------
# OK - repeat string
string_repeat() {
  if [[ -z "${2:-}" ]]; then
    cl::p_usg "$(cl::func_name) COUNT STRING" && \
    return 1
  fi
  ! cl::is_int $1 && { cl::p_err "$1 is not an integer"; return 1; }
  #echo $(printf "%0$1d" | sed "s/0/$2/g")
  #printf "$2.0s" {1..$1}
  awk 'BEGIN{$'$1'=OFS="'$2'";print}'
}


# OK - prefix every line from the input file with a line counter, restart after empty line
line_counter_prefix_sublines() {
  if [[ -z "${1:-}" ]]; then
    cl::p_usg "$(cl::func_name) INFILE" && \
    return 1
  fi
  local infile="$1"
  local i=0
  cat "${infile}" | while read l; do
    if [[ -z "$l" ]]; then
      i=0
      continue
    else
      i=$((i+1))
    fi
    echo "$i: $l"
  done
}

# ----------------------------------------------------------------------------
# }}}
# {{{ math
# ----------------------------------------------------------------------------
# OK - send expression to dc (simple wrapper)
calc() {
  local HELP USG="$(cl::func_name) [OPTION..] EXPR.."
  ! IFS='' read -r -d '' HELP <<EOF
Usage: $USG

Options:
  -s|--scale X     decimal scale (default: 0)
EOF
  [[ -z "${1:-}" ]] && { cl::p_usg "$USG"; return 1; }
  local scale
  while [[ -n "$1" ]]; do
    case $1 in
      -s|--scale)
        [[ -z "$2" ]] && { cl::p_err "missing value for argument -s"; return 1; }
        cl::is_int $2 || { cl::p_err "value [$2] for argument -s must be an integer"; return 1; }
        scale="scale="$2";"; shift 2
        ;;
      -h|--help)
        printf "%s" "$HELP"; return 0
        ;;
      -*)
        cl::p_err "unknown argument: $1"; return 1
        ;;
      *)
        break
        ;;
    esac
  done
  bc <<<"${scale}$@"
}


# OK - send expression to python print with imported math package
py_calc() {
  if [[ "$1" =~ ^(-i|--import)$ ]]; then
    [[ -z "$2" ]] && cl::p_err "missing value for argument -i" && return 1
    local _py_import="$2"; shift 2
  fi
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) [-i IMPORT] PY_CODE.." && return 1
  python3<<<"from math import *
${_py_import+import ${_py_import}}
print($@)"
}


rnd () {
   printf "%s" "$((($RANDOM % $1)+1))"; }
hex2dec() { echo "ibase=16; $(echo ${1##0x} | tr '[a-f]' '[A-F]')" | bc; }
# TODO: fix overflow (eg. 125 @ 2 digits)
zerofill () { #inserts leading zeros (number, digits)
  [[ -z "$2" ]] && \
    cl::p_usg "zerofill value digits" && return 1
  ! cl::is_int $1 || ! cl::is_int $2 && cl::p_err "$i is not an integer" && return 1
    echo $(printf "%0$2d" $1)
}
calcSum() {
  line=""; arg=""
  while true; do
    read line
    case $line in
      q|Q|=)
        break
        ;;
      *)
        if cl::is_number $line; then
          arg="$arg"+"$line"
        else
          echo "not a number"
        fi
      ;;
    esac
  done
  arg="$(echo "$arg" | sed 's/+-/-/g')"
  echo "$arg"
  echo "result: "$(pycalc "$arg")
}

# ----------------------------------------------------------------------------
# }}} math
# {{{ network
# ----------------------------------------------------------------------------
# OK - multi-threaded (8 jobs) wget mirror
wget_mm () {
  if [[ -z "${1:-}" ]]; then
    cl::p_usg "$(cl::func_name) URL"
    printf "mirror URL (no parent) using wget running 8 background jobs\n"
    return 1
  fi
  # FIXME use GNU parallel instead
  for i in {1..8}; do
    printf "job(%s): wget -U '%s' -m -k -K -E -np -N '%s' &" "$i" "$UAGENT" "$1"
    wget -U "$UAGENT" -m -k -K -E -np -N "$1" &
  done
}


# OK - download URL using wget using output file name based on URL
wget_d () {
  if [[ -z "${1:-}" ]]; then
    cl::p_usg "$(cl::func_name) URL [wget-args]"
    cat <<EOF

Download URL (using wget) into a dynamic output file, named based on the URL.

Default wget args:
  -U "\${UAGENT}"
  --referer "{base path of given URL}"
  -O "{out file name based on URL}"

Example:
  $(cl::func_name) https://foo.bar/resource/1.html -c
  -> wget -U "\${UAGENT}"
          --referer "https://foo.bar/resource"
          -O "foo.bar+resource+1.html"
          https://foo.bar/resource/1.html
          -c
EOF
    return 1
  fi
  local url="$1"
  shift
  local ref="$(dirname "${url}")"
  local outfile="$(sed -E 's/^(\w+):\/\///g;s/\/+$//g;s/\//+/g' <<<"${url}")"
  wget -U "${UAGENT}" --referer "${ref}" -O "${outfile}" "$@" "${url}"
}


# attempt to re-download a file that was downloaded using wget_d
wget_d_rev () {
  if [[ -z "${1:-}" ]]; then
    cl::p_usg "$(cl::func_name) FILE.."
    printf "attempt to re-download a file that was downloaded using wget_d\n"
    return 1
  fi
  for f in "$@"; do
    local url="http://$(tr '+' '/' <<<"$f")"
    local ref="$(dirname "$url")"
    cl::p_msg "Trying to re-download: $url"
    wget -U "$UAGENT" --referer "$ref" "$url" -O "$f"
    [[ $? == 0 ]] && continue
    cl::p_err "Attempt to re-donwload via http failed, trying https ..."
    url="${url/http:/https:}"
    wget -U "$UAGENT" --referer "$ref" "$url" -O "$f"
  done
}


# OK - open ssh tunnel
ssh_tunnel () {
  if [[ -z "${2:-}" ]]; then
    cl::p_usg "$(cl::func_name) [USER@]HOST[:PORT] LOCALPORT [REMOTEPORT]"
    return 1
  fi
  local host="${${1#*@}%:*}"
  local user
  [[ "$1" = *@* ]] && user="${1%@*}"
  local port
  [[ "$1" = *:* ]] && port="${1#*:}"
  local lp="$2"
  local rp="${3:-$lp}"
  (($lp < 1024)) && ! cl::is_su && local SUDO="sudo"
  $SUDO ssh -f "${host}" ${port:+-p ${port}} ${user:+-l $user} -L ${lp}:127.0.0.1:${rp} -N
}


# OK - generate a random mac address
mac_generate() {
  printf "52:54:%s" "$(dd if=/dev/urandom count=1 2>/dev/null \
                       | md5sum \
                       | sed 's/^\(..\)\(..\)\(..\)\(..\).*$/\1:\2:\3:\4/')"
}

# ----------------------------------------------------------------------------
# }}}
# {{{ file renaming
# OK - if rename is not available, provide a simple replace implementation
if ! cl::cmd_p rename >& /dev/null; then
  # OK - simple rename implemenation (if rename command not available)
  rename () {
    cl::p_war "rename command not available, using simplified implementation"
    cl::cmd_p zmv && cl::p_war "consider using available zmv command instead"
    if (( $# < 2 )); then
      cat <<EOF
Usage: $(cl::func_name) PATTERN FILE..

Example: $(cl::func_name) 's/ /_/g' *.txt
EOF
      return 1
    fi
    local pattern="$1"
    shift
    for f in "$@"; do
      target="$(sed -E $pattern <<<"$f")"
      mv -i "$f" "$target"
    done
  }
  #
fi

# OK - list all selected files matching the given mime type
ls_mime () {
  if [[ -z "${2:-}" ]]; then
    cat <<!
Usage: $(cl::func_name) MIME-TYPE FILE..

Lists all FILE.. matching the given MIME-TYPE.

EXAMPLES:
  # list all *.bin files of type text/html
  $(cl::func_name) text/html *.bin
  # list all *.txt files matching the given (regex) list of mime types
  $(cl::func_name) "(text/html|application/xml|application/x-empty)" *.txt
!
    return 1
  fi
  #[ -z "$(echo $1|grep -E '\w\/\w')" ]] &&\
  #  echo "wrong mimetype format \'$1\'" && return 1
  local mtype="$1"
  shift
  file -h -i "$@" \
    | grep -e "$mtype" \
    | sed 's/: .*//g'
}

#
rename_prefix_counter() {
  if [[ -z "$1" ]]; then
    cat <<EOF
Usage: $(cl::func_name) FILE.."
Example: $(cl::func_name) intro.ogg interlude.ogg final_song.ogg
         -> 01_intro.ogg 02_interlude.ogg 03_final_song.ogg
EOF
    return 1
  fi
  i=1
  while [[ -n "$1" ]]; do
    local prefix="$(zerofill $i 2)"
    local target="${prefix}_$1"
     if [[ ! -e "$target" ]]; then
      cl::p_msg "$target"
      mv "$1" "$target"
    else
      cl::p_err "skipping '$target', file exists !"
    fi
      [[ "$?" -ne 0 ]] && cl::p_err "something went wrong" #&& return 1
    i="$(($i+1))"
    shift
  done
}
#

rename_prefix_modtime () {
  [[ -n "$2" ]] && cl::p_err "rename-prefix-modtime to many parameters" &&\
    cl::p_usg "rename-prefix-modtime file" && return 2
  [[ -z "$1" ]] && cl::p_usg "rename-prefix-modtime file" && return 2
  local ls="$(which -a ls|grep -v alias|head -n 1)"
  local target="$($ls -l --time-style '+%Y-%m-%d@%H.%M' \"$1\"|cut -d \  -f 6) $1"
  echo renaming \"$1\" to \"$target\"
  mv "$1" "$target"
}
#

rename_prefix_exiftime () {
  [[ -n "$2" ]] && cl::p_err "rename-prefix-exif-time to many parameters" &&\
    cl::p_usg "rename-prefix-exif-time file" && return 2
  [[ -z "$1" ]] && cl::p_usg "rename-prefix-exif-time file" && return 2
  local target="$(exif -t 0x9003 \"$1\"|grep Value|sed 's/\s*Value:\s*\([0-9]*\):\([0-9]*\):\([0-9]*\) \([0-9]*\):\([0-9]*\):\([0-9]*\).*/\1-\2-\3@\4.\5.\6/g') $1"
  echo renaming \"$1\" to \"$target\"
  mv "$1" "$target"
}
#export rename_prefix_exiftime

# OK - add file count (content) to folder name (pre-/suffix)
rename_dir_filecount () {
  local skip="" digits=0 rec=0 reccount=0 countall=0 verbose=0 test=0 prefix=0 clean=0 cleanonly=0 hidden=0
  while [[ -n "$1" ]]; do
    case $1 in
      -r)
        rec=1; shift
        ;;
      -rc)
        reccount=1; shift
        ;;
      -a)
        countall=1; shift
        ;;
      -d)
        [[ -z "$2" ]] && cl::p_err "digit count missing for argument $1" && return 2
        if ! cl::is_int $2 || ! cl::is_positive $2; then
          cl::p_err "digit count is not a positive int value: $2" && return 2
        fi
        digits="$2"; shift 2
        ;;
      -s)
        [[ -z "$2" ]] && cl::p_err "pattern missing for argument $1" && return 2
        skip="$2"; shift 2
        ;;
      -v)
        verbose=1; shift
        ;;
      -n)
        test=1; shift
        ;;
      -p)
        (($hidden == 1)) && cl::p_err "-p and -i are mutually exclusive" && return 2
        prefix=1; shift
        ;;
      -i)
        (($prefix == 1)) && cl::p_err "-p and -i are mutually exclusive" && return 2
        hidden=1; shift
        ;;
      -c)
        (($cleanonly == 1)) && cl::p_err "-co and -c are mutually exclusive" && return 2
        clean=1; shift
        ;;
      -co)
        (($clean == 1)) && cl::p_err "-co and -c are mutually exclusive" && return 2
        cleanonly=1; shift
        ;;
      -*)
        cl::p_err "unknown arg: $1" && return 2
        ;;
      *)
        break
        ;;
    esac
  done
  if [[ -z "$1" ]]; then
    cat <<!
$(cl::func_name) [OPTION..] DIR

$(cl::fx b)Options:$(cl::fx r)
  -r        recursive processing mode (rename each sub directory too)
  -rc       recursive count mode (include in count, else direct content only)
  -d N      number of digits (add leading zeros, default: none)
  -a        includ directories in count (default: just count files)
  -s REGEX  skip directories matching the regex pattern (full path matched)

  -p        instead of adding suffix " ([count])" add prefix "([count]) "
  -i        include hidden (dot) directories

  -c        clean potentially exiting prefix / suffix first (caution!)
  -co       like -c but only cleans, doesn't add new prefix /suffix (caution!)

  -n        test mode (no act), just print move commands
  -v        verbose mode

$(cl::fx b)Example:$(cl::fx r)
  # add file count suffix (x) to to ~/foo and its sup-directories
  # don't reame directories staring with underscore _
  $(cl::fx b)$(cl::func_name) -r -s '/_[^/]*$' ~/foo/$(cl::fx r)

  $(cl::fx blue)~/foo/bar/1.txt
  ~/foo/bar/2.txt
  ~/foo/bar/3.txt
  ~/foo/x.txt$(cl::fx r)

  # results in

  $(cl::fx blue)~/foo (1)/bar (3)$(cl::fx r)
!
     return 2
  fi
  for d in "$@"; do
    if [[ ! -d "${d}" ]]; then
      cl::p_err "dir not found [$1], skipping ..."
      continue
    fi
    local dir="${d%%/}" # remove trailing / if existing
    local -a type
    [[ "$countall" -ne 1 ]] && type=(-type f)
    local -a maxdepth
    [[ "$rec" -ne 1 ]] && maxdepth=(-maxdepth 0)
    local -a maxdepthcount
    [[ $reccount -ne 1 ]] && maxdepthcount=(-maxdepth 1)
    local -a nothidden
    [[ "$hidden" -ne 1 ]] && nothidden=(-not -name ".*")

    find "$dir" $maxdepth -depth -type d $nothidden \
      | while read d; do
          [[ "$d" = "." ]] && continue
          if [[ -n "$skip" ]] && echo "$d" | grep -E "$skip" > /dev/null; then
            (($verbose == 1)) && cl::p_msg "skipping (regex): $d"
            continue
          fi
          # count files in dir and rename dir (possible old count is removed)
          count="$(find "$d" $maxdepthcount $type | wc -l)"
          [[ "$digits" -ne 0 ]] && count="$(zerofill $count $digits)"
          (($countall == 1)) && count="$((count-1))" # -1 to exclude current dir .
          if (($cleanonly == 1)); then # clean only
            (($prefix == 1)) \
              && dest="$(sed -E 's/((^\.?)?\/)?(\([0-9]+\)\s+)+([^/]+)$/\1\4/' <<<"$d")" \
              || dest="$(sed -E 's/(\s+\([0-9]+\))+$//' <<<"$d")"
          elif (($clean == 1)); then # clean and add
            (($prefix == 1)) \
              && dest="$(sed -E "s/((^\.?)?\/)?(\([0-9]+\)\s+)+([^/]+)$/\1\($count\) \4/" <<<"$d")" \
              || dest="$(sed -E 's/(\s+\([0-9]*\))_$//' <<<"$d") ($count)"
          else # simply add, don't clean first
            (($prefix == 1)) \
              && dest="$(sed -E "s/((^\.?)?\/)?([^/]+)$/\1\($count\) \3/" <<<"$d")" \
              || dest="$d ($count)"
          fi
          if [[ "$d" = "$dest" ]]; then
            (($verbose == 1)) && cl::p_msg "skipping (same name): $d"
          elif [[ -d "$dest" ]]; then
            (($verbose == 1)) && cl::p_msg "skipping (exists): $d"
          else
            (($verbose == 1)) && cl::p_msg "moving: '$d' -> '$dest'"
            if (($test == 1)); then
              echo "mv \"$d\" \"$dest\""
            else
              mv "$d" "$dest"
            fi
          fi
        done
  done
}
#export rename_dir_filecount

url2fname () { echo $1 | sed 's/^http:\/\///g;s/\//+/g'; }
export url2fname
# ----------------------------------------------------------------------------
# }}} renaming
# {{{ moving
# ----------------------------------------------------------------------------
merge_dir () {
  local verbose=false wild=false noact=false ignore_case
  while [[ "${1:-}" == -* ]]; do
    case ${1} in
       -v)
           verbose=true
           shift
           ;;
       -w)
           wild=true
           shift
           ;;
       -n)
           noact=true
           shift
           ;;
       -i)
           ignore_case=1
           shift
           ;;
       *)
           break
           ;;
    esac
  done
  if [[ -z "${1:-}" ]]; then
    cl::p_usg "merge_dir [OPTION..] target [source..]

merge content of all source directories into the given target directory
  with -w to match *target* (actually base-directory/*target*)

OPTIONS:
  -w match *target*, only if no sources are provided
  -i match target case insensitive, only if no sources are provided
     note, this will set the extendedglob option
  -n for no-act (print commands only) and
  -v for verbose mode"
    return 1
  fi
  tar="$1"
  shift
  if [[ -n "${1:-}" ]]; then
    src=("$@")
  elif ${wild}; then
    setopt extendedglob
    if [[ $tar = */* ]]; then
      src=(${ignore_case:+(#i)}"${tar%/*}"/*"${tar##*/}"*/)
    else
      src=(${ignore_case:+(#i)}*"${tar}"*/)
    fi
  else
    setopt extendedglob
    src=(${ignore_case:+(#i)}"${tar}"*/)
  fi
  local dir_created=false
  ${noact} || mkdir -p "${tar}" && dir_created=true
  if [[ ! ${noact} && ! -d "${tar}" ]]; then
    cl::p_err "unabe to create target directory [${tar}]"
    return 2
  fi

  ${verbose} && cl::p_msg "target: ${tar}"
  ${verbose} && cl::p_msg "source(s): ${src[@]}"
  setopt extendedglob
  for d in "${src[@]}"; do
    ${verbose} && cl::p_msg "processing: ${d}"
    if [[ ! -d "${d}" ]]; then
      ${verbose} && cl::p_msg "skipping, not a directory: ${d}"
      continue
    fi
    if [[ "${d}" -ef "${tar}" ]]; then
      cl::p_war "skipping, source same as target: ${d}"
      continue
    fi
    find "${d}" -mindepth 1 -maxdepth 1 -exec $($noact && printf echo) /bin/mv -t "${tar}" -- {} +
    ${noact} || rmdir "${d}"
  done
  ${dir_created} && rmdir --ignore-fail-on-non-empty "${tar}" 2>/dev/null
}
#

merge_dirs_same_first_word() {
  local pattern='^[^%#_+-]+'
  local noact=false
  if [[ "${1:-}" = "-n" ]]; then
    noact=true
    shift
  fi
  if [[ -z "${1:-}" ]]; then
    cl::p_usg "merge_dirs_same_first_word [-n] DIR.."
    echo "merges all DIR.. having the same first word (actually only: ${pattern})"
    echo "only local dircs allowed (no / or ../)"
    echo "example: merge_dirs_same_first_word -n [a-z]*/"
  fi
  ls -d "$@" | grep -vE '^(\.\.|\/)' | sed -r 's/^\.\///g' | grep -Eo "$pattern" \
    | tr '/' '\0' | sort | uniq -c \
    | while read c d; do
        if (($c > 1)) && [[ -n "$d" ]]; then
          if ${noact}; then
            cl::p_msg "merge_dir \"$d\""
          else
            merge_dir "$d"
          fi
        fi
      done
}
#
# ----------------------------------------------------------------------------
# }}}
# {{{ textfile manipulation
# ----------------------------------------------------------------------------
kill_trailing_spaces () {
  if [[ -z "$1" ]]; then
    cl::p_usg "kill_trailing_spaces <file>"
    return 1
  fi
  local file="$1"
  if [[ ! -w "$file" ]]; then
    cl::p_err "file [$file] does not exist or is not writable"
    return 1
  fi

  perl -pi -e 's/[ ]\+$//g' "$file"
}
#
# ----------------------------------------------------------------------------
# }}}
# ----------------------------------------------------------------------------
# {{{ delevopment
# https://web.archive.org/web/20130116195128/http://bogdan.org.ua/2011/03/28/how-to-truncate-git-history-sample-script-included.html
git_truncate () {
  if [[ -z "$1" ]]; then
    cl::p_usg "git-truncate hash-id/tag [message]"
    return 1
  fi
  id="$1"
  shift

  msg="Truncated history"
  [[ -n "$1" ]] && msg="$@"
  cl::p_msg "The history prior to the hash-id/tag [$id] will be DELETED !!!"
  if ! cl::q_yesno "> Delete history?"; then
    return 0
  fi
  git checkout --orphan temp "$id" \
    && git commit --allow-empty -m "$msg" \
    && git rebase --onto temp "$id" master \
    && git branch -D temp
}
#
# }}}
# ----------------------------------------------------------------------------
# {{{ multimedia
# ----------------------------------------------------------------------------
# youtube-dl download using aria2 (4 concurrent downloades, 4 threads per host)
# use output filenames generated by youtube-dl
ytp() {
  [[ -z "$1" ]] && cl::p_usgc "url.." && return 1
  youtube-dl -f 'bestvideo[vcodec=vp9]+bestaudio[acodec=opus]
                 /bestvideo[vcodec=vp9]+bestaudio[acodec=vorbis]
                 /bestvideo[vcodec=vp8]+bestaudio[acodec=opus]
                 /bestvideo[vcodec=vp8]+bestaudio[acodec=vorbis]
                 /bestvideo[ext=webm]+bestaudio[ext=webm]
                 /bestvideo[ext=webm]+bestaudio[ext=ogg]
                 /best[ext=webm]/bestvideo+bestaudio/best' \
             -i -o '%(title)s [%(id)s].%(ext)s' \
             -g --get-filename "${@}" \
    | sed '$!N;s/\n/\n  out=/' \
    | aria2c -U "$UAGENT" -c -x4 -j4 -i -
}


# same as ytp but download audio only
ytap() {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) url.." && return 1
  youtube-dl -f 'bestaudio[acodec=opus]/bestaudio[acodec=vorbis]
                 /best[ext=webm]/best[ext=ogg]/best' \
             -i -x -o '%(title)s [%(id)s].ogg' \
             -g --get-filename "${@}" \
    | sed '$!N;s/\n/\n  out=/' \
    | aria2c -U "$UAGENT" -c -x4 -j4 -i -
}


# convert infile to mp3 audio file
to_mp3 () {
  local brate=160k
  [[ -z "$1" ]] && \
    cl::p_usg "$(cl::func_name) INFILE [BITRATE [OUTFILE]]\n  bitrate   audio bitrate in bit/s (default: ${brate})\n  requirements: avconv (ffmpeg), libavcodec-*" && return 1
  local in="$1"
  [[ -n "$2" ]] && brate="$2"
  local out
  if [[ -n "$3" ]]; then
    out="$3"
  else
    out="$(basename $in)"
    out="$(dirname $in)/${out%.*}-audio.mp3"
  fi
  ffmpeg -i "$in" -ab "$brate" "$out"
}


id3_cover_replace () {
  [[ -z "$1" ]] && \
    cl::p_usg "$(cl::func_name) [-c COVER] FILE..\n  removes all images from id3 and adds\n  the selected image (default: folder.jpg) as cover" && return 1
  local cover="folder.jpg"
  [[ "$1" = "-c" ]] && \
    cover="$2" && shift 2
  [[ ! -f "$cover" ]] && cl::p_err "cover '$cover' not found" && return 1
  cl::p_msg "removing image files from id3"
  eyeD3 --remove-images "$@"
  cl::p_msg "adding new cover"
  eyeD3 --add-image="$cover":FRONT_COVER:"$(basename $cover)" "$@"
}


mpc2mp3 () {
  [[ -z "$1" ]] && \
    cl::p_usg "$(cl::func_name) [-n|--normalize] FILE.." && return 1
  local normal=0
  [[ "$1" = "-n" ]] || [[ "$1" = "--normalize" ]] && \
    normal=1 && shift
  for f in "$@"; do
    #mpcdec "$f" --wav - |oggenc - -q 5 -o "${f%.*}".ogg
    tmp="/tmp/mpc2ogg_$(date +%s%N).wav"
    cl::p_msg "$(basename $f)"
    if (($normal == 1)); then
      mpcdec "$f" "$tmp"
      normalize "$tmp"
      lame --vbr-new -V 2 "$tmp" $(basename "${f%.*}").mp3
      rm -f /tmp/mpc2ogg_*.wav
    else
      mpcdec "$f" - | lame --vbr-new -V 2 - "$(basename ${f%.*}).mp3"
    fi
  done
}


ppc2ogg () {
  [[ -z "$1" ]] && \
    cl::p_usg "$(cl::func_name) [-n|--normalize] FILE.." && return 1
  local normal=0
  [[ "$1" = "-n" ]] || [[ "$1" = "--normalize" ]] && \
    normal=1 && shift
  for f in "$@"; do
    #mpcdec "$f" --wav - |oggenc - -q 5 -o "${f%.*}".ogg
    tmp="/tmp/mpc2ogg_$(date +%s%N).wav"
    mpcdec "$f" "$tmp"
    (($normal == 1)) && normalize "$tmp"
    oggenc "$tmp" -q 5 -o $(basename "${f%.*}").ogg
    rm -f /tmp/mpc2ogg_*.wav
  done
}


ts2ps() {
  [[ -z "$1" ]] &&\
    cl::p_usg "$(cl::func_name) INFILE [OUTFILE]" &&\
    return -1
  local outfile
  if [[ -n "$2" ]]; then
    outfile="$2"
  else
    outfile="${1%.*}".m2p
  fi
  cl::q_overwrite "$outfile" &&\
    mencoder -ovc copy -oac copy -of mpeg -o "$outfile" "$1"
}


mplayer-wavdump () {
    local outfile="./$(basename $1).wav"
    #mplayer -ao pcm:file="$outfile" "$1"
    #mplayer -noconfig all -vo null -vc dummy -ao pcm:fast:file="$outfile" "$1"
    mplayer -noconfig all -benchmark -vo null -vc null -ao pcm:fast:file="$outfile" "$1"
}
mplayer-audiodump() {
    local outfile="./$(basename $1).adump"
    mplayer -noconfig all -dumpaudio -dumpfile "$outfile" "$1"
}
mplayer-videodump() {
    local outfile="./$(basename $1).vdump"
    mencoder -ovc copy -nosound -o "$outfile" "$1"
}
mplayer-delete-me() {
  local -r DELETE_ME=/tmp/mplayer-delete-me
  local -r LOG_FILE="${DELETE_ME}.log"
  if [[ ! -f "$DELETE_ME" ]]; then
    cl::p_err "file not found: $DELETE_ME, nothing to delete"
    return -1
  fi
  uniq < "$DELETE_ME" | while read f; do
    if [[ ! -f "$f" ]]; then
      cl::p_err "file not found: $f" \
        | tee -a "$LOG_FILE"
      continue
    fi
    cl::p_msg "deleting: $f" | tee -a "$LOG_FILE"
    rm "$f"
  done
  rm "$DELETE_ME"
}
mplayer-bookmark-split() {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) FILE" && return -1
  local infile="$1"
  [[ ! -f "$infile" ]] && cl::p_err "file not found: $infile" && return -1
  local bmfile="${1}.bookmarks"
  [[ ! -f "$bmfile" ]] && cl::p_err "no bookmark file found: $bmfile" && return -1
  local -a cmd
  local cmd=(ffmpeg) pos="" pos_prev="0" idx=0 outfile=""
  while read b; do
    cl::p_msg "processing bookmark: $b"
    #bmtype="$(cut -d \| -f 1 <<< $b)"
    #case "$bmtype" in
    #   begin)
    idx="$((idx+1))"
    [[ "$pos" != "" ]] && pos_prev="$pos"
    pos="$(cut -d \| -f 3 <<<'$b')"
    outfile="$(file-suffix '${infile}' '_bmsplit_$(zerofill ${idx} 3)')"
    cmd=(ffmpeg)
    cmd+=(-ss $pos_prev -i "$infile" -to $pos)
    cmd+=(-sn -vcodec copy -acodec copy -y "$outfile")
    cl::p_msg "$cmd[@]"
    ${cmd[@]}
  done < "$bmfile"
  if (($idx == 0)); then
    cl::p_warn "nothing to do ..."
    return
  fi
  idx="$((idx+1))"
  outfile="$(file-suffix '${infile}' '_bmsplit_$(zerofill ${idx} 3)')"
  cmd=(ffmpeg)
  cmd+=(-ss $pos -i "$infile")
  cmd+=(-sn -vcodec copy -acodec copy -y "$outfile")
  cl::p_msg "$cmd[@]"
  #sed -E 's/ (-sn|-ss)/\n \1/g' <<< ${cmd[@]}
  ${cmd[@]}
}

# fixes index in avi files using mencoder
fixidx() {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) INFILE [OUTFILE]" && return -1
  local infile="$1"
  [[ ! -f "$infile" ]] && cl::p_err "file not found" && return -1
  [[ -n "$2" ]] && outfile="$2" || outfile="$(file-suffix "$infile" _FIXED)"
  cl::p_msg "output file: $outfile"
  mencoder -forceidx -oac copy -ovc copy "$infile" -o "$outfile"
}

# convert file to opus using opusenc
# TODO add argument for output filename
to_opus() {
  local opusenc_args=()
  if [[ "$1" = "-b" ]]; then
    opusenc_args+=(-b)
    [[ -z "$2" ]] && cl::p_err "no bitrate provided" && return -1
    ! cl::is_int $2 && cl::p_err "bitrate must be a valid integer"
    opusenc_args+=($2)
    shift 2
  fi
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) [-b BITRATE] INFILE [OPUSENC_ARG..]" \
    && return -1
  local infile="$1"; shift
  [[ ! -f "$infile" ]] && cl::p_err "no such file: $infile" && return -1
  local outfile="${infile%.*}.opus"
  cl::p_msg "outfile: $outfile"
  opusenc "${opusenc_args[@]}" "$@" "$infile" "$outfile"
}

# concatenate media files using ffmpeg
ff_concat() {
  [[ -z "$2" ]] &&\
    cl::p_usg "$(cl::func_name) OUTFILE INFILE.." &&\
    return -1
  local outfile="$1"; shift
  #mencoder -ovc copy -oac copy -o "$outfile" "$@"
  ffmpeg -f concat -safe 0 -i <(for f in "$@"; do echo "file '$PWD/$f'"; done) -c copy "$outfile"
}

# crop video using ffmpeg
ff_crop() {
  [[ -z "$2" ]] &&
    cl::p_usg "$(cl::func_name) INFILE CROP [OUTFILE]\nexample: $(cl::func_name) video.webm 640:352:0:64" &&
    return -1
  local infile="$1"; crop="$2"
  [[ -f "$infile" ]] && cl::p_err "file not found: $infile" && return -1
  [[ -n "$3" ]] && outfile="$3" || outfile="$(file-suffix "$infile" _CROP)"
  cl::p_msg "output file: $outfile"
  ffmpeg -i "$infile" -vf crop="$crop" -codec:a copy "$outfile"
}

wmv2avi() {
  [[ -z "$1" ]] &&\
    cl::p_usg "$(cl::func_name) INFILE [OUTFILE]" &&\
    return -1
  local outfile
  if [[ -n "$2" ]]; then
    outfile="$2"
  else
    outfile="${1%.*}".avi
  fi
  cl::q_overwrite "$outfile" &&\
    mencoder -ofps 23.976 -ovc lavc -oac copy -o "$outfile" "$1"
}
mma-timidity () {
  mma "$1" && timidity "${1%.*}.mid"
}
mediathek () {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) ASX_URL" && return 1
  curl -s "$1" | grep mms: | cut -d \" -f 2 | while read url; do
    local outfile="${url##*/}"
    cl::p_msg "dumping '$url' -> '$outfile'"
    mplayer -dumpstream -dumpfile "$outfile" "$url"
  done
}

# list dimensions of all given image files
image_dimensions () {
  # usage + help
  local -r USG="$(cl::func_name) [OPTION..] FILE.."
  local HELP
  ! IFS='' read -r -d '' HELP <<EOF
Usage: $USG

$(cl::fx b)Options:$(cl::fx r)
  -d|--delimiter D    output column delimiter (default: '|')

$(cl::fx b)Output Format:$(cl::fx r)
  $(cl::fx blue)index:   1          |2   |3  |4       |5     |6         |7
  fields:  {file-name}|{w} |{h}|{w}x{h} |{w*x} |{min(w,h)}|{max(w,h)}
  example: test.jpg   |1024|768|1024x768|786432|768       |1024$(cl::fx r)

$(cl::fx b)Examples:$(cl::fx r)
  # list all dimension information for *.jpg, use delimiter ; instead of |
  $(cl::fx green)$(cl::func_name) -d \\; *.jpg$(cl::fx r)

  # get only the WxH dimension string (4) for test.jpg
  $(cl::fx green)$(cl::func_name) test.jpg | cut -d \\| -f 4$(cl::fx r)

  # get only the file names (1) from *.jpg where dimension (6) <= 1000
  $(cl::fx green)$(cl::func_name) *.jpg \\
    | awk -F '|' 'BEGIN {OFS="|"} { if (\$6 <= 1000) print \$1 }'$(cl::fx r)

  # read all dimensional values from *.jpg into variables and "do some stuff"
  $(cl::fx green)$(cl::func_name) *.jpg \\
    | while IFS='|' read -r f w h dim pixels min max; do
        printf "%s - w:%s x h:%s -> %s\n" "\$f" "\$w" "\$h" "\$pixels"
      done$(cl::fx r)
EOF
  readonly HELP
  # parse arguments
  [[ -z "$1" ]] && cl::p_usg "$USG" && return 1
  local d='|'
  while [[ -n "$1" ]]; do
    case $1 in
      -d|--delimiter)
        [[ -z "$2" ]] && { cl::p_err "missing value for argument $1"; return 1; }
        d="$2"; shift 2
        ;;
      -h|--help)
        printf "%s" "$HELP"; return 0
        ;;
      -*)
        cl::p_err "unknown argument: $1"; return 1
        ;;
      *)
        break
        ;;
    esac
  done
  # process files
  for f in "$@"; do
    [[ ! -f "$f" ]] && cl::p_err "file not found [$f], skipping ..." && continue
    local ident="$(identify -format '%w|%h\n' $f)"
    IFS='|' read -r w h <<<"$ident"
    [[ -z "$w" ]] || [[ -z "$h" ]] && cl::p_err "unable to identify the dimensions of [$f], skipping ..." && continue
    cl::is_int $w || { cl::p_err "width w = [$w] doesn't seemt to be an integer" && return 1; }
    cl::is_int $h || { cl::p_err "height h = [$h] doesn't seemt to be an integer" && return 1; }
    local dim="$wx$h"
    local pixels="$(($w*$h))"
    local min="$(($w>$h?$h:$w))"
    local max="$(($w<$h?$h:$w))"
    [[ -n "$min_comp" ]] && [[ ! "$min" -"$min_comp" "$filter_min_pixel" ]] && continue
    printf "%s%s%s%s%s%s%s%s%s%s%s%s%s\n" "$f" "$d" "$w" "$d" "$h" "$d" \
           "$dim" "$d" "$pixels" "$d" "$min" "$d" "$max"
  done
}

rm_smallimage () {
  # usage + help
  local -r USG="$(cl::func_name) [OPTION..]"
  local HELP
  ! IFS='' read -r -d '' HELP <<EOF
  test
foo
  bar
EOF
  readonly HELP
  print "$help"
}

# foo() {
#   if [[ -z "$1" ]]; then
#     cat <<!
# $(cl::func_name) [-t] file..

# removes all given images with a pixel count < 160000 (example: < 400x400)

# args:
#   -t    test mode, don't delete anything
#   -p X  min pixel count (default: 160000)
# !
#     return 1
#   fi
#   [[ "$1" = "-t" ]] && test=1 || test=0
#   for f in "$@"; do
#     [[ ! -f "$f" ]] && continue
#     local px="$(image-pixelcount "$f")" # 2>/dev/null
#     [[ "$?" -ne 0 ]] && cl::p_err "size can't be identified: $f" && continue
#     if (($px < 160000)); then
#       if (($test == 1)); then
#         echo "too small: \"$f\""
#       else
#         cl::p_msg "removing: $px $f"
#         rm "$f"
#       fi
#     fi
#   done
# }
exif-set-author () {
  [[ -z "$2" ]] && cl::p_usg "$(cl::func_name) AUTHOR FILE.." && return 1
  if ! command -v exiv2 >& /dev/null; then
     cl::p_err "exiv2 must be installed"
     return 1
  fi
  local author="$1" && shift
  exiv2 mo -v -k \
    -M "set Exif.Image.Artist Ascii $author" \
    -M "set Xmp.dc.creator XmpSeq $author" \
    "$@"
    #-M "set Iptc.Application2.Byline String $author" \
}
flv2mp4 () {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) flvfile" && return 1
  local infile="$1"
  local outfile="${infile%.*}.mp4"
  cl::p_msg "converting '$infile' to '$outfile'"
  ffmpeg -i "$infile" -vcodec copy -acodec copy "$outfile"
}
fixaspectratio () {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) INFILE [OUTFILE [ratio]]" && return 1
  local infile="$1"
  [[ -n "$2" ]] && outfile="$2" || outfile="$(file-suffix "$1" _FIX)"
  [[ -n "$3" ]] && ratio="$3" || ratio="16:9"
  ffmpeg -i "$infile" -aspect "$ratio" -c copy "$outfile"
}

video-split-screen () {
  [[ -z "$3" ]] && cl::p_usg "$(cl::func_name) INFILE1 INFILE2 OUTFILE [v|h]" && return 1
  local infile1="$1"; shift
  local infile2="$1"; shift
  local outfile="$1"; shift
  local filter='[0:v]pad=iw*2:ih[int];[int][1:v]overlay=W/2:0[vid]'
  [[ -n "$1" ]] && case $1 in
    v)
       shift; # default
    ;;
    h)
       filter='[0:v]pad=iw:ih*2[int];[int][1:v]overlay=0:H/2[vid]'
       shift
    ;;
    *)
       m_err "unknown arg: $1, only v (vertical, default) and h (horizontal) mode are supported"
       return 1
    ;;
  esac
  echo ffmpeg -i \"$infile1\" -i \"$infile2\" -filter_complex "'$filter'" -map "'[vid]'" \"$outfile\"
  ffmpeg -i "$infile1" -i "$infile2" -filter_complex "$filter" -map '[vid]' "$outfile"
}

gifslice-opt() {
  [[ -z "$3" ]] && cl::p_usg "$(cl::func_name) INFILE [OUTFILE|-ao] OPTION..." && return 1
  local infile="$1"
  shift
  local -a outfile
  # arg 2 is -ao (auto outfile) then generate output file name by appending timestamp
  if [[ "$1" = "-ao" ]]; then
    outfile=(-o "$(cl::p_file_with_suffix _slice_$(date +%s) "${infile}")")
    shift
  # arg 2 is not an option? then it must be the outfile name
  elif [[ "$1" =~ ^[^-] ]]; then
    outfile=(-o "$1")
    shift
  fi
  gifslice -U "${infile}" "$@" -O2 "${outfile[@]:-}"
}
# ----------------------------------------------------------------------------
# }}} multimeda
# ----------------------------------------------------------------------------
# }}} crypto
# {{{ system
# ----------------------------------------------------------------------------
pnice () {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) PROC_NAME_REGEX" && return 1
  local p="$(ps ax -T | grep -iE "$@" | grep -vE '0:00.*grep')"
  (($#p <= 0)) && cl::p_err "no matching processes/threads found" && return 1
  cl::p_msg "niceness of the following processes/threads will be changed:"
  echo "$p"
  if cl::q_yesno "> process?"; then
    echo $p|cut -d \  -f 2|xargs sudo renice -n 19 -p
  fi
}
pniceio () {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) PROC_NAME_REGEX" && return 1
  local p="$(ps ax -T | grep -iE "$@" | grep -vE '0:00.*grep')"
  (($#p <= 0)) && cl::p_err "no matching processes/threads found" && return 1
  cl::p_msg "niceness of the following processes/threads will be changed:"
  echo "$p"
  if cl::q_yesno "> process?"; then
    echo $p|cut -d \  -f 2|xargs sudo ionice -c 3 -p
  fi
}
pniceloop () {
  [[ -z "$1" ]] && cl::p_usg "$(cl::func_name) PROC_NAME_REGEX" && return 1
  while true; do
    local p="$(ps ax -T | grep -iE "$@" | grep -vE '0:00.*grep')"
    (($#p <= 0)) && cl::p_err "no matching processes/threads found" && return 1
    cl::p_msg "niceness of the following processes/threads will be changed:"
    echo "$p"
  #if  cl::q_yesno "> process"; then
    echo $p|cut -d \  -f 2|xargs sudo renice -n 19 -p
    echo $p|cut -d \  -f 2|xargs sudo ionice -c 3 -p
  #fi
    sleep 10 # repeat every 10 sec
  done
}
iso-quickmount () {
  if [[ -z "$1" ]]; then
    cat <<!
Usage: $(cl::func_name) [ISO_FILE [DIR]|DIR]

examples:
  # quick mount iso file to default dir (will be created)
  # dir name pattern: filename without extension, same base dir as given iso
  $(cl::func_name) freebsd.iso

  # quick mount iso to specific dir (will be created)
  $(cl::func_name) ~/isos/freebsd.iso ./freebsd/

  # umount quickmount iso dir (and remove dir again)
  $(cl::func_name) freebsd/
!
    return 1
  fi
  local mountdir
  if [[ -d "$1" ]]; then
    mountdir="$1"
    if sudo umount "$MOUNTDIR"; then
      cl::p_msg "Successfully un-mounted: $MOUNTDIR"
      if ! sudo rmdir "$MOUNTDIR" 2>/dev/null; then
        cl::p_war "Unable to remove mount dir!" #: $MOUNTDIR"
        #return 1
      fi
      return 0
    else
      cl::p_err "Unable to un-mount given dir!" #: $MOUNTDIR"
      return 1
    fi
  elif [[ -f "$1" ]]; then
    local isofile="$1"
    if ! file --mime-type "$ISOFILE" | grep 'iso9660' 2>&1 >/dev/null; then
      cl::p_err "Given argument doesn't seem to be a valid iso image: $ISOFILE"
      return 1
    fi
    mountdir="${1%.*}"
    [[ -n "$2" ]] && mountdir="$2" # \
    #  && [[ -d "$2" ]] && cl::p_err "Given mount dir does already exist '$2'!" \
    #  && return 1
    if ! sudo mkdir "$mountdir" 2>&1 \
        | grep -v ': File exists'; then
      if [[ ! -d "$mountdir" ]]; then
        cl::p_err "Unable to create dir: $mountdir"
        return 1
      fi
    fi
    if rsp="$(sudo mount -r -o loop -t iso9660 "$isofile" "$mountdir" 2>&1)"; then
      cl::p_msg "Successfully mounted iso file to: $mountdir"
      return 0
    else
      am=0
      echo $rsp | grep 'according to mtab.*is already mounted'  >/dev/null \
        && msg=" The file seems to be mounted already!" && am=1
      cl::p_err "Unable to mount iso file!$msg" #: $isofile"
      if ! sudo rmdir "$mountdir" 2>/dev/null && (( "$am" != 1 )); then
        cl::p_war "Unable to remove mount dir: $mountdir"
        #return 1
      fi
      return 1
    fi
  else
    cl::p_err "Given argument neither seems to be an iso file nor a directory: $1"
    return 1
  fi
  return 0
}
# ----------------------------------------------------------------------------
# }}}
# {{{ security & crypto
# ----------------------------------------------------------------------------
create-crypto-containe () { # file, size, fstype [, files]
  # get args and check a few things
  local file="$1" # container file
  #[ -f "$file" ]] && cl::p_err "file '$file' does exist" && return 1
  local dir="$(dirname "$1")"; shift # dirname
  [[ ! -d "$dir" ]] && cl::p_err "no such dir '$dir'" && return 1
  local size="$1"; shift # container size (mb)
  ! cl::is_int $size && cl::p_err "no valid size '$size'" && return 1
  local blocks="$(($size*1024))" # container size (blocks)
  local space="$(df "$dir" | grep -v Filesystem | awk '{print $3}')"
  (($space < $blocks)) && \
    cl::p_err "not enough space on target drive" && return 1
  local fs="$1"; shift # container filesystem
  local bs=1024 # set block size

  # check superuser status
  local sudo=""
  ! cl::is_su && sudo="sudo" && \
    cl::p_msg "you might be asked to enter your sudo password"
  #seed="$(head -c 15 /dev/random | uuencode -m - | head -2 | tail -1)"
  #muli key mode !!! CBC
  if [[ "$fs" = 'iso9660' ]]; then
    (($size < 1000)) && bs=512 # set block size
    [[ -z "$@" ]] && cl::p_err "missing files" && return 1
    #cl::p_msg "creating empty container"
    #$sudo dd if=/dev/zero of="$file" bs="$bs" count="$blocks"
    #cl::p_msg "creating random data"
    #$sudo shred -n 1 -v "$file"
    #cl::p_msg "please enter passphrase"
    #$sudo losetup -e AES256 -k 256 /dev/loop2 "$file"
    #cl::p_msg "building fs"
    #$sudo mkisofs -r -o /dev/loop2 "$@"
    #$sudo losetup -d /dev/loop2
    cl::p_msg "creating empty container"
    dd if=/dev/zero of="$file" bs="$bs" count=16 &&\
    cl::p_msg "generating symmetric key (entropy !)" &&\
    head -c 2880 /dev/random | uuencode -m - | head -n 65 | tail -n 64 \
    | gpg --symmetric -a | dd of="$file" conv=notrunc &&\
    cl::p_msg "creating crypted isofs (this may take a while)" &&\
    mkisofs -r "$@" | aespipe -e aes256 -w 5 -T \
      -K "$file" -O 16 >> "$file" &&\
    cl::p_msg "try: growisofs -dvd-compat -Z /dev/dvd="$file""
  elif [[ "$fs" = 'ext2' ]]; then
    cl::p_msg "creating empty container"
    $sudo dd if=/dev/zero of="$file" bs="$bs" count="$blocks" &&\
    cl::p_msg "creating random data" &&\
    $sudo shred -n 1 -v "$file" &&\
    cl::p_msg "please enter passphrase" &&\
    $sudo losetup -e aes -k 256 /dev/loop2 "$file" &&\
    cl::p_msg "building fs" &&\
    $sudo mkfs -t ext2 /dev/loop2 &&\
    $sudo losetup -d /dev/loop2
  else
    cl::p_err "wrong fs '$fs'" && return 1
  fi
  cl::p_msg "done"
  return 0
}
mkcc-cd () {
  [[ -z "$2" ]] && \
    cl::p_usg "$(cl::func_name) CONTAINER FILE.." && return 1
  file="$1"; shift
  create-crypto-containe "$file" 700 'iso9660' "$@"
}
mkcc-dvd () {
  [[ -z "$2" ]] && \
    cl::p_usg "$(cl::func_name) CONTAINER FILE.." && return 1
  local file="$1"; shift
  create-crypto-containe "$file" 4400 'iso9660' "$@"
}
mkcc-ext2 () {
  [[ -z "$2" ]] && \
    cl::p_usg "$(cl::func_name) CONTAINER SIZE" && return 1
  create-crypto-containe "$1" "$2" 'ext2'
}
mount-crypted () {
  [[ -z "$1" ]] && \
    cl::p_usg "$(cl::func_name) CONTAINER" && return 1
  local fs=ext2
  [[ "${1##*.}" = "iso" ]] && fs=iso9660
  local sudo=""
  ! cl::is_su && sudo="sudo" && \
    cl::p_msg "you might be asked to enter your sudo password"
  $sudo mount "$1" /mnt/crypted -t $fs \
    -o loop=/dev/loop2,encryption=aes256,gpgkey="$file",offset=8192
    #-o loop=/dev/loop2,encryption=aes,keybits=256
}

# https://stackoverflow.com/a/10379209
# OK - securely delete (overwrite) files / directories (recursively)
shred_secure() {
  [[ -z "$1" ]] && \
    cl::p_usg "$(cl::func_name) (FILE|DIR).." && return 1
  local return_code=0
  for f in "$@"; do
    [[ ! -e "${f}" ]] && \
      cl::p_war "File not found [${f}], skipping ..." && continue
    if [[ -d "${f}" ]]; then
      cl::p_msg "Shredding dir recursively: ${f}"
      # loop over all non-directories (including special types like links or sockets)
      find "${f}" -depth -not -type d | while read f2; do
        # file no longer existing? skip fast
        if [[ -L "${f2}" ]]; then
          cl::p_msg "Deleting symlink using rm: [${f2}]"
          rm -f "${f2}" \
            || return_code=1
          continue
        elif [[ -p "${f2}" ]]; then
          cl::p_msg "Deleting pipe using rm: [${f2}]"
          rm -f "${f2}" \
            || return_code=1
          continue
        elif [[ -S "${f2}" ]]; then
          cl::p_msg "Deleting socket using rm: [${f2}]"
          rm -f "${f2}" \
            || return_code=1
          continue
        elif [[ ! -f "${f2}" ]]; then
          cl::p_war "File not found (no longer existing?) [${f2}], skipping ..."
          continue
        fi
        cl::p_msg "Shredding file: ${f2}"
        # overwriting with random data
        shred -v -n 1 "${f2}"
        # forcing a sync of the buffers to the disk
        sync
        # overwriting with zeroes and remove the file
        shred -v -n 0 -z -u "${f2}" \
          || return_code=1
      done
      # delete all (now empty) directories, could also be: rm -rf "${f}"
      cl::p_msg "Deleting remaining (empty) directories."
      find "${f}" -depth -type d -exec rmdir --ignore-fail-on-non-empty '{}' \;
      # check if dir itself is gone, if note, some files may still exist
      if [[ -d "${f}" ]]; then
        cl::p_err "Shredding of the given dir [${f}] seems to be incomplete, most likely due to unaccessible / newly created files! Please check or try again."
        return_code=1
      fi
    else
      cl::p_msg "Shredding: ${f}"
      # overwriting with random data
      shred -v -n 1 "${f}"
      # forcing a sync of the buffers to the disk
      sync
      # overwriting with zeroes and remove the file
      shred -v -n 0 -z -u "${f}" \
        || return_code=1
    fi
  done
  if (( ${return_code} > 0 )); then
    cl::p_err "At least one ERROR occured while processing!"
  fi
  return ${return_code}
}


# ----------------------------------------------------------------------------
# }}} security & crypto
# {{{ debian/ubuntu
# ----------------------------------------------------------------------------
if command -v apt-key >& /dev/null; then
  apt_key_import () {
    [[ -z "$1" ]] && { cl::p_usg "$(cl::func_name) FINGERPRINT"; return 1; }
    gpg --keyserver wwwkeys.eu.pgp.net --recv-keys "$1" \
      && sudo gpg --armor --export "$1" | apt-key add -
  }
fi
# ----------------------------------------------------------------------------
# }}}
