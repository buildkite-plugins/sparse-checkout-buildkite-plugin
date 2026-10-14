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

@test "clean_checkout only-upon-failure uses normal git clean when sparse-checkout succeeds" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="only-upon-failure"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean -ffxdq : echo 'git clean normal'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'checkout'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'only-upon-failure'
  assert_output --partial 'git clean normal'
  refute_output --partial 'clean_checkout is enabled'
  refute_output --partial 'performing aggressive clean checkout and retrying'
  refute_output --partial 'git reset hard'

  unstub ssh-keyscan
  unstub git
}

@test "clean_checkout only-upon-failure retries with aggressive clean after checkout failure" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="only-upon-failure"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean -ffxdq : echo 'git clean normal'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : echo 'error: Your local changes' >&2; exit 1"
  stub git "reset --hard HEAD : echo 'git reset hard'"
  stub git "clean -ffxdq : echo 'git clean aggressive'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout retry'"
  stub git "checkout * : echo 'checkout success'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'performing aggressive clean checkout and retrying'
  assert_output --partial 'git reset hard'
  assert_output --partial 'git clean aggressive'
  assert_output --partial 'git sparse-checkout retry'
  assert_output --partial 'checkout success'

  unstub ssh-keyscan
  unstub git
}

@test "clean_checkout only-upon-failure fails if retry after aggressive clean still fails" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="only-upon-failure"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean -ffxdq : echo 'git clean'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout'"
  stub git "checkout * : exit 1"
  stub git "reset --hard HEAD : echo 'git reset hard'"
  stub git "clean -ffxdq : echo 'git clean aggressive'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout retry'"
  stub git "checkout * : exit 1"

  run "$PWD"/hooks/checkout

  assert_failure
  assert_output --partial 'performing aggressive clean checkout and retrying'
  assert_output --partial 'Failed to checkout dummy-commit-hash'

  unstub ssh-keyscan
  unstub git
}

@test "clean_checkout only-upon-failure retries after sparse-checkout set failure" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_CLEAN_CHECKOUT="only-upon-failure"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git "clean -ffxdq : echo 'git clean normal'"
  stub git "fetch --depth 1 origin * : echo 'git fetch'"
  stub git "sparse-checkout set * * : exit 1"
  stub git "reset --hard HEAD : echo 'git reset hard'"
  stub git "clean -ffxdq : echo 'git clean aggressive'"
  stub git "sparse-checkout set * * : echo 'git sparse-checkout retry'"
  stub git "checkout * : echo 'checkout success'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Failed to configure sparse-checkout'
  assert_output --partial 'performing aggressive clean checkout and retrying'
  assert_output --partial 'git sparse-checkout retry'

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
  assert_output --partial 'Attempt 1/3 failed with status 1; retrying in 2s'
  assert_output --partial 'Attempt 2/3 failed with status 1; retrying in 5s'
  assert_output --partial 'git fetch merge refspec'
  assert_output --partial 'checkout fetch_head'

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

@test "Propagates git's real exit status when fetching the commit fails" {
  stub ssh-keyscan "* : echo 'keyscan'"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'fatal: shallow file has changed since we read it' >&2; exit 128"

  run "$PWD"/hooks/checkout

  assert_failure 128
  assert_output --partial 'fatal: shallow file has changed since we read it'
  assert_output --partial 'Failed to fetch dummy-commit-hash from origin'

  unstub ssh-keyscan
  unstub git
}

@test "Retries a failed commit fetch before succeeding" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_FETCH_ATTEMPTS="6"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep "* : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git fetch commit'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout dummy-commit-hash : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Attempt 1/6 failed with status 128; retrying in 1.'
  assert_output --partial 'git fetch commit'
  assert_output --partial 'checkout commit'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Fails with git's exit status after fetch_attempts commit fetches" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_FETCH_ATTEMPTS="3"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "* : true" \
    "* : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128"

  run "$PWD"/hooks/checkout

  assert_failure 128
  assert_output --partial 'Attempt 2/3 failed with status 128; retrying in 2.'
  assert_output --partial 'Failed to fetch dummy-commit-hash from origin'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Ignores BUILDKITE_CHECKOUT_ATTEMPTS and fetches once by default" {
  export BUILDKITE_CHECKOUT_ATTEMPTS="6"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128"

  run "$PWD"/hooks/checkout

  assert_failure 128
  refute_output --partial 'retrying in'
  assert_output --partial 'Failed to fetch dummy-commit-hash from origin'

  unstub ssh-keyscan
  unstub git
}

