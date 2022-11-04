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
declare -r VERSION=0.2.0
declare -r SCRIPT=${0##*/}
declare -r AUTHOR="Urs Roesch"
declare -r LICENSE="GPL2"
declare -r BASE_DIR=$(readlink --canonicalize $(dirname ${0})/..)
declare -r TIMESTAMP=$(date +%F)
declare -r LINE=$(printf "%0.1s" -{1..80})

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} <options>

  Options:
    -h | --help     This message
    -V | --version  Print version, author and license and exit

USAGE
  exit ${exit_code}
}

function parse_options() {
  while (( $# > 0 )); do
    case ${1} in
    -h|--help)    usage 0;;
    -V|--version) version;;
    *)            usage 1;;
    esac
    shift
  done
}

function version() {
  printf "%s v%s\nCopyright (c) %s\nLicense - %s\n" \
    "${SCRIPT%.*}" "${VERSION}" "${AUTHOR}" "${LICENSE}"
  exit 0
}

function default_branch() {
  # prefer master over main
  local -a branches=( $(git branch | grep -oE "\<(master|main)\>" | sort -r) )
  echo "${branches[0]}"
}

function pull_all() {
  local repo_name=${1}; shift;
  cd ${repo_name}
  print_header "${repo_name}"
  git checkout "$(default_branch)"
  git pull --rebase origin "$(default_branch)"
  for repo in $(git branch | grep -v master); do
    git branch -d ${repo} && git push origin :${repo} || :
  done
}

function print_header() {
   local repo_name=${1}
   echo
   echo ${LINE}
   echo ${repo_name}
   echo ${LINE}
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
cd ${BASE_DIR} &&
  for repo_name in *Portable *Template; do
   ( pull_all "${repo_name}" )
  done
