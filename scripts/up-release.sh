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
declare -r VERSION=0.4.0
declare -r SCRIPT=${0##*/}
declare -r SCRIPT_DIR=$(readlink -f $(dirname ${0}))
declare -r PACKAGE_NAME=$(basename $(pwd))
declare -r UPDATE_INI=App/AppInfo/update.ini
declare -r POWERSHELL=$(which pwsh 2>/dev/null || which powershell 2>/dev/null)
declare -r GIT_MESSAGE="Release %s\n\nSummary:\n  * Upstream release v%s\n"
declare -g MESSAGE=
declare -g ITERATION=
declare -g BUILD_METHOD=powershell
declare -g PRE_RELEASE=
declare -g OLD_VERSION=$(awk -F "[ =]*" '/Upstream/ { print $2 }' ${UPDATE_INI})
declare -g NEW_VERSION=
declare -g OLD_PACKAGE=
declare -g NEW_PACKAGE=
declare -g OLD_DISPLAY=
declare -g NEW_DISPLAY=
declare -g CHECKSUM=

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} <options>

  Options:
    -h | --help              This message
    -d | --docker            Build with docker instead of powershell
    -i | --iteration <N>     Override the iteration
    -o | --old <version>     Old version string (optional)
                             Default: ${OLD_VERSION}
    -n | --new <version>     New version string (mandatory)
    -c | --checksum <sha256> Provide the checksum for the download
    -m | --message <messag>  New version string (optional)
    -p | --pre-release       Submit as pre-release to github

USAGE
  exit ${exit_code}
}

function parse_options() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -d|--docker)      BUILD_METHOD=docker;;
    -i|--iteration)   shift; ITERATION=${1};;
    -o|--old)         shift; OLD_VERSION=${1};;
    -n|--new)         shift; NEW_VERSION=${1};;
    -m|--message)     shift; MESSAGE=${1};;
    -c|--checksum)    shift; CHECKSUM=${1};;
    -p|--pre-release) PRE_RELASE=true;;
    -h|--help)        usage 0;;
    *)                usage 1;;
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

function format_package_version() {
  local    package_version=${NEW_VERSION//[^0-9.-]/}
  local -a package_tokens=( ${package_version//[-.]/ } )
  [[ -n ${ITERATION} ]] && package_tokens[3]=${ITERATION}
  NEW_PACKAGE=$(printf "%d.%d.%d.%d" ${package_tokens[@]})
}

function define_release_variables() {
  OLD_RELEASE=$(git describe --abbrev=0 --tags)
  OLD_PACKAGE=$(awk -F "[= ]*" '/^Package/ { print $2 }' ${UPDATE_INI})
  OLD_DISPLAY=$(awk -F "[= ]*" '/^Display/ { print $2 }' ${UPDATE_INI})
  NEW_RELEASE=${OLD_RELEASE/${OLD_VERSION}/${NEW_VERSION}}
  if [[ ! ${OLD_RELEASE} =~ ${OLD_VERSION//+/\\+} ]]; then
    echo "'${OLD_RELEASE}' from git tags does not match with provided '${OLD_VERSION}'"
    exit 255
  fi
  format_package_version
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

function message() {
  if [[ -n $MESSAGE ]]; then
    echo "${MESSAGE}"
  else
    printf "${GIT_MESSAGE}" ${NEW_RELEASE} ${NEW_VERSION}
  fi
}

function commit_release() {
  git diff --exit-code || \
    git commit \
      --all \
      --message "$(message)"
}

function push_release() {
  git push origin release/${NEW_RELEASE}
  git push origin ${NEW_RELEASE}
}

function build_with_powershell() {
  ${POWERSHELL} \
    -ExecutionPolicy ByPass \
    -File Other/Update/Update.ps1 \
    ${CHECKSUM:--UpdateChecksums}
}

function build_with_docker() {
  ${SCRIPT_DIR}/docker-build.sh --up-release
}

function build_release() {
  case ${BUILD_METHOD} in
  docker) build_with_docker;;
  *)      build_with_powershell;;
  esac
}

function escape_regex() {
  local string=${1}
  string=${string//\./\\.}
  string=${string//\+/\\+}
  string=${string//\*/\\*}
  echo ${string}
}

function update_upstream() {
  local old_version=${1}
  sed -r -i \
    -e "/^Upstream/s/${old_version}/${NEW_VERSION}/g" \
    -e "/^Upstream/s/${old_version%%-*}/${NEW_VERSION%%-*}/g" \
    -e "/^Upstream/s/${old_version//+/}/${NEW_VERSION//+}/g" \
    ${UPDATE_INI}
}

function create_new_release() {
  local old_version=$(escape_regex "${OLD_VERSION}")
  sed -r -i \
    -e "/^Package/s/${OLD_PACKAGE}/${NEW_PACKAGE}/" \
    -e '/^Upstream/!'"s/${old_version}\>/${NEW_VERSION}/g" \
    -e '/^Upstream/!'"s/${old_version%%-*}\>/${NEW_VERSION%%-*}/g" \
    -e '/^Upstream/!'"s/${old_version//+/}\>/${NEW_VERSION//+}/g" \
    -e '/^Upstream/!'"s/${old_version//+-/+}\>/${NEW_VERSION//+-/+}/g" \
    -e '/^Checksum/!'"s/\<${OLD_VERSION//\./}\>/${NEW_VERSION//\./}/g" \
    ${UPDATE_INI}
  update_checksum
  build_release
  update_upstream "${old_version}"
  commit_release
  create_release_tag
  push_release
}

function update_checksum() {
  [[ -z ${CHECKSUM} ]] && return 0
  sed -r -i \
    -e "/^Checksum1/s/(.*)::.*/\\1::${CHECKSUM}/" \
    ${UPDATE_INI}
}

function create_pull_request() {
  hub pull-request -m "$(message)"
}

function wait_for_ci_status() {
  for count in {1..20}; do
    hub ci-status | grep -q success && return 0
    sleep 60
  done
  echo timeout of 20 minutes reached!
  return 1
}

function create_release() {
  ${SCRIPT_DIR}/pa-github-release.sh \
    ${PRE_RELEASE:+--pre-release} \
    --tag ${NEW_RELEASE} \
    --message "$(message)"
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
