#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

#Uncomment to enable stub debug output:
export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

# you can set variables common to all tests here
export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS='Value'
  
@test "Test mandatory option success" {

  export SSH_KNOWN_HOSTS="TEST_KNOWN_HOSTS"
  export BUILDKITE_REPO_SSH_HOST='Value'
  run ssh-keyscan "$BUILDKITE_REPO_SSH_HOST" >> $SSH_KNOWN_HOSTS; [[ -f $SSH_KNOWN_HOSTS]]
  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial ' mandatory option given'
  refute_output --partial 'Running plugin'

}


@test "Missing mandatory option fails" {
  unset $BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
}
