#!/usr/bin/env bash

declare -r BASE_DIR=$(readlink --canonicalize $(dirname ${0})/..)
declare -r TIMESTAMP=$(date +%F)

cd ${BASE_DIR} && for dir in *Portable; do 
  ( 
     set -o errexit
     cd ${dir}
     git checkout master
     git pull origin master
     for repo in $(git branch | grep -v master); do 
       git branch -d ${repo} && git push origin :${repo} || :
     done
   )
done
