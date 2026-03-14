#!/usr/bin/env bash
set -e

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"

for p in "$THIS_DIR"/*.pl; do
    perl "$p"
done
