#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

declare -r BASE_DIR=$(readlink --canonicalize $(dirname ${0})/..)
declare -r TIMESTAMP=$(date +%F)
declare -r LINE=$(printf "%0.1s" -{1..80})

function pull_all() {
  local repo_name=${1}; shift;
  cd ${repo_name}
  print_header "${repo_name}"
  git checkout master
  git pull --rebase origin master
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


cd ${BASE_DIR} &&
  for repo_name in *Portable *Template; do
   ( pull_all "${repo_name}" )
  done
