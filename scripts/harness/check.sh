#!/usr/bin/env bash
set -euo pipefail

# Agent-friendly wrapper around the harness checks.
# Usage:
#   scripts/harness/check.sh [--full] [--no-test] [--no-compile]

export MIX_ENV="${MIX_ENV:-test}"

mix swati.harness.check "$@"