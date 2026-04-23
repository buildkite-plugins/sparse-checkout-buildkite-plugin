# Sparse Checkout Buildkite Plugin [![Build status](https://badge.buildkite.com/f846f6eca370c461286ba3de8e7def04b16e00cd1b85b58b23.svg)](https://buildkite.com/buildkite/plugins-sparse-checkout)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for creating a sparse checkout of a repository.

This is useful for pipeline upload steps that dont need to access files outside the .buildkite directory. If your repository is large, this plugin will speed up your pipelines by only pulling the files relevant to the step.

## Configuration

These are all the options available to configure this plugin's behaviour.

### Required

#### `paths` (list of string)

Paths accepted by `git sparse-checkout set`.

### Optional

#### `no_cone` ('true' or 'false')

Whether to pass `--no-cone` to `git sparse-checkout` so that the paths are considered to be a list of patterns.

#### `skip_ssh_keyscan` ('true' or 'false')

Whether to skip ssh-keyscan step. This will skip adding each ssh public key into the known-hosts file. Only use if ssh keys are already setup.

#### `clean_checkout` ('true' or 'false')

Whether to perform aggressive repository cleanup before checkout. This option handles scenarios where interrupted or cancelled jobs leave the git repository in a corrupted state that would prevent checkout. When enabled, it removes git lock files, resets the repository with `git reset --hard HEAD`, and cleans all untracked files with `git clean -ffxdq`.

**What it fixes:**
- Stale git lock files (from interrupted operations)
- Corrupted git index
- Uncommitted changes in tracked files
- Untracked and ignored files

**⚠️ Warning:** This option will destroy ALL local changes and remove ALL untracked files. The `git clean -ffxdq` command with the `-x` flag will also remove ignored files (such as credentials, local configuration, or cache files). Only use this option when you're certain no important local data needs to be preserved.

Use this option for pipeline upload jobs that don't need to preserve local changes.

#### `cleanup_sparse_state` ('true' or 'false')

Tear down sparse-checkout state after the job finishes, so that subsequent jobs on the same agent that do **not** use sparse checkout are not affected.

When `git sparse-checkout` runs, it writes `.git/config.worktree` and sets `extensions.worktreeConfig`, `core.sparseCheckout`, and `core.sparseCheckoutCone` in git config. On agents with persistent build directories, this state persists across jobs — causing subsequent non-sparse jobs to silently inherit the sparse paths and fail to find files outside them.

In most setups you do not need this option. The plugin's `hooks/environment` already isolates sparse checkouts into a `-sparse`-suffixed build directory, so non-sparse jobs on the same agent land elsewhere and never see sparse state. Enable `cleanup_sparse_state` only when your agent configuration overrides `BUILDKITE_BUILD_CHECKOUT_PATH` after the plugin's env hook runs, causing sparse and non-sparse checkouts to share the same directory.

Cleanup runs at `pre-exit` after the job's command finishes, so the next job on the same directory starts clean. This runs regardless of job success or failure. Cleanup runs at `pre-exit` rather than `post-checkout` so that sparse state stays active for the duration of the job command.

A second pass runs at `pre-checkout` as a safety net for cases where a previous job's `pre-exit` never fired (for example, agent crashes or `SIGKILL`).

The cleanup removes `.git/config.worktree` and unsets `extensions.worktreeConfig`, `core.sparseCheckout`, and `core.sparseCheckoutCone`. The working tree files are left intact. This deliberately avoids `git sparse-checkout disable`, which re-materialises the full working tree (expensive on large monorepos).

#### `verbose` ('true' or 'false')

Enable verbose logging with bash execution tracing (`set -x`). This shows each command being executed and can help debug issues with ssh-keyscan, git operations, or other checkout problems. When enabled, you'll see detailed output including command arguments and any error messages from underlying tools.

#### `merge_ref_retry_attempts` (integer)

How many times to try fetching the GitHub pull-request merge ref (`refs/pull/<n>/merge`) when using merge-ref checkout (see `BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC` below). Defaults to `3`. Between attempts the hook waits 2 seconds after the first failure and 5 seconds after later failures. Set to `0` to skip merge-ref fetch attempts and fall back immediately.

#### `post_checkout` (object)

Options that run after the sparse checkout completes, in the `post-checkout` hook.

#### `unshallow` ('true' or 'false')

Convert the shallow clone into a full-depth clone by running `git fetch --unshallow origin` after checkout. This is useful when your build requires full git history (for example, changelog generation, `git log`, or `git blame`). If the repository is already unshallow, this step is skipped.

## Environment Variables

### BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC
When `BUILDKITE_PULL_REQUEST_USING_MERGE_REFSPEC=true`, the plugin will retry the
GitHub merge ref checkout if it sees the known "missing merge ref" failure, up to
`merge_ref_retry_attempts` times (default `3`). Between attempts it waits 2 seconds
after the first failure and 5 seconds after subsequent failures. If the merge ref
is still unavailable, it falls back to the normal non-merge-ref target
(`BUILDKITE_BRANCH` when `BUILDKITE_COMMIT=HEAD`, otherwise `BUILDKITE_COMMIT`).

This retry logic only applies to the specific merge-ref-not-ready error. Other
`git fetch` failures still fail immediately.


## Example

Below is an example of using sparse-checkout plugin.

```yaml
steps:
  - label: "Pipeline upload"
    command: "buildkite-agent pipeline upload"
    plugins:
      - sparse-checkout#v1.7.0:
          paths:
            - .buildkite
```

### Unshallowing the repository

If your build step requires full git history, enable the `unshallow` option under `post_checkout`:

```yaml
steps:
  - label: "Build with full history"
    command: "make changelog"
    plugins:
      - sparse-checkout#v1.7.0:
          paths:
            - src
            - .buildkite
          post_checkout:
            unshallow: true
```

### Handling corrupted repository states

If your jobs are frequently cancelled during the git clone phase, you may encounter failures due to uncommitted changes left in the repository. Use the `clean_checkout` option to handle this:

```yaml
steps:
  - label: "Pipeline upload with clean checkout"
    command: "buildkite-agent pipeline upload"
    plugins:
      - sparse-checkout#v1.7.0:
          paths:
            - .buildkite
          clean_checkout: true
```

### Cleaning up sparse-checkout state when the default path isolation is overridden

If your agent configuration causes sparse and non-sparse jobs to share the same checkout directory (overriding the plugin's `-sparse` path isolation), sparse-checkout state can leak between them. Enable `cleanup_sparse_state` to clean this up at `pre-exit` and `pre-checkout`:

```yaml
steps:
  - label: "Sparse build"
    command: "make build"
    plugins:
      - sparse-checkout#v1.7.0:
          paths:
            - src
          cleanup_sparse_state: true
```

The plugin will clean up stale sparse config in `pre-exit` (protecting the next job on the same directory from our own sparse state) and again in `pre-checkout` (protecting the current run from a previous interrupted job where `pre-exit` never fired).

## Testing

```bash
docker run --rm -ti -v "${PWD}":/plugin buildkite/plugin-tester:latest
```

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
