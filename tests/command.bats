#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

# you can set variables common to all tests here
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS='Value'




@test "Test mandatory option fails" {
  set BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS='Value'

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial ' mandatory option given'
  refute_output --partial 'Running plugin'
}


@test "Missing mandatory option fails" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
}
