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
declare -r BASE_DIR=$(readlink -f $(dirname ${0})/..)
declare -r SCRIPT_DIR=$(readlink -f $(dirname $0))
declare -r UPDATE_SCRIPT=Update.ps1
declare -r DIVIDER=$(printf "%0.1s" -{1..80})

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function file_list() {
  find ${BASE_DIR} \
    -type f \
    -name ${UPDATE_SCRIPT} \
    -path "${BASE_DIR}/*Portable/*" | \
    sort
}

# -----------------------------------------------------------------------------

function build_package() {
  script=${1}; shift;
  name=${script#${BASE_DIR}/}
  name=${name%%/*}
  echo 
  echo ${DIVIDER}
  echo ${name} 
  echo ${DIVIDER}
  pwsh -ExecutionPolicy ByPass ${script}
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
build_all_packages
