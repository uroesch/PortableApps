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
declare -r VERSION="0.2.0"
declare -r LICENSE="GPL2"
declare -r BASE_DIR=$(cd $(dirname ${0})/..; pwd)
declare -r SCRIPT_DIR=$(cd $(dirname $0); pwd)
declare -r UPDATE_SCRIPT=Update.ps1
declare -r DIVIDER=$(printf "%0.1s" -{1..80})
declare -r POWERSHELL=$(which pwsh 2>/dev/null || which powershell 2>/dev/null)
declare -g BUILD_METHOD=powershell

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function ::usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} <options>

  Options:
    -h | --help      This message
    -d | --docker    Build with docker instead of powershell
    -V | --version   Print version and exit

USAGE
  exit ${exit_code}
}

# -----------------------------------------------------------------------------

function ::parse_options() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -d|--docker)  BUILD_METHOD=docker;;
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

function ::file_list() {
  find ${BASE_DIR} \
    -type f \
    -name ${UPDATE_SCRIPT} \
    -path "${BASE_DIR}/*Portable/*" | \
    sort
}

# -----------------------------------------------------------------------------
# X Functions
# -----------------------------------------------------------------------------
function x::create_port() {
  printf -v DISPLAY ":7%03d" $(( ${RANDOM} % 1000 )) 
  export DISPLAY
}

function x::start() {
  [[ ${XDG_SESSION_TYPE} == tty ]] || return 0 && :
  x::create_port
  Xvfb ${DISPLAY} &>/dev/null & 
}

function x::stop() {
  pkill -f "Xvfb ${DISPLAY}" &> /dev/null || :
}

# -----------------------------------------------------------------------------
# Build Functions
# -----------------------------------------------------------------------------
function build::with_powershell() {
  local name=${1}; shift
  local script=${1}; shift
  printf "%s\n" ${DIVIDER} "Building ${name}" ${DIVIDER} ''
  x::start
  pwsh \
    -ExecutionPolicy ByPass \
    -File ${script} \
    ${CHECKSUM:--UpdateChecksums}
  x::stop
}

# -----------------------------------------------------------------------------

function build::with_docker() {
  local name=${1}; shift
  cd ${BASE_DIR}/${name} && \
    ${SCRIPT_DIR}/docker-build.sh
}

# -----------------------------------------------------------------------------

function build::package() {
  script=${1}; shift;
  name=${script#${BASE_DIR}/}
  name=${name%%/*}
  case ${BUILD_METHOD} in
  docker) build::with_docker ${name};;
  *)      build::with_powershell ${name} ${script};;
  esac
  echo
}

# -----------------------------------------------------------------------------

function build::all_packages() {
  for script in $(::file_list); do
    build::package "${script}"
  done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
::parse_options "${@}"
build::all_packages