@test "Retries a failed clone" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_FETCH_ATTEMPTS="2"
  local hook="$PWD/hooks/checkout"
  cd "$BATS_TEST_TMPDIR"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep "* : true"
  stub git \
    "clone --depth 1 --filter=blob:none --no-checkout -v git@github.com:example/repo.git . : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "clone --depth 1 --filter=blob:none --no-checkout -v git@github.com:example/repo.git . : echo 'git clone'" \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin dummy-commit-hash : echo 'git fetch commit'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout dummy-commit-hash : echo 'checkout commit'"

  run "$hook"

  assert_success
  assert_output --partial 'Attempt 1/2 failed with status 128; retrying in 1.'
  assert_output --partial 'Repository cloned successfully'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Retries a failed merge ref fetch" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep "* : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git fetch merge refspec'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout FETCH_HEAD : echo 'checkout fetch_head'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Attempt 1/3 failed with status 128; retrying in 1.'
  assert_output --partial 'checkout fetch_head'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Fails with git's exit status after merge_ref_retry_attempts merge ref fetches" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_MERGE_REF_RETRY_ATTEMPTS="2"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep "* : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128"

  run "$PWD"/hooks/checkout

  assert_failure 128
  assert_output --partial 'Attempt 1/2 failed with status 128'
  assert_output --partial 'Failed to fetch merge ref for PR #123 from origin'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Falls back to the commit when the merge ref is still missing" {
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
    "fetch --depth 1 origin abc123 : echo 'git fetch commit'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'falling back to abc123'
  assert_output --partial 'checkout commit'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Fails when the last merge ref error is not a missing ref" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "2 : true" \
    "5 : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128"

  run "$PWD"/hooks/checkout

  assert_failure 128
  assert_output --partial 'Failed to fetch merge ref for PR #123 from origin'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Falls back to the commit when the last merge ref error is a missing ref" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep \
    "* : true" \
    "2 : true"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin refs/pull/123/merge : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin refs/pull/123/merge : echo \"fatal: couldn't find remote ref refs/pull/123/merge\" >&2; exit 1" \
    "fetch --depth 1 origin abc123 : echo 'git fetch commit'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'Attempt 1/3 failed with status 128; retrying in 1.'
  assert_output --partial 'Attempt 2/3 failed with status 1; retrying in 2s'
  assert_output --partial 'falling back to abc123'
  assert_output --partial 'checkout commit'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "merge_ref_retry_attempts 0 skips the merge ref" {
  export BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC="true"
  export BUILDKITE_PULL_REQUEST="123"
  export BUILDKITE_COMMIT="abc123"
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_MERGE_REF_RETRY_ATTEMPTS="0"

  stub ssh-keyscan "* : echo 'keyscan'"
  stub git \
    "clean * : echo 'git clean'" \
    "fetch --depth 1 origin abc123 : echo 'git fetch commit'" \
    "sparse-checkout set * * : echo 'git sparse-checkout'" \
    "checkout abc123 : echo 'checkout commit'"

  run "$PWD"/hooks/checkout

  assert_success
  assert_output --partial 'falling back to abc123'
  assert_output --partial 'checkout commit'

  unstub ssh-keyscan
  unstub git
}

@test "Caps fetch_attempts at 10" {
  export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_FETCH_ATTEMPTS="15"

  local fetches=() sleeps=()
  for _ in {1..10}; do
    fetches+=("fetch --depth 1 origin dummy-commit-hash : echo 'git@github.com: Permission denied (publickey).' >&2; exit 128")
  done
  for _ in {1..9}; do
    sleeps+=("* : true")
  done

  stub ssh-keyscan "* : echo 'keyscan'"
  stub sleep "${sleeps[@]}"
  stub git "clean * : echo 'git clean'" "${fetches[@]}"

  run "$PWD"/hooks/checkout

  assert_failure 128
  assert_output --partial 'Capping 15 attempts at the maximum of 10'
  assert_output --partial 'Attempt 9/10 failed with status 128; retrying in 256.'
  assert_output --partial 'Failed to fetch dummy-commit-hash from origin'

  unstub sleep
  unstub ssh-keyscan
  unstub git
}

@test "Rejects fetch_attempts that is not a whole number of at least 1" {
  for value in six 6s 1.5 0 -1 08; do
    export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_FETCH_ATTEMPTS="${value}"

    run "$PWD"/hooks/checkout

    assert_failure 1
    assert_output --partial "fetch_attempts must be a whole number of at least 1, got '${value}'"
  done
}

@test "Rejects merge_ref_retry_attempts that is not a whole number of at least 0" {
  for value in three 3s 1.5 -1 08; do
    export BUILDKITE_PLUGIN_SPARSE_CHECKOUT_MERGE_REF_RETRY_ATTEMPTS="${value}"

    run "$PWD"/hooks/checkout

    assert_failure 1
    assert_output --partial "merge_ref_retry_attempts must be a whole number of at least 0, got '${value}'"
  done
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
