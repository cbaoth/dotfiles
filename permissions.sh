#!/bin/bash

# safety check before chaning mod bits for the wrong files
[ ! -d ".git" ] \
  && echo "error: .git not found, this doesn't seem to be the right folder" \
  && exit 1
 
find -type d -exec chmod 750 '{}' \;
find -type f -exec chmod 640 '{}' \;
chmod 750 *.sh

