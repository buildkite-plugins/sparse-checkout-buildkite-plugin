#!/bin/bash

# Shared utility functions for Buildkite plugins

set -euo pipefail

# Usage: log_info "Starting deployment process"
log_info() {
  echo "[INFO]: $*"
}

# Usage: log_success "Image pushed to registry"
log_success() {
  echo "[SUCCESS]: $*"
}

# Usage: log_warning "Using default timeout of 30s"
log_warning() {
  echo "[WARNING]: $*"
}

# Usage: log_error "Failed to connect to API"
log_error() {
  echo "[ERROR]: $*" >&2
}

# Usage: log_debug "Processing configuration file"
log_debug() {
  if is_debug_mode; then
    echo "[DEBUG]: $*" >&2
  fi
}

# Usage: if command_exists docker; then echo "Docker available"; fi
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Usage: check_dependencies docker aws kubectl
check_dependencies() {
  local missing_deps=()

  for cmd in "$@"; do
    if ! command_exists "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_error "Please install the missing dependencies and try again."
    exit 1
  fi
}

# Usage: validate_required_config "API token" "${api_token}"
validate_required_config() {
  local config_name="$1"
  local config_value="$2"

  if [[ -z "$config_value" ]]; then
    log_error "$config_name is required but not provided"
    exit 1
  fi
}

# Usage: run_command "Pushing image to registry" docker push my-image:latest
run_command() {
  local description="$1"
  shift

  log_info "$description"
  if "$@"; then
    log_success "$description completed successfully"
    return 0
  else
    log_error "$description failed"
    return 1
  fi
}

# Usage: if is_debug_mode; then echo "Additional debug info"; fi
is_debug_mode() {
  [[ "${BUILDKITE_PLUGIN_DEBUG:-false}" =~ (true|on|1) ]]
}

# Usage: setup_error_trap (call early in your hook scripts)
setup_error_trap() {
  trap 'log_error "Command failed with exit status $? at line $LINENO: $BASH_COMMAND"' ERR
}

# Usage: enable_debug_if_requested (call early in your hook scripts)
enable_debug_if_requested() {
  if is_debug_mode; then
    log_info "Debug mode enabled"
    set -x
  fi
}

# Retry a command with exponential backoff
# Usage: retry 5 ssh-keyscan -t rsa example.com
# Arguments:
#   $1: number of retries
#   $@: command to execute
retry() {
  local retries=$1
  shift
  local attempts=1
  local status=0

  until "$@"; do
    status=$?
    echo "Exited with status $status" >&2
    if (( retries == 0 )); then
      return $status
    elif (( attempts == retries )); then
      echo "Failed after $attempts retries" >&2
      return $status
    else
      echo "Retrying $((retries - attempts)) more times..." >&2
      attempts=$((attempts + 1))
      sleep $(((attempts - 2) * 2))
    fi
  done
}

# ============================================================================
# Array utilities
# ============================================================================

# Checks if an array contains a specific value
# Usage: if array_contains "needle" "${haystack[@]}"; then echo "found"; fi
array_contains() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

# Joins array elements into a string with separator
# Usage: result=$(array_join "," "${array[@]}")  # Returns: "a,b,c"
array_join() {
  local separator="${1}" f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$separator}"
  fi
}

# ============================================================================
# String utilities
# ============================================================================

# Checks if a string contains another string
# Usage: if string_contains "$haystack" "$needle"; then echo "found"; fi
string_contains() {
  [[ "$1" == *"$2"* ]]
}

# Removes prefix from string
# Usage: result=$(string_strip_prefix "foo=bar" "foo=")  # Returns: "bar"
string_strip_prefix() {
  echo "${1#"$2"}"
}

# Removes suffix from string
# Usage: result=$(string_strip_suffix "foo=bar" "=bar")  # Returns: "foo"
string_strip_suffix() {
  echo "${1%"$2"}"
}

# ============================================================================
# Sparse checkout utilities
# ============================================================================

# Cleans up sparse-checkout state left behind by git sparse-checkout set.
# Removes .git/config.worktree, unsets the three related config keys, and clears
# per-file skip-worktree bits from the index so that subsequent non-sparse jobs
# on the same agent directory are not affected.
#
# Deliberately avoids `git sparse-checkout disable` which re-materialises all
# files in the working tree (expensive on large monorepos).
#
# Covers both modern git (extensions.worktreeConfig + .git/config.worktree) and
# older git that writes core.sparseCheckout directly into .git/config.
cleanup_sparse_checkout_config() {
  if [[ ! -d .git ]]; then
    log_info "No .git directory found, skipping sparse-checkout config cleanup"
    return 0
  fi
  log_info "Cleaning up sparse-checkout config"
  # Clear skip-worktree bits from the index before touching config so that
  # subsequent non-sparse jobs see all files. These bits are set by
  # `git sparse-checkout set` and persist independently of config entries.
  # Using update-index avoids materialising files to disk (unlike disable).
  git ls-files -t 2>/dev/null | awk '/^S /{print substr($0, 3)}' | xargs git update-index --no-skip-worktree -- 2>/dev/null || true
  # Unset the extension flag first so git does not look for the worktree config
  # file during subsequent config operations.
  git config --unset extensions.worktreeConfig 2>/dev/null || true
  rm -f .git/config.worktree
  git config --unset core.sparseCheckout 2>/dev/null || true
  git config --unset core.sparseCheckoutCone 2>/dev/null || true
  log_success "Sparse-checkout config cleaned up"
}

# ============================================================================
# File utilities
# ============================================================================

# Checks if file exists and is a regular file
# Usage: if file_exists "/path/to/file"; then echo "exists"; fi
file_exists() {
  [[ -f "$1" ]]
}

# Checks if file contains specific text/pattern
# Usage: if file_contains_text "pattern" "/path/to/file"; then echo "found"; fi
file_contains_text() {
  grep -q "$1" "$2"
}
