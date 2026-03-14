#!/usr/bin/env bash
set -u

cd "$(dirname "$0")" || exit 1

status=0

for example in ./*.pl; do
    echo "==> $example"
    perl "$example"
    rc=$?
    echo "<== $example exit=$rc"
    echo
    if [ "$rc" -ne 0 ]; then
        status=$rc
    fi
done

exit "$status"
