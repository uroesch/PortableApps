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
declare -r BASE_DIR=$(readlink -f $(dirname ${0})/..)
declare -r SCRIPT_DIR=$(readlink -f $(dirname $0))
declare -r UPDATE_SCRIPT=Update.ps1
declare -r DIVIDER=$(printf "%0.1s" -{1..80})
declare -r POWERSHELL=$(which pwsh 2>/dev/null || which powershell 2>/dev/null)
declare -g BUILD_METHOD=powershell

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} <options>

  Options:
    -h | --help      This message
    -d | --docker    Build with docker instead of powershell

USAGE
  exit ${exit_code}
}

# -----------------------------------------------------------------------------

function parse_options() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -d|--docker) BUILD_METHOD=docker;;
    -h|--help)   usage 0;;
    *)           usage 1;;
    esac
    shift
  done
}

# -----------------------------------------------------------------------------

function file_list() {
  find ${BASE_DIR} \
    -type f \
    -name ${UPDATE_SCRIPT} \
    -path "${BASE_DIR}/*Portable/*" | \
    sort
}

# -----------------------------------------------------------------------------

function build_with_powershell() {
  local name=${1}; shift
  local script=${1}; shift
  echo ${DIVIDER}
  echo Building ${name}
  echo ${DIVIDER}
  echo
  pwsh \
    -ExecutionPolicy ByPass \
    -File ${script} \
    ${CHECKSUM:--UpdateChecksums}
}

# -----------------------------------------------------------------------------

function build_with_docker() {
  local name=${1}; shift
  cd ${BASE_DIR}/${name} && \
    ${SCRIPT_DIR}/docker-build.sh
}

# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------

function build_package() {
  script=${1}; shift;
  name=${script#${BASE_DIR}/}
  name=${name%%/*}
  case ${BUILD_METHOD} in
  docker) build_with_docker ${name};;
  *)      build_with_powershell ${name} ${script};;
  esac
  echo
}

# -----------------------------------------------------------------------------

function build_all_packages() {
  for script in $(file_list); do
    build_package "${script}"
  done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
build_all_packages
