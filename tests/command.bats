#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

#Uncomment to enable stub debug output:
#export BUILDKITE_AGENT_STUB_DEBUG='/dev/tty'

# you can set variables common to all tests here
export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS='Value'

@test "Missing mandatory option fails" {
  unset $BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS
  export BUILDKITE_REPO_SSH_HOST='value'
  export SSH_KNOWN_HOSTS='value'

  stub ssh-keyscan \
    "[[ -d ~/.ssh ]] || mkdir -p ~/.ssh" \
    "$BUILDKITE_REPO_SSH_HOST" >> "$SSH_KNOWN_HOSTS"

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
  unstub ssh-keyscan 
}
