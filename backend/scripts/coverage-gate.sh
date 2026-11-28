#!/usr/bin/env sh
# Prints per-package coverage and fails when total coverage drops below the
# ratchet in coverage-threshold.txt. Raise the number as coverage grows; never
# lower it to make a build pass.
# Usage: sh scripts/coverage-gate.sh coverage.out
set -eu

profile="${1:-coverage.out}"
cd "$(dirname "$0")/.."
threshold="$(tr -d ' \n' < coverage-threshold.txt)"

echo "Per-package coverage:"
go tool cover -func="$profile" | awk '
  $1 ~ /:[0-9]+:/ && $NF ~ /%$/ {
    split($1, a, ":"); n = split(a[1], p, "/"); pkg = ""
    for (i = 1; i < n; i++) pkg = pkg (i > 1 ? "/" : "") p[i]
    gsub(/%/, "", $NF); sum[pkg] += $NF; cnt[pkg]++
  }
  END { for (k in sum) printf "  %-55s %5.1f%% (%d funcs, mean per function)\n", k, sum[k]/cnt[k], cnt[k] }' | sort

total="$(go tool cover -func="$profile" | awk '/^total:/ {gsub(/%/, "", $NF); print $NF}')"
echo "Total statement coverage: ${total}% (minimum enforced: ${threshold}%)"

if awk -v t="$total" -v m="$threshold" 'BEGIN { exit !(t + 0 < m + 0) }'; then
  echo "::error::coverage ${total}% is below the enforced minimum ${threshold}%"
  exit 1
fi
