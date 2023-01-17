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
declare -r VERSION=0.10.1
declare -r SCRIPT=${0##*/}
declare -r AUTHOR="Urs Roesch"
declare -r LICENSE="GPL2"
declare -r SCRIPT_DIR=$(readlink -f $(dirname ${0}))
declare -r PACKAGE_NAME=$(basename $(pwd))
declare -r UPDATE_INI=App/AppInfo/update.ini
declare -r POWERSHELL=$(which pwsh 2>/dev/null || which powershell 2>/dev/null)
declare -r GIT_MESSAGE="Release %s\n\nSummary:\n  * Upstream release v%s\n"
declare -g DEFAULT_BRANCH=
declare -g MESSAGE=
declare -g ITERATION=
declare -g BUILD_METHOD=powershell
declare -g PRE_RELEASE=
declare -g OLD_VERSION=$(awk -F "[ =]*" '/Upstream/ {print $2}' ${UPDATE_INI})
declare -g GITHUB_PATH=$(awk -F "[ =]*" '/GithubPath/ {print $2}' ${UPDATE_INI})
declare -g NEW_VERSION=
declare -g NEW_RELEASE=
declare -g OLD_PACKAGE=
declare -g NEW_PACKAGE=
declare -g OLD_DISPLAY=
declare -g NEW_DISPLAY=
declare -g CHECKSUM=
declare -g USE_GITHUB=
declare -g STAGE=release
declare -a GITHUB_RELEASES=()

# -----------------------------------------------------------------------------
# Global functions
# -----------------------------------------------------------------------------
function ::run_stages() {
  local -- stage=${1}; shift;
  if [[ ! ${stage} =~ prep|patch|build|pr|release ]]; then
    echo "Stage ${stage} unknown to human kind!" 1>&2
  fi
  prep::github_releases
  prep::sync_default_branch
  prep::define_release_variables
  prep::compare_versions
  prep::print_variables
  [[ ${stage} == prep ]] && return 0
  patch::create_branch
  patch::create_release
  [[ ${stage} == patch ]] && return 0
  build::release
  [[ ${stage} == build ]] && return 0
  pr::create_pull_request
  pr::wait_for_ci_status
  [[ ${stage} == pr ]] && return 0
  release::to_github
}

function ::usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} <options>

  Options:
    -c | --checksum <sha256>   Provide the checksum for the download
    -d | --docker              Build with docker instead of powershell
    -g | --github-path <path>  Specify the github path of upstream project
                               Default: ${GITHUB_PATH}
    -h | --help                This message
    -i | --iteration <N>       Override the iteration
    -m | --message <messag>    New version string (optional)
    -n | --new <version>       New version string (mandatory)
    -o | --old <version>       Old version string (optional)
                               Default: ${OLD_VERSION}
    -p | --pre-release         Submit as pre-release to github
    -r | --release-name <name> New PA release name
    -s | --stage <stage>       Only complete up to a certain stage.
                               Values are prep, patch, build, pr, release
                               Default: ${STAGE}
    -V | --version             Print version, author and license and exit


USAGE
  exit ${exit_code}
}

function ::parse_options() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -V|--version)      ::version;;
    -c|--checksum)     shift; CHECKSUM=${1};;
    -d|--docker)       BUILD_METHOD=docker;;
    -g|--github-path)  shift; GITHUB_PATH=${1};;
    -i|--iteration)    shift; ITERATION=${1};;
    -m|--message)      shift; MESSAGE=${1};;
    -n|--new)          shift; NEW_VERSION=${1};;
    -o|--old)          shift; OLD_VERSION=${1};;
    -p|--pre-release)  PRE_RELEASE=true;;
    -r|--release-name) shift; NEW_RELEASE=${1};;
    -s|--stage)        shift; STAGE=${1};;
    -h|--help)         ::usage 0;;
    *)                 ::usage 1;;
    esac
    shift
  done
}

function ::version() {
  printf "%s v%s\nCopyright (c) %s\nLicense - %s\n" \
    "${SCRIPT%.*}" "${VERSION}" "${AUTHOR}" "${LICENSE}"
  exit 0
}

function ::verify_options() {
  if [[ -z ${GITHUB_PATH} && -z ${NEW_VERSION} ]]; then
    printf "\nMissing value vor GithupPath or --new option\n"
    ::usage 123
  fi
  for option in OLD_VERSION; do
    if [[ -z ${!option} ]]; then
      printf "\nMissing option --old or --new\n"
      ::usage 1
    fi
  done
  # don't use github url if new version was given as an option
  if [[ -n ${NEW_VERSION} ]]; then
    USE_GITHUB=false
  elif [[ -n ${GITHUB_PATH} ]]; then
    USE_GITHUB=true
  fi
}

