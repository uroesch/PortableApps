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
declare -r BASE_DIR=$(readlink --canonicalize $(dirname ${0})/..)
declare -r TIMESTAMP=$(date +%F)
declare -r LINE=$(printf "%0.1s" -{1..80})
declare -r MESSAGE="Sync common files - ${TIMESTAMP}"
declare -x DISPLAY=:7777
declare -x START_X=false
declare -a REPOS=()

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function start_x() {
  [[ ${START_X} != true ]] && return 0
  pkill -f "Xvfb ${DISPLAY}" || :
  sleep 1
  Xvfb ${DISPLAY} -ac &
}

# -----------------------------------------------------------------------------

function sync_repo() {
  local dir=${1}
  cd ${dir}
  git checkout master
  git fetch --all
  git pull origin master
  if git branch | grep -q "sync/update-${TIMESTAMP}"; then
    git checkout sync/update-${TIMESTAMP}
  else
    git checkout -b sync/update-${TIMESTAMP}
  fi
  rsync -av ../CommonFiles/ .
  git add .
  if ! git commit -a -m "${MESSAGE}"; then
    git checkout master
    git branch -D sync/update-${TIMESTAMP}
  else
    powershell Other/Update/Update.ps1
    git push origin sync/update-${TIMESTAMP}
    hub pull-request -m "${MESSAGE}"
    git checkout master
  fi
}

# -----------------------------------------------------------------------------

function print_header() {
   local ${repo_name}=${1}
   echo
   echo ${LINE}
   echo ${repo_name}
   echo ${LINE}
}

# -----------------------------------------------------------------------------

function sync_repos() {
  local -a modules=( ${@} )
  cd ${BASE_DIR}
  if [[ -z ${modules:-} ]]; then
    modules=$(ls -d *Portable)
  fi
  for repo_name in ${modules[@]}; do
    print_header "${repo_name}"
    ( sync_repo "${repo_name}"; )
  done
}

# -----------------------------------------------------------------------------

function usage() {
  local exit_code=${1:-1}; shift;
  cat <<USAGE

  Usage:
    ${SCRIPT} [-X] [-h]

  Options:
    -h | --help       This message
    -X | --start-x    Start a hidden X server for the build to go through

USAGE
  exit ${exit_code}
}

# -----------------------------------------------------------------------------

function parse_options() {
  while [[ ${#} -gt 0 ]]; do
    case ${1} in
    -X|--start-x) START_X=true;;
    -h|--help)    usage 0;;
    *Portable)    REPOS=( ${REPOS[@]:-} ${1} );;
    *)           usage 1;;
    esac
    shift
  done
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
start_x
sync_repos "${REPOS[@]}"
