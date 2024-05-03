#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_YOUR_PLUGIN_NAME_MANDATORY='Value'
}

@test "Missing mandatory option fails" {
  unset BUILDKITE_PLUGIN_YOUR_PLUGIN_NAME_MANDATORY

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
}

@test "Normal basic operations" {
  unset BUILDKITE_PLUGIN_PLUGIN_TESTER_VERSION



  run "$PWD"/hooks/command

  assert_success
  assert_output --partial 'docker ran with'
  assert_output --partial " -v $PWD:/plugin "
  assert_output --partial " buildkite/plugin-tester:${LATEST_VERSION} bats tests"


}