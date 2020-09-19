#!/bin/bash

YESTERDAY="$(date +%Y-%m-%d -d yesterday)"
BODY="/tmp/fail2ban-mail-${YESTERDAY}.mail"
SUBJECT="Fail2Ban summary for yesterday ${YESTERDAY}"
CONTENT_TYPE="Content-Type: text/html"
MAILTO="admin@yav.in"

mail_summary() {
  # ensure empty mail body temp file
  rm -f "${BODY}"
  touch "${BODY}"

  # append to mail body: salutation
  printf "<html><body>Hello,<br/><br/>here is your daily fail2ban report for yesterday ${YESTERDAY}.<br/><br/>" >> "${BODY}"

  # get ban count from yesterday
  local ban_count="$(grep ' Ban ' /var/log/fail2ban.log | grep ${YESTERDAY} | wc -l)"

  if [[ "${ban_count}" =~ [^0-9] ]]; then
    printf "ERROR GETTING TOTAL BAN COUNT (NOT AN INTEGER) !!!<br/><br/>" >> "${BODY}"
  elif ((${ban_count} <= 0)); then
    printf "No bans detected :)<br/><br/>" >> "${BODY}"
  else
    printf "A total of %s bans were detected.<br/><br/>" "${ban_count}" >> "${BODY}"
    printf -- "---<br/><br/>" "${ban_count}" >> "${BODY}"
    # count per jail
    grep " Ban " /var/log/fail2ban.log | grep "${YESTERDAY}" | sed -r "s/.*\[([^\]+)\]\s+Ban\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})([^0-9].*|$)/\1/g" | sort | uniq -c | sort -nr | sed -r 's/$/<br\/>/g' >> "${BODY}"
    printf -- "<br/>---<br/><br/>" "${ban_cout}" >> "${BODY}"
    # count per IP
    grep " Ban " /var/log/fail2ban.log | grep "${YESTERDAY}" | sed -r "s/.*\[([^\]+)\]\s+Ban\s+([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})([^0-9].*|$)/\2 \1/g" | sort | uniq -c | sort -nr | sed -r "s/\s*([0-9]+)\s([0-9.]+)\s+(.*)/\2\t\3\t\1/g" | sed -r 's/$/<br\/>/g' >> "${BODY}"
    printf -- "<br/>---<br/><br/>" "${ban_cout}" >> "${BODY}"
  fi

  printf "Bye!<br/>Your fail2bain summary mail script<br/></body></html>" >> "${BODY}"

  # send mail
  mail -a "${CONTENT_TYPE}" -s "${SUBJECT}" "${MAILTO}" <"${BODY}"

  #  delete fifo
  rm "${BODY}"
}

mail_summary

