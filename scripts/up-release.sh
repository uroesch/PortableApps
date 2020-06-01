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
declare -g OLD_VERSION=
declare -g NEW_VERSION=
declare -g NEW_RELEASE=
declare -r UPDATE_INI=App/AppInfo/update.ini
declare -r GIT_MESSAGE="Release %s\n\nSummary:\n  * Upstream release v%s\n"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE
  
  Usage: ${SCRIPT} <options>
  
  Options:
    -h | --help          This message  
    -o | --old <version> Old version string (mandatory)
    -n | --new <version> New version string (mandatory)

USAGE
  exit ${exit_code}
}

function parse_options() { 
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -o|--old)  shift; OLD_VERSION=${1};;
    -n|--new)  shift; NEW_VERSION=${1};;
    -h|--help) usage 0;;
    *)         usage 1;; 
    esac
    shift
  done
}

function verify_options() { 
  for option in NEW_VERSION OLD_VERSION; do
    if [[ -z ${!option} ]]; then
      printf "\nMissing option --old or --new\n"
      usage 1
    fi
  done
}

function last_release() {
  git tag | tail -n 1 
}

function sync_master() {
  git checkout master
  git pull origin master
}

function create_new_branch() {
  local old_release=$(last_release)
  local checkout_option=""
  NEW_RELEASE=${old_release/${OLD_VERSION}/${NEW_VERSION}}
  if ! git branch | grep -q "release/${NEW_RELEASE}"; then
    checkout_option="-b"
  fi 
  git checkout ${checkout_option} release/${NEW_RELEASE} 
}

function create_release_tag() {
  # clean tag if already exits
  if git tag | grep ${NEW_RELEASE}; then 
    git tag --delete ${NEW_RELEASE} 
  fi 
  git tag ${NEW_RELEASE}
}

function commit_release() {
  git diff --exit-code || \
    git commit \
      --all \
      --message "$(printf "${GIT_MESSAGE}" ${NEW_RELEASE} ${NEW_VERSION})"
}

function push_release() {
  git push origin release/${NEW_RELEASE}
  git push origin ${NEW_RELEASE}
}

function create_new_release() {
  sed -i \
    -e "s/${OLD_VERSION}/${NEW_VERSION}/g" \
    -e "s/${OLD_VERSION%%-*}/${NEW_VERSION%%-*}/g" \
    ${UPDATE_INI}
  powershell Other/Update/Update.ps1
  commit_release 
  create_release_tag
  push_release 
}

function create_pull_request() {
  git hub pull-request \
    --message "$(printf "${GIT_MESSAGE}" ${NEW_RELEASE} ${NEW_VERSION})"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
verify_options
sync_master
create_new_branch
create_new_release
create_pull_request
