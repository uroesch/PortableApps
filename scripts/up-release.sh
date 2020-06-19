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
declare -r PACKAGE_NAME=$(basename $(pwd))
declare -g OLD_VERSION=
declare -g NEW_VERSION=
declare -g OLD_PACKAGE=
declare -g NEW_PACKAGE=
declare -g OLD_DISPLAY=
declare -g NEW_DISPLAY=
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

function define_release_variables() {
  OLD_RELEASE=$(git describe --abbrev=0 --tags)
  OLD_PACKAGE=$(awk -F "[= ]*" '/^Package/ { print $2 }' ${UPDATE_INI})
  OLD_DISPLAY=$(awk -F "[= ]*" '/^Display/ { print $2 }' ${UPDATE_INI})
  NEW_PACKAGE=${NEW_VERSION//[^0-9.-]/}
  NEW_PACKAGE=$(printf "%d.%d.%d.%d" ${NEW_PACKAGE//[-.]/ })
  NEW_RELEASE=${OLD_RELEASE/${OLD_VERSION}/${NEW_VERSION}}
}

function sync_master() {
  git checkout master
  git pull origin master
}

function create_new_branch() {
  local checkout_option=""
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
    -e "/^Package/s/${OLD_PACKAGE}/${NEW_PACKAGE}/" \
    -e "s/${OLD_VERSION}/${NEW_VERSION}/g" \
    -e "s/${OLD_VERSION%%-*}/${NEW_VERSION%%-*}/g" \
    -e "s/${OLD_VERSION//+/}/${NEW_VERSION//+}/g" \
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

function wait_for_ci_status() {
  for count in {1..20}; do
    while true; do
      git hub ci-status | grep -q success && return 0
      sleep 60
    done
  done
  echo timeout of 20 minutes reached!
  return 1
}

function find_installer() {
  local release=${NEW_RELEASE:1:1000}
  find ../ \
    -type f \
    -name "${PACKAGE_NAME}_${release//[+]/*}*.paf.exe"
}

function create_checksums() {
  local files="${@}"
  sha256sum ${files}  | \
    awk '{ print gensub("../", "", 1, $2), $1 }'
}


function assemble_release_message() { 
  local cell_width=64
  local line=$(eval printf "%0.1s" -{1..${cell_width}})
  local table_format="| %-${cell_width}s | %-${cell_width}s |\n"
  printf "%s\n\nUpstream release %s" ${NEW_RELEASE} ${NEW_VERSION};
  printf "\n\n${table_format}" Filename SHA-256
  printf "${table_format}" ${line} ${line}
  printf "${table_format}" $(create_checksums $(find_installer))
}

function create_release() {
  local options=""
  case ${NEW_RELEASE} in
  *beta*|*alpha*|*rc*) options="${options} -p";;
  esac
  assemble_release_message
  git hub release create ${options} \
    -a $(find_installer) \
    -F <( assemble_release_message ) \
    ${NEW_RELEASE}
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
verify_options
sync_master
define_release_variables
create_new_branch
create_new_release
create_pull_request
wait_for_ci_status
create_release
