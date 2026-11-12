#!/bin/bash
# Fails if the repository holds something that must never be committed:
# private keys, live tokens, credentials inside a URL, signing files, or an
# App Transport Security opt-out. Part of scripts/check.sh and CI.
#
# A grep, not a full secret scanner: it catches the common, high-signal cases.
# Use gitleaks or your host's secret scanning as well if you have them.
set -e
cd "$(dirname "$0")/.."

status=0

# Files git would commit (tracked plus untracked, minus .gitignore'd), except this script.
files=$(git ls-files --cached --others --exclude-standard | grep -v '^scripts/check-secrets\.sh$' || true)

patterns=(
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'AKIA[0-9A-Z]{16}'
  'gh[pousr]_[A-Za-z0-9]{36,}'
  'glpat-[A-Za-z0-9_-]{20,}'
  'xox[abprs]-[A-Za-z0-9-]{10,}'
  'sk_live_[A-Za-z0-9]{16,}'
  'https?://[^/[:space:]:@"]+:[^/[:space:]@"]+@'
)
for pattern in "${patterns[@]}"; do
  if [ -n "$files" ] && matches=$(echo "$files" | xargs grep -nE -- "$pattern" 2>/dev/null); then
    echo "check-secrets: possible secret matching '$pattern':"
    echo "$matches" | cut -c1-160
    status=1
  fi
done

signing=$(echo "$files" | grep -E '\.(p12|p8|mobileprovision|provisionprofile|keychain|keychain-db|certSigningRequest|cer)$' || true)
if [ -n "$signing" ]; then
  echo "check-secrets: signing files belong in CI secrets, not the repository:"
  echo "$signing"
  status=1
fi

if [ -n "$files" ] && ats=$(echo "$files" | grep -E '\.(plist|xcconfig)$' | xargs grep -lE 'NSAllowsArbitraryLoads' 2>/dev/null); then
  echo "check-secrets: App Transport Security must stay on (NSAllowsArbitraryLoads found):"
  echo "$ats"
  status=1
fi

if [ $status -eq 0 ]; then
  echo "check-secrets: nothing found"
fi
exit $status
