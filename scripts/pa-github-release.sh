#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
set -o errexit
set -o nounset
set -o pipefail
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
declare -r SCRIPT=${0##*/}
declare -r PACKAGE_NAME=$(basename $(pwd))
declare -g TAG=$(git describe --abbrev=0 --tags)
declare -g MESSAGE=
declare -g PRE_RELEASE=
declare -r DEFAULT_MESSAGE="%s\n\nUpstream release %s"
declare -r SUMS_FILE=${TMP_DIR:-/tmp}/sha256sums

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function usage() {
  local exit_code=${1:-1}; shift
  cat <<USAGE

  Usage: ${SCRIPT} <options>

  Options:
    -h | --help              This message
    -m | --message <message> New version string
    -p | --pre-release       Upload as pre-release
    -t | --tag <tag>         Tag to create release for
                             Default: '${TAG}'

USAGE
  exit ${exit_code}
}

function parse_options() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
    -t|--tag)         shift; TAG=${1};;
    -m|--message)     shift; MESSAGE=${1};;
    -p|--pre-release) PRE_RELASE=true;;
    -h|--help)        usage 0;;
    *)                usage 1;;
    esac
    shift
  done
}

function message() {
  if [[ -n $MESSAGE ]]; then
    # prepend message with tag if not on first line
    if [[ ! ${MESSAGE} =~ ^${TAG} ]]; then
      printf "${TAG}\n\n"
    fi
    printf "${MESSAGE}"
  else
    printf "${DEFAULT_MESSAGE}" ${TAG} ${TAG}
  fi
}

function find_installer() {
  local release=${TAG:1:1000}
  find ../ \
    -type f \
    -name "${PACKAGE_NAME}_${release//[+]/*}*.paf.exe"
}

function create_checksums() {
  local files="${@}"
  for file in ${files}; do
    sha256sum ${file} | awk '{print $1}' > ${file}.sha256
  done
  # create file for uploading
  sha256sum ${files} | \
    awk '{ print gensub("../", "", "g") }' \
    > ${SUMS_FILE}
  # echo sums for inline table
  awk '{ print $2, $1 }' ${SUMS_FILE}
}

function assemble_release_message() {
  local cell_width=64
  local line=$(eval printf "%0.1s" -{1..${cell_width}})
  local table_format="| %-${cell_width}s | %-${cell_width}s |\n"
  printf "$(message)"
  printf "\n\n${table_format}" Filename SHA-256
  printf "${table_format}" ${line} ${line}
  printf "${table_format}" $(create_checksums $(find_installer))
}

function create_release() {
  local options=""
  case ${TAG} in
  *beta*|*alpha*|*rc*) options="${options} -p";;
  esac
  assemble_release_message
  hub release create \
     ${PRE_RELEASE:+-p} \
     ${options} \
    -a $(find_installer) \
    -a $(find_installer).sha256 \
    -a ${SUMS_FILE} \
    -F <( assemble_release_message ) \
    ${TAG}
}

function cleanup() {
  [[ -f ${SUMS_FILE} ]] && rm ${SUMS_FILE}
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
parse_options "${@}"
create_release
