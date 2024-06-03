#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export BUILDKITE_AGENT_STUB_DEBUG='/dev/tty'

# Set variables common to all tests here
export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS='Value'

setup() {
  export ORIGINAL_KNOWN_HOSTS=~/.ssh/known_hosts
  export TEST_KNOWN_HOSTS=$(mktemp)
  export BUILDKITE_REPO_SSH_HOST='Value'

  # Backup the original known_hosts file
  if [ -f "$ORIGINAL_KNOWN_HOSTS" ]; then
    cp "$ORIGINAL_KNOWN_HOSTS" "$ORIGINAL_KNOWN_HOSTS.bak"
  fi

  # Point to the temporary known_hosts file
  export SSH_KNOWN_HOSTS="$TEST_KNOWN_HOSTS"
}

teardown() {
  # Restore the original known_hosts file
  if [ -f "$ORIGINAL_KNOWN_HOSTS.bak" ]; then
    mv "$ORIGINAL_KNOWN_HOSTS.bak" "$ORIGINAL_KNOWN_HOSTS"
  fi

  # Remove the temporary known_hosts file
  rm -f "$TEST_KNOWN_HOSTS"
}

# Function to mock ssh-keyscan if it's not available
mock_ssh_keyscan() {
  if ! command -v ssh-keyscan &> /dev/null; then
    cat <<'EOF' > /tmp/ssh-keyscan
#!/bin/bash
echo "# SSH-2.0-mock_ssh_keyscan"
EOF
    chmod +x /tmp/ssh-keyscan
    export PATH="/tmp:$PATH"
  fi
}

@test "Test mandatory option success" {
  mock_ssh_keyscan
  
  run ssh-keyscan "$BUILDKITE_REPO_SSH_HOST" >> "$SSH_KNOWN_HOSTS"
  assert_success
  [ -f "$SSH_KNOWN_HOSTS" ]

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'mandatory option given'
  refute_output --partial 'Running plugin'
}

@test "Missing mandatory option fails" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'Missing mandatory option'
  refute_output --partial 'Running plugin'
}
