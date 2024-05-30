#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

# you can set variables common to all tests here
  export BUILDKITE_BUILD_CHECKOUT_PATH='Value'


@test "Missing mandatory option fails" {
  unset BUILDKITE_BUILD_CHECKOUT_PATH

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
}

@test "Normal basic operations" {

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Running plugin with options'
  assert_output --partial '- mandatory: Value'
}

@test "Optional value changes behaviour" {
  export BUILDKITE_BUILD_CHECKOUT_PATH='other value'

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Running plugin with options'
  assert_output --partial '- optional: other value'
}