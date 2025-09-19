#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS="default_path"
  export BUILDKITE_REPO_SSH_HOST="default_host"
  export BUILDKITE_COMMIT="dummy-commit-hash"
}

@test "Skip ssh-keyscan when option provided" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN="true"

  stub git "clean \* : echo 'git clean'"
  stub git "fetch --depth 1 origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'" 
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Skipped SSH keyscan'

  unstub git
}

@test "Run ssh-keyscan when no option provided" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN
  
  stub ssh-keyscan "\* : echo 'keyscan'"
  stub git "clean \* : echo 'git clean'"
  stub git "fetch --depth 1 origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'" 
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Scanning SSH keys for remote git repository'
  
  unstub git
  unstub ssh-keyscan
}

@test "Run ssh-keyscan when BUILDKITE_REPO_SSH_HOST is defined" {
  unset BUILDKITE_PLUGIN_SPARSE_CHECKOUT_SKIP_SSH_KEYSCAN
  export BUILDKITE_REPO_SSH_HOST="github.com"

  stub ssh-keyscan "\* : echo 'keyscan'"
  stub git "clean \* : echo 'git clean'"
  stub git "fetch --depth 1 origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'"
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Scanning SSH keys for remote git repository'

  unstub git
  unstub ssh-keyscan
}

@test "Skip ssh-keyscan when BUILDKITE_REPO_SSH_HOST is unset" {
  unset BUILDKITE_REPO_SSH_HOST

  stub git "clean \* : echo 'git clean'"
  stub git "fetch --depth 1 origin \* : echo 'git fetch'"
  stub git "sparse-checkout set \* \* : echo 'git sparse-checkout'"
  stub git "checkout \* : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Skipped SSH keyscan'

  unstub git
}

@test "Respects BUILDKITE_GIT_FETCH_FLAGS in git fetch" {
  export BUILDKITE_GIT_FETCH_FLAGS="--prune --verbose"
  export BUILDKITE_COMMIT="HEAD"
  export BUILDKITE_BRANCH="main"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch --prune --verbose --depth 1 origin * : echo 'git fetch with flags'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch with flags'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout disabled - uses normal git clean" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="false"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean -ffxdq : echo 'git clean normal'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git clean normal'
  refute_output --partial 'Clean checkout enabled'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout enabled performs aggressive cleanup" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="true"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "reset --hard HEAD : echo 'git reset hard'"
  stub git "clean -ffxdq : echo 'git clean aggressive'"
  stub git "sparse-checkout disable : echo 'git sparse-checkout disable'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Clean checkout enabled - resetting repository state'
  assert_output --partial 'git reset hard'
  assert_output --partial 'git clean aggressive'
  assert_output --partial 'git sparse-checkout disable'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout handles repository without HEAD gracefully" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="true"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "reset --hard HEAD : exit 1"  # simulate failure
  stub git "clean -ffxdq : echo 'git clean'"
  stub git "sparse-checkout disable : echo 'sparse-checkout disable'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Clean checkout enabled - resetting repository state'
  assert_output --partial 'git clean'
  assert_output --partial 'sparse-checkout disable'

  unstub ssh-keyscan
  unstub git
}
