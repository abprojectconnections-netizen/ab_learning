#!/usr/bin/env sh
# Creates backend/.env from env/local.env.example with random secrets.
# Refuses to overwrite an existing .env.
set -eu

cd "$(dirname "$0")/.."

if [ -e .env ]; then
  echo ".env already exists; leaving it untouched." >&2
  exit 0
fi

rand() { openssl rand -hex "$1"; }

# Every placeholder gets its own random value (no two secrets are ever equal).
while IFS= read -r line; do
  case "$line" in
    *__GENERATE_LONG__*) printf '%s\n' "${line%%__GENERATE_LONG__*}$(rand 32)${line#*__GENERATE_LONG__}" ;;
    *__GENERATE__*) printf '%s\n' "${line%%__GENERATE__*}$(rand 16)${line#*__GENERATE__}" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < env/local.env.example > .env

chmod 600 .env
echo "Created backend/.env (git-ignored) with generated local secrets."
