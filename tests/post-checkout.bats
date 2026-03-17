#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  HOOK_DIR="$PWD"
}

teardown() {
  cd "$HOOK_DIR" 2>/dev/null || true
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
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

@test "Cleanup worktree config enabled - removes config.worktree and unsets all sparse config keys" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"
  mkdir -p "$WORK_DIR/.git"
  echo '[core]' > "$WORK_DIR/.git/config.worktree"

  stub git \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/post-checkout"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
  assert_output --partial 'Sparse-checkout config cleaned up'
  [[ ! -f "$WORK_DIR/.git/config.worktree" ]]
}

@test "Cleanup worktree config enabled - succeeds even when no prior sparse config exists" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"
  mkdir -p "$WORK_DIR/.git"

  stub git \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/post-checkout"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
  assert_output --partial 'Sparse-checkout config cleaned up'
}

@test "Cleanup worktree config enabled - skips when no .git directory" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/post-checkout"

  assert_success
  assert_output --partial 'No .git directory found, skipping sparse-checkout config cleanup'
  refute_output --partial 'Cleaning up sparse-checkout config'
}

@test "Cleanup worktree config enabled via SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG env var" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG
  export SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"
  mkdir -p "$WORK_DIR/.git"

  stub git \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/post-checkout"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
}

@test "Cleanup worktree config not configured - no cleanup runs" {
  run "$HOOK_DIR"/hooks/post-checkout

  assert_success
  refute_output --partial 'sparse-checkout config'
}

@test "Unshallow enabled but fetch fails exits with error" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_POST_CHECKOUT_UNSHALLOW="true"

  stub git "rev-parse --is-shallow-repository : echo 'true'" \
           "fetch --unshallow origin : exit 1"

  run "$HOOK_DIR"/hooks/post-checkout

  assert_failure
  assert_output --partial 'Failed to unshallow repository'
}
