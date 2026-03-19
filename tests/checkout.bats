#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_PATHS="default_path"
  export BUILDKITE_REPO_SSH_HOST="default_host"
  export BUILDKITE_COMMIT="dummy-commit-hash"
  export BUILDKITE_REPO="git@github.com:example/repo.git"
  mkdir -p .git
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
  assert_output --partial 'Scanning SSH keys'

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
  assert_output --partial 'Scanning SSH keys'

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
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Clean checkout enabled - resetting repository state'
  assert_output --partial 'git reset hard'
  assert_output --partial 'git clean aggressive'
  refute_output --partial 'git sparse-checkout disable'

  unstub ssh-keyscan
  unstub git
}

@test "Fetches pull request merge refspec when BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC is true" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="HEAD"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch --depth 1 origin refs/pull/123/merge : echo 'git fetch merge refspec'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

  unstub ssh-keyscan
  unstub git
}

@test "Fetches pull request merge refspec with known commit" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="456"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch --depth 1 origin refs/pull/456/merge : echo 'git fetch merge refspec'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

  unstub ssh-keyscan
  unstub git
}

@test "Retries missing merge ref before succeeding" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "2 : true" \
    "5 : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git fetch merge refspec'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'retrying in 2s'
  assert_output --partial 'retrying in 5s'
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Falls back to the branch when BUILDKITE_COMMIT is HEAD" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="HEAD"
  export BUILDKITE_BRANCH="feature-branch"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "2 : true" \
    "5 : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin feature-branch : echo 'git fetch fallback branch'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'falling back to branch feature-branch'
  assert_output --partial 'git fetch fallback branch'
  assert_output --partial 'checkout fetch_head'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Fails when the head commit fallback fetch fails" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "2 : true" \
    "5 : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin abc123 : echo 'fatal: bad object abc123' >&2; exit 1"

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'falling back to abc123'
  assert_output --partial 'Failed to fetch fallback commit abc123 from origin'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Does not use merge refspec when BUILDKITE_PULL_REQUEST is false" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="false"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch --depth 1 origin abc123 : echo 'git fetch commit'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch commit'
  assert_output --partial 'checkout commit'

  unstub ssh-keyscan
  unstub git
}

@test "Does not use merge refspec when flag is not set" {
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"
  unset BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean * : echo 'git clean'"
  stub git "fetch --depth 1 origin abc123 : echo 'git fetch commit'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'git fetch commit'
  assert_output --partial 'checkout commit'

  unstub ssh-keyscan
  unstub git
}

@test "Clean checkout handles repository without HEAD gracefully" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="true"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "reset --hard HEAD : exit 1"
  stub git "clean -ffxdq : echo 'git clean'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Clean checkout enabled - resetting repository state'
  assert_output --partial 'git clean'
  refute_output --partial 'sparse-checkout disable'

  unstub ssh-keyscan
  unstub git
}
