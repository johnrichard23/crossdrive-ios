#!/bin/bash
# Points git at the shared hooks in scripts/hooks. Run once per clone.
set -e
cd "$(git rev-parse --show-toplevel)"
chmod +x scripts/hooks/*
git config core.hooksPath scripts/hooks
echo "Hooks installed (scripts/hooks)."