function ::message() {
  if [[ -n $MESSAGE ]]; then
    echo "${MESSAGE}"
  else
    printf "${GIT_MESSAGE}" ${NEW_RELEASE} ${NEW_VERSION}
  fi
}

function ::has_docker() {
  command -v docker &> /dev/null
}

function ::build_method() {
  case $(uname -o) in
  Msys|Cygwin) : ;;
  *) ::has_docker && BUILD_METHOD=docker || : ;;
  esac
}

function ::build_with_powershell() {
  ${POWERSHELL} \
    -ExecutionPolicy ByPass \
    -File Other/Update/Update.ps1 \
    ${CHECKSUM:--UpdateChecksums}
}

function ::build_with_docker() {
  ${SCRIPT_DIR}/docker-build.sh --up-release
}

function ::escape_regex() {
  local string=${1}
  string=${string//\./\\.}
  string=${string//\+/\\+}
  string=${string//\*/\\*}
  echo ${string}
}

# -----------------------------------------------------------------------------
# Github section
# -----------------------------------------------------------------------------
function github::fetch_releases() {
  curl \
    --silent \
    --header "Accept: application/vnd.github+json" \
    https://api.github.com/repos/${GITHUB_PATH}/releases
}

function github::releases() {
  [[ ${USE_GITHUB} == false ]] && return 0
  (( ${#GITHUB_RELEASES[@]} == 0 )) && \
    readarray GITHUB_RELEASES <<< $(github::fetch_releases)
  echo "${GITHUB_RELEASES[@]}"
}

function github::release_name() {
   local filter=${1:-}
   github::releases | \
   jq -r "[ .[].name | select(. = contains(\"${filter}\")) ] | first"
}

function github::new_version() {
   local filter=${1:-}
   github::release_name "${filter}" | \
   sed \
     -e 's/[^0-9+-.\(jp\|rc\)]//g' \
     -e 's/(\([0-9]*\))/.\1/g' \
     -e 's/^[^0-9]//'
}

function github::pattern() {
  awk -F "[ =]*" '/GithubAsset/ {print $2}' ${UPDATE_INI}
}

function github::browser_download_url() {
  local name=$(github::release_name)
  local pattern=$(github::pattern)
  [[ -z ${pattern} ]] && return 0
  github::releases |
  jq -r ".[] | \
    select( .name == \"${name}\" ) | \
    .assets[] | \
    select( .name | match(\"${pattern}\") ) | \
    .browser_download_url"
}

function github::prerelease() {
  local query='.[] | select(.name == "%s") | .prerelease'
  github::releases | \
    jq -r "$(printf "${query}" "$(github::release_name)")" | \
    grep -i true || :
}

# -----------------------------------------------------------------------------
# Preparation section
# -----------------------------------------------------------------------------
function prep::github_releases() {
  # fetch the github releases json if GITHUB_PATH is set
  github::releases >/dev/null
}

function prep::format_package_version() {
  local    package_version=${NEW_VERSION//[^0-9.-]/}
  local -a package_tokens=( ${package_version//[-.]/ } )
  [[ -n ${ITERATION} ]] && package_tokens[3]=${ITERATION}
  NEW_PACKAGE=$(printf "%d.%d.%d.%d" ${package_tokens[@]})
}

function prep::define_release_variables() {
  OLD_RELEASE=$(git describe --abbrev=0 --tags)
  OLD_PACKAGE=$(awk -F "[= ]*" '/^Package/ { print $2 }' ${UPDATE_INI})
  OLD_DISPLAY=$(awk -F "[= ]*" '/^Display/ { print $2 }' ${UPDATE_INI})
  [[ ${USE_GITHUB} == true ]] &&
    NEW_VERSION=$(github::new_version "${NEW_VERSION:-}")
  [[ -n ${NEW_VERSION} ]] &&
    NEW_RELEASE=${OLD_RELEASE/${OLD_VERSION}/${NEW_VERSION}}
  [[ ${NEW_RELEASE:0:1} != v ]] && NEW_RELEASE=v${NEW_RELEASE}
  if [[ ! ${OLD_RELEASE} =~ ${OLD_VERSION//+/\\+} ]]; then
    echo "'${OLD_RELEASE}' from git tags does not match with provided '${OLD_VERSION}'"
    exit 255
  fi
  [[ -n ${GITHUB_PATH} && -z ${PRE_RELEASE} ]] && \
    PRE_RELEASE=$(github::prerelease)
  prep::format_package_version
  NEW_DISPLAY=${NEW_RELEASE/#[a-z]/}
}

function prep::find_default_branch() {
  # prefer master over main
  local -a branches=( $(git branch | grep -oE "\<(master|main)\>" | sort -r) )
  DEFAULT_BRANCH="${branches[0]}"
}

function prep::sync_default_branch() {
  prep::find_default_branch
  git checkout "${DEFAULT_BRANCH}"
  git pull origin "${DEFAULT_BRANCH}"
}

function prep::compare_versions() {
  if [[ ${OLD_VERSION} == ${NEW_VERSION} ]]; then
    printf "\n\nThe current (%s) and new (%s) version are the same.\n\n" \
      "${OLD_VERSION}" "${NEW_VERSION}"
    exit 0
  fi
}

function prep::print_variables() {
  local -a fields=(
    BUILD_METHOD
    {NEW,OLD}_{PACKAGE,RELEASE,VERSION,DISPLAY}
    PRE_RELEASE
  )
  printf "\nVariables:\n"
  for var in ${fields[@]}; do
    printf " - %-12s '%s'\n" "${var}:" "${!var}"
  done
}

# -----------------------------------------------------------------------------
# Patch section
# -----------------------------------------------------------------------------
function patch::create_branch() {
  local checkout_option=""
  if ! git branch | grep -q "release/${NEW_RELEASE}"; then
    checkout_option="-b"
  fi
  git checkout ${checkout_option} release/${NEW_RELEASE}
}

function patch::browser_download_url() {
  [[ ${USE_GITHUB} == false ]] && return 0 || :
  local url=$(github::browser_download_url)
  [[ -z ${url} ]] && return 0 || :
  local pattern=$(github::pattern)
  sed -r -i -e "/^URL/s|= .*${pattern}.*|= ${url}|" ${UPDATE_INI}
}

function patch::exlude_url() {
  case ${USE_GITHUB} in
  false) : ;;
  true) echo '|URL' ;;
  esac
}

function patch::create_release() {
  local old_version=$(::escape_regex "${OLD_VERSION}")
  local exclude="^(Upstream|Package$(patch::exclude_url))"
  patch::browser_download_url
  sed -r -i \
    -e "/^Package/s/${OLD_PACKAGE}/${NEW_PACKAGE}/" \
    -e "/${exclude}/!s/${old_version}\>/${NEW_VERSION}/g" \
    -e "/${exclude}/!s/${old_version%%-*}\>/${NEW_VERSION%%-*}/g" \
    -e "/${exclude}/!s/${old_version//+/}\>/${NEW_VERSION//+}/g" \
    -e "/${exclude}/!s/${old_version//+-/+}\>/${NEW_VERSION//+-/+}/g" \
    -e "/${exclude}/!s/\<${OLD_VERSION//\./}\>/${NEW_VERSION//\./}/g" \
    -e '/^Display/'"s/=.*/= ${NEW_DISPLAY}/g" \
    ${UPDATE_INI}
  patch::update_checksum
}

function patch::update_checksum() {
  [[ -z ${CHECKSUM} ]] && return 0
  sed -r -i \
    -e "/^Checksum1/s/(.*)::.*/\\1::${CHECKSUM}/" \
    ${UPDATE_INI}
}

# -----------------------------------------------------------------------------
# Build section
# -----------------------------------------------------------------------------
function build::build_release() {
  case ${BUILD_METHOD} in
  docker) ::build_with_docker;;
  *)      ::build_with_powershell;;
  esac
}

function build::update_upstream() {
  local old_version=${1}
  sed -r -i \
    -e "/^Upstream/s/=.*/= ${NEW_VERSION}/g" \
    ${UPDATE_INI}
}

function build::commit_release() {
  git diff --exit-code || \
    git commit \
      --all \
      --message "$(::message)"
}

function build::create_release_tag() {
  # clean tag if already exits
  if git tag | grep ${NEW_RELEASE}; then
    git tag --delete ${NEW_RELEASE}
  fi
  git tag ${NEW_RELEASE}
}

function build::release() {
  build::build_release
  build::update_upstream "$(::escape_regex "${OLD_VERSION}")"
  build::commit_release
  build::create_release_tag
}

# -----------------------------------------------------------------------------
# PR section
# -----------------------------------------------------------------------------
function pr::wait_for_ci_status() {
  for count in {1..20}; do
    hub ci-status | grep -q success && return 0
    sleep 60
  done
  echo timeout of 20 minutes reached!
  return 1
}

function pr::push_release() {
  git push origin release/${NEW_RELEASE}
  git push origin ${NEW_RELEASE}
}

function pr::create_pull_request() {
  pr::push_release
  hub pull-request -b "${DEFAULT_BRANCH}" -m "$(::message)"
}

# -----------------------------------------------------------------------------
# Release section
# -----------------------------------------------------------------------------
function release::to_github() {
  ${SCRIPT_DIR}/pa-github-release.sh \
    ${PRE_RELEASE:+--pre-release} \
    --tag ${NEW_RELEASE} \
    --message "$(message)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
::parse_options "${@}"
::verify_options
::build_method
::run_stages ${STAGE}

# vim: set shiftwidth=2 softtabstop=2 expandtab :
