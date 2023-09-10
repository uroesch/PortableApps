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
declare -r SCRIPT_DIR=$(cd $(dirname $0); pwd)
declare -r UPDATE_SCRIPT=Update.ps1

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function ::usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} [<options>]

  Options:
    -h | --help      This message
    -V | --version   Print version and exit

  Description:
    Installs dependencies to build the PortableApps collection 
    found at https://github.com/uroesch/PortableApps.

USAGE
  exit ${exit_code}
}

# -----------------------------------------------------------------------------

function ::parse_options() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -h|--help)    ::usage 0;;
    -V|--version) ::version;;
    *)            ::usage 1;;
    esac
    shift
  done
}

# -----------------------------------------------------------------------------

function ::version() {
  printf "%s v%s\nCopyright (c) %s\nLicense - %s\n" \
    "${SCRIPT%.*}" "${VERSION}" "${AUTHOR}" "${LICENSE}"
  exit 0
}

# -----------------------------------------------------------------------------

function ::run_as_root() {
  (( $(id -u) > 0 )) && exec sudo bash ${SCRIPT_DIR}/${SCRIPT} "${@}" || :
}

# -----------------------------------------------------------------------------

function install::powershell() {
  snap install powershell --classic
}

# -----------------------------------------------------------------------------

function install::wine() {
  dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get -y install wine32
}

# -----------------------------------------------------------------------------

function install::packages() {
  apt-get -y install \
   git \
   git-lfs \
   hub \
   p7zip-full \
   xvfb
}

# -----------------------------------------------------------------------------

::parse_options "${@}"
::run_as_root "${@}"
install::powershell
install::wine
install::packages





