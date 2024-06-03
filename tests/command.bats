#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

# you can set variables common to all tests here
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS='Value'
  export BUILDKITE_REPO_SSH_HOST='Value'
  export SSH='Value'



@test "Test mandatory option success" {


  stub ssh \
    "mkdir -p ~/.ssh; ssh-keyscan github.com >> ~/.ssh/known_hosts; [[ -f ~/.ssh/known_hosts ]]"
  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial ' mandatory option given'
  refute_output --partial 'Running plugin'

  unstub ssh
}


@test "Missing mandatory option fails" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
}
