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
declare -r UPDATE_SCRIPT=Other/Update/Update.ps1
declare -r DIVIDER=$(printf "%0.1s" -{1..80})
declare -g DOCKER_IMAGE=uroesch/pa-wine:latest
declare -g BUILD_ALL=false
declare -a BUILD=()


# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}
  cat <<USAGE

  Usage:
    ${SCRIPT} [<options>]

  Options:
    -h | --help             This message
    -A | --all              Build all packages
    -b | --build <PA-name>  Build package with name
   
  Examples:
    Build all PortableApps packages in repository
    ${SCRIPT} --all 

    Build PortableApps package 'PlinkProxyPortable'
    ${SCRIPT} --build PlinkProxyPortable

    Build 'PlinkProxyPortable' by changing to directory
    cd PlinkProxyPortable && ../scripts/${SCRIPT} 

  Description:
    Builds PortableApps packages from Git repository
    'https://github.com/uroesch/PortableApps' via docker container.

USAGE
  exit ${exit_code}
}

# -----------------------------------------------------------------------------
function parse_options() {
  while (( ${#} > 0 )); do
    case ${1} in
    -A|--all)
      BUILD_ALL=true;;
    -b|--build) 
      shift;
      BUILD_ALL=false 
      BUILD+=( "${1}" )
      ;;
    -h|--help) 
      usage 0
      ;;
    *) 
      usage 1
      ;;
    esac
    shift
  done  
}

# -----------------------------------------------------------------------------

function file_list() {
  find ${BASE_DIR} \
    -maxdepth 1 \
    -type d \
    -path "${BASE_DIR}/*Portable" \
    -printf "%f\n" | \
    sort
}

# -----------------------------------------------------------------------------

function build_packages() {
  if [[ ${BUILD_ALL} == true ]]; then
    BUILD=( $(file_list) )
  elif (( ${#BUILD[@]} == 0 )); then
    name=$(pwd)
    case ${name} in
    *Portable) 
      build_on_docker ${name##*/}
      ;;
    *)
      printf "\n  No options specified an not in a *Portable directory!\n\n"
      exit 123
      ;;
    esac    
  fi
  
  for name in ${BUILD[@]}; do
    build_on_docker ${name}
  done
}

# -----------------------------------------------------------------------------

function build_on_docker() {
  local name=${1}
  printf "%s\n%s\n%s\n\n" "${DIVIDER}" "Building ${name}" "${DIVIDER}"
  docker run \
    --rm \
    --tty \
    --env USER_UID=$(id --user) \
    --env USER_GID=$(id --group) \
    --mount type=bind,src=${BASE_DIR},target=/PortableApps \
    --workdir=/PortableApps/${name} \
    ${DOCKER_IMAGE} \
    pwsh -ExecutionPolicy ByPass ${UPDATE_SCRIPT}
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
build_packages
