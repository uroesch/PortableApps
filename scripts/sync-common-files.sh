#!/usr/bin/env bash

declare -r BASE_DIR=$(readlink --canonicalize $(dirname ${0})/..)
declare -r TIMESTAMP=$(date +%F)

cd ${BASE_DIR} && for dir in *Portable; do 
  ( 
     set -o errexit
     cd ${dir}
     git checkout master
     git pull origin master
     git checkout -b sync/update-${TIMESTAMP}
     rsync -av ../CommonFiles/ . 
     git add . 
     git commit -a -m "Sync common files - ${TIMESTAMP}"
     git push origin sync/update-${TIMESTAMP}
     git checkout master
   )
done
