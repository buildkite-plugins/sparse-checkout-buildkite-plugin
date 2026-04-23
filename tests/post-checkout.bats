#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  HOOK_DIR="$PWD"
}

teardown() {
  cd "$HOOK_DIR" 2>/dev/null || true
  unstub git 2>/dev/null || true
}

@test "Unshallow enabled and repo is shallow runs git fetch --unshallow" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'true'" \
           "fetch --unshallow origin : echo 'git fetch unshallow'"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  assert_output --partial 'Unshallowing repository'
  assert_output --partial 'Repository unshallowed successfully'
}

@test "Unshallow enabled and repo is not shallow skips unshallow" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'false'"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  assert_output --partial 'Repository is not shallow, skipping unshallow'
}

@test "Unshallow not configured skips post-checkout operations" {
  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  refute_output --partial 'Unshallowing repository'
}

@test "Unshallow enabled but fetch fails exits with error" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'true'" \
           "fetch --unshallow origin : exit 1"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_failure
  assert_output --partial 'Failed to unshallow repository'
}
