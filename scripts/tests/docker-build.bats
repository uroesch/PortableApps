#!/usr/bin/env bats

load includes

@test "docker-build.sh: Common option --help" {
  output=$(docker-build.sh --help 2>&1)
  [[ ${output} =~ ' --all ' ]]
  [[ ${output} =~ ' --build ' ]]
  [[ ${output} =~ ' --help' ]]
  [[ ${output} =~ ' --shell ' ]]
  [[ ${output} =~ ' --up-release ' ]]
  [[ ${output} =~ ' --version ' ]]
}

@test "docker-build.sh: Common option -h" {
  output=$(docker-build.sh -h 2>&1)
  [[ ${output} =~ ' -A ' ]]
  [[ ${output} =~ ' -b ' ]]
  [[ ${output} =~ ' -h ' ]]
  [[ ${output} =~ ' -s ' ]]
  [[ ${output} =~ ' -u ' ]]
  [[ ${output} =~ ' -V ' ]]
}

@test "docker-build.sh: Common option --version" {
  docker-build.sh --version | grep -w ${DOCKER_BUILD_VERSION}
}

@test "docker-build.sh: Common option -V" {
  docker-build.sh -V | grep -w ${DOCKER_BUILD_VERSION}
}
