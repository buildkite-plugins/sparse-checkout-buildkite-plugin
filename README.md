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

Whether to perform aggressive repository cleanup before checkout. This option handles scenarios where interrupted or cancelled jobs leave the git repository in a corrupted state with uncommitted changes that would prevent checkout. When enabled, it performs `git reset --hard HEAD` and `git sparse-checkout disable` in addition to the normal cleanup.

**⚠️ Warning:** This option will destroy ALL local changes and remove ALL untracked files. The `git clean -ffxdq` command with the `-x` flag will also remove ignored files (such as credentials, local configuration, or cache files). Only use this option when you're certain no important local data needs to be preserved.

Use this option for pipeline upload jobs that don't need to preserve local changes.

#### `verbose` ('true' or 'false')

Enable verbose logging with bash execution tracing (`set -x`). This shows each command being executed and can help debug issues with ssh-keyscan, git operations, or other checkout problems. When enabled, you'll see detailed output including command arguments and any error messages from underlying tools.

## Example

Below is an example of using sparse-checkout plugin.

```yaml
steps:
  - label: "Pipeline upload"
    command: "buildkite-agent pipeline upload"
    plugins:
      - sparse-checkout#v1.3.0:
          paths:
            - .buildkite
```

### Handling corrupted repository states

If your jobs are frequently cancelled during the git clone phase, you may encounter failures due to uncommitted changes left in the repository. Use the `clean_checkout` option to handle this:

```yaml
steps:
  - label: "Pipeline upload with clean checkout"
    command: "buildkite-agent pipeline upload"
    plugins:
      - sparse-checkout#v1.3.0:
          paths:
            - .buildkite
          clean_checkout: true
```

## ⚒ Developing

To run testing, shellchecks and plugin linting use `bk run` with the [Buildkite CLI](https://github.com/buildkite/cli).

```bash
bk run
```
## 👩‍💻 Contributing

Your policy on how to contribute to the plugin!

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
