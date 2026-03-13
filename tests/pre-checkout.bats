#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  HOOK_DIR="$PWD"
}

@test "Cleanup worktree config enabled - cleans up stale sparse config before checkout" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "$work_dir/.git"
  echo '[core]' > "$work_dir/.git/config.worktree"

  stub git \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$work_dir"
  run "$HOOK_DIR/hooks/pre-checkout"
  cd "$HOOK_DIR"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
  assert_output --partial 'Sparse-checkout config cleaned up'
  [[ ! -f "$work_dir/.git/config.worktree" ]]

  unstub git
  rm -rf "$work_dir"
}

@test "Cleanup worktree config enabled - succeeds even when no prior sparse config exists" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "$work_dir/.git"

  stub git \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$work_dir"
  run "$HOOK_DIR/hooks/pre-checkout"
  cd "$HOOK_DIR"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
  assert_output --partial 'Sparse-checkout config cleaned up'

  unstub git
  rm -rf "$work_dir"
}

@test "Cleanup worktree config enabled - skips when no .git directory exists yet" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  local work_dir
  work_dir="$(mktemp -d)"

  cd "$work_dir"
  run "$HOOK_DIR/hooks/pre-checkout"
  cd "$HOOK_DIR"

  assert_success
  assert_output --partial 'No .git directory found, skipping sparse-checkout config cleanup'
  refute_output --partial 'Cleaning up sparse-checkout config'

  rm -rf "$work_dir"
}

@test "Cleanup worktree config enabled via SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG env var" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG
  export SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "$work_dir/.git"

  stub git \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$work_dir"
  run "$HOOK_DIR/hooks/pre-checkout"
  cd "$HOOK_DIR"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'

  unstub git
  rm -rf "$work_dir"
}

@test "Cleanup worktree config not configured - does nothing" {
  run "$HOOK_DIR/hooks/pre-checkout"

  assert_success
  refute_output --partial 'sparse-checkout config'
}
