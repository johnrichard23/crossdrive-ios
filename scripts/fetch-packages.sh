#!/bin/bash
# The project uses the two shared packages by local path
# (../mobile-data-layer and ../mobile-design-system). On a machine that
# doesn't have them next to this repository, such as a CI runner, clone them.
#
# Set in the CI settings (never in this repository):
#   DATA_LAYER_REPO, DESIGN_SYSTEM_REPO   git URLs the runner can read
#   DATA_LAYER_REF,  DESIGN_SYSTEM_REF    optional tag or branch
#
# Once the packages are hosted and the project points at versioned remote
# packages instead of paths, delete this script and its CI step.
set -e
cd "$(dirname "$0")/.."

fetch() {
  local dir=$1 repo=$2 ref=$3
  if [ -d "../$dir" ]; then
    echo "packages: ../$dir is present"
    return
  fi
  if [ -z "$repo" ]; then
    echo "packages: ../$dir is missing and no repository URL is set" >&2
    exit 1
  fi
  echo "packages: cloning ../$dir${ref:+ at $ref}"
  git clone --quiet --depth 1 ${ref:+--branch "$ref"} "$repo" "../$dir"
}

fetch mobile-data-layer "${DATA_LAYER_REPO:-}" "${DATA_LAYER_REF:-}"
fetch mobile-design-system "${DESIGN_SYSTEM_REPO:-}" "${DESIGN_SYSTEM_REF:-}"
