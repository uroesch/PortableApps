#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
set -o errexit
set -o nounset
set -o pipefail

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
declare -r SCRIPT=${0##*/}
declare -r AUTHOR="Urs Roesch"
declare -r VERSION="0.1.0"
declare -r LICENSE="GPL2"
declare -r INSTALL_DIR=$( cd $(dirname ${0})/..; pwd)
declare -g REMOVE_APPINSTALLERS=true
declare -g REMOVE_INFRAINSTALLERS=true
declare -g CLEAN_DOWNLOADDIRS=false

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

function usage() {
  local exit_code="${1:-1}"
  cat << USAGE
  
  Usage: 
    ${SCRIPT} [<options>]

  Options:
    -h --help            This message
    -A --skip-apps       Do not delete complied Apps and their SHA256 file. 
    -D --clean-downloads Delete content of <Name>Portable/Download directory.
    -I --skip-installer  Do not delete the infrastructure installers.
    -V --version         Display Version and exit.

  Description:
    Cleans up working copies of old builds and if desired the Download directories
    witin the PortableApp definition.
    Without any option given both the PortableApp.com Installer and Launcher and the
    PortableApps file ending in .paf.exe and .paf.exe.sha256 will be removed.

USAGE
  exit ${exit_code}
}

function parse_options() {
  while (( ${#} > 0 )); do
    case ${1} in
    -A|--skip-apps)       REMOVE_APPINSTALLERS=false;;
    -I|--skip-installer)  REMOVE_INFRAINSTALLERS=false;;
    -D|--clean-downloads) CLEAN_DOWNLOADDIRS=true;;
    -V|--version)         version;;
    -h|--help)            usage 0;;
    *)                    usage 1;;
    esac
    shift
  done 
}

function version() {
  printf "%s v%s\nCopyright (c) %s\nLicense - %s\n" \
    "${SCRIPT%.*}" "${VERSION}" "${AUTHOR}" "${LICENSE}"
  exit 0
}

function remove-files() {
  local message=${1}; shift;
  local files=( "${@}" )
 
  (( ${#files[@]} ==  0 )) && return 0
  printf "${message}\n" "${#files[@]}" "${INSTALL_DIR}"
  for file in ${files[@]}; do
    printf " - Removing File '%s'\n" "${file}"
    rm "${file}"
  done
}

function remove-installers() {
  local message="${1}"; shift; 
  local filter="${1}"; shift; 
  local files=( $(find ${INSTALL_DIR} -type f -name "${filter}") )
  remove-files "${message}" "${files[@]}"
}

function remove-appinstallers() {
  local message
  [[ ${REMOVE_APPINSTALLERS} != true ]] && return 0
  message="Removing %s PortableApps installers from '%s'"
  remove-installers "${message}" "*Portable_*.paf.exe" 
  message="Removing %s PortableApps installer checksums from '%s'"
  remove-installers "${message}" "*Portable_*.paf.exe.sha256" 
}

function remove-infrainstallers() {
  local message
  [[ ${REMOVE_INFRAINSTALLERS} != true ]] && return 0
  message="Removing %s build infrastructure installers from '%s'"
  remove-installers "${message}" "PortableApps.com*.paf.exe"
}

function clean-downloaddirectory() {
  local message
  local files
  [[ ${CLEAN_DOWNLOADDIRS} != true ]] && return 0
  files=( $(find ${INSTALL_DIR}/*Portable/Download -type f) )
  message="Removing %s Files from '%s/*Portable/Download' directories"
  remove-files "${message}" "${files[@]}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
remove-appinstallers
remove-infrainstallers
clean-downloaddirectory
