#!/bin/bash

DAYS_FROM=-7
DAYS_TO=-1
DATE_FROM="$(date +%Y-%m-%d -d now${DAYS_FROM}days)"
DATE_TO="$(date +%Y-%m-%d -d now${DAYS_TO}days)"
DATES="("; for i in $(seq ${DAYS_FROM} ${DAYS_TO}); do [[ ${i} -ne ${DAYS_FROM} ]] && DATES+='|'; DATES+="$(date +%Y-%m-%d -d now${i}days)"; done; DATES+=")"

BODY="/tmp/fail2ban-summary-mail.mail"
SUBJECT="Fail2Ban summary for the week from ${DATE_FROM} to ${DATE_TO}"
CONTENT_TYPE="Content-Type: text/html"
MAILTO="admin@yav.in"

mail_summary() {
  # ensure empty mail body temp file
  rm -f "${BODY}"
  touch "${BODY}"

  # append to mail body: salutation
  printf "<html><body>Hi,<br/><br/>here is your fail2ban report for the week from ${DATE_FROM} to ${DATE_TO}.<br/><br/>" >> "${BODY}"

  # get ban count from the given date range
  local ban_count="$(zgrep -E "${DATES}.* Ban " /var/log/fail2ban.log* | wc -l)"

  if [[ "${ban_count}" =~ [^0-9] ]]; then
    printf "ERROR GETTING TOTAL BAN COUNT (NOT AN INTEGER) !!!<br/><br/>" >> "${BODY}"
  elif ((${ban_count} <= 0)); then
    printf "No bans detected :)<br/><br/>" >> "${BODY}"
  else
    printf "A total of %s bans were detected.<br/><br/>" "${ban_count}" >> "${BODY}"
    printf -- "---<br/><br/>" "${ban_count}" >> "${BODY}"
    # count per jail
    zgrep -E "${DATES}.* Ban " /var/log/fail2ban.log* | sed -r "s/.*\[([^\]+)\]\s+Ban\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})([^0-9].*|$)/\1/g" | sort | uniq -c | sort -nr | sed -r 's/$/<br\/>/g' >> "${BODY}"
    printf -- "<br/>---<br/><br/>" "${ban_cout}" >> "${BODY}"
    # count per IP
    zgrep -E "${DATES}.* Ban " /var/log/fail2ban.log* | sed -r "s/.*\[([^\]+)\]\s+Ban\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})([^0-9].*|$)/\2 \1/g" | sort | uniq -c | sort -nr | sed -r "s/\s*([0-9]+)\s([0-9.]+)\s+(.*)/\2\t\3\t\1/g" | sed -r 's/$/<br\/>/g' >> "${BODY}"
    printf -- "<br/>---<br/><br/>" "${ban_cout}" >> "${BODY}"
  fi

  printf "Bye!<br/>Your fail2bain summary mail script<br/></body></html>" >> "${BODY}"

  # send mail
  mail -a "${CONTENT_TYPE}" -s "${SUBJECT}" "${MAILTO}" <"${BODY}"

  #  delete fifo
  rm "${BODY}"
}

mail_summary
