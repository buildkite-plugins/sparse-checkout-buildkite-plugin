#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_MANDATORY='Value'
  export path='Value
}

@test "Build without a repository" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_BUILD=myservice


  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial "built myservice"


}