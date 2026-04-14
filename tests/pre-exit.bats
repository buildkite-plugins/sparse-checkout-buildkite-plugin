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

@test "Cleanup worktree config enabled - removes config.worktree and unsets all sparse config keys" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"
  mkdir -p "$WORK_DIR/.git"
  echo '[core]' > "$WORK_DIR/.git/config.worktree"

  stub git \
    "ls-files -t : true" \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/pre-exit"

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
    "ls-files -t : true" \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/pre-exit"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
  assert_output --partial 'Sparse-checkout config cleaned up'
}

@test "Cleanup worktree config enabled - skips when no .git directory" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/pre-exit"

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
    "ls-files -t : true" \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/pre-exit"

  assert_success
  assert_output --partial 'Cleaning up sparse-checkout config'
}

@test "Cleanup worktree config enabled - clears skip-worktree bits from index" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEANUP_WORKTREE_CONFIG="true"

  WORK_DIR="$(mktemp -d)"
  mkdir -p "$WORK_DIR/.git"

  stub git \
    "ls-files -t : echo 'S lib/excluded.rb'" \
    "update-index --no-skip-worktree -- lib/excluded.rb : true" \
    "config --unset extensions.worktreeConfig : true" \
    "config --unset core.sparseCheckout : true" \
    "config --unset core.sparseCheckoutCone : true"

  cd "$WORK_DIR"
  run "$HOOK_DIR/hooks/pre-exit"

  assert_success
  assert_output --partial 'Sparse-checkout config cleaned up'
}

@test "Cleanup worktree config not configured - no cleanup runs" {
  run "$HOOK_DIR/hooks/pre-exit"

  assert_success
  refute_output --partial 'sparse-checkout config'
}
