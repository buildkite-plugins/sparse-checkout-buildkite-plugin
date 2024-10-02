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

## Example

Below is an example for using sparse-checkout plugin.

```yaml
steps:
  - label: "Pipeline upload"
    command: "buildkite-agent pipeline upload"
    plugins:
      - sparse-checkout#v1.1.0:
          paths:
            - .buildkite
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
