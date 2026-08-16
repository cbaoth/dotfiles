# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/dotfiles/.zsh.d/aliases-linux_desktop.zsh: Host-specific aliases for Linux desktop.

# {{{ - GAMES ----------------------------------------------------------------
alias pob='wine "C:/users/$USER/AppData/Roaming/Path of Building Community/Path of Building.exe"'
pob-setup() {
  local pob_setup_url="https://github.com/PathOfBuildingCommunity/PathOfBuilding/releases/latest/download/PathOfBuildingCommunity-Setup.exe"
  local pob_setup_path="/tmp/PathOfBuildingCommunity-Setup.exe"
  echo "Setting up Path of Building Community from https://pathofbuilding.community/"
  if [[ -f "${pob_setup_path}" ]]; then
    echo "Found existing setup file at ${pob_setup_path}, removing it ..."
    rm -f "${pob_setup_path}"
  fi
  echo "Downloading Path of Building Community setup from ${pob_setup_url} ..."
  wget "${pob_setup_url}" -O "${pob_setup_path}"
  wine "${pob_setup_path}"
  rm -f "${pob_setup_path}"
}
alias pob2='wine "C:/users/$USER/AppData/Roaming/Path of Building Community (PoE2)/Path of Building-PoE2.exe"'
pob2-setup() {
  local pob2_setup_url="https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/releases/latest/download/PathOfBuildingCommunity-PoE2-Setup.exe"
  local pob2_setup_path="/tmp/PathOfBuildingCommunity-PoE2-Setup.exe"
  echo "Setting up Path of Building Community (PoE2) from https://pathofbuilding.community/"
  if [[ -f "${pob2_setup_path}" ]]; then
    echo "Found existing setup file at ${pob2_setup_path}, removing it ..."
    rm -f "${pob2_setup_path}"
  fi
  echo "Downloading Path of Building Community (PoE2) setup from ${pob2_setup_url} ..."
  wget "${pob2_setup_url}" -O "${pob2_setup_path}"
  wine "${pob2_setup_path}"
  rm -f "${pob2_setup_path}"
}
alias poeb=pob
alias poe2b=pob2
alias bg3mm='protontricks-launch --appid 1086940 "$HOME/Documents/Games/Baldurs Gate 3/BG3ModManager/BG3ModManager.exe"'
# }}} - GAMES ----------------------------------------------------------------
