#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/libfuzzer-effective-input.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

CORPUS="$TEST_ROOT/corpus"
mkdir "$CORPUS"
printf '\000Q' > "$CORPUS/seed"
printf '\377A' > "$CORPUS/oversize-a"
printf '\377B' > "$CORPUS/oversize-b"

LOG="$TEST_ROOT/fuzz.log"
cargo fuzz run effective_input_chain "$CORPUS" -- \
    -runs=8 -mutate_depth=3 -max_len=64 -seed=1 -verbosity=0 >"$LOG" 2>&1

WARNING_COUNT=$(grep -c \
    'exceeding MaxOutSize 64; rejecting this input' "$LOG" || true)
if [[ "$WARNING_COUNT" -ne 1 ]]; then
    cat "$LOG" >&2
    echo "expected exactly one oversized effective-input warning" >&2
    exit 1
fi

INFERRED_CORPUS="$TEST_ROOT/inferred-corpus"
mkdir "$INFERRED_CORPUS"
printf '\000Q' > "$INFERRED_CORPUS/seed"
INFERRED_LOG="$TEST_ROOT/inferred.log"
cargo fuzz run effective_input_chain "$INFERRED_CORPUS" -- \
    -runs=2 -seed=1 -verbosity=0 >"$INFERRED_LOG" 2>&1
grep -q 'not generate inputs larger than 8192 bytes' "$INFERRED_LOG"

CAPPED_CORPUS="$TEST_ROOT/capped-corpus"
mkdir "$CAPPED_CORPUS"
dd if=/dev/zero of="$CAPPED_CORPUS/seed" bs=1048576 count=1 2>/dev/null
CAPPED_LOG="$TEST_ROOT/capped.log"
cargo fuzz run effective_input_chain "$CAPPED_CORPUS" -- \
    -runs=2 -seed=1 -verbosity=0 >"$CAPPED_LOG" 2>&1
grep -q 'not generate inputs larger than 1048576 bytes' "$CAPPED_LOG"

printf '\245X' > "$TEST_ROOT/expected"
for INPUT in "$CORPUS"/*; do
    if cmp -s "$TEST_ROOT/expected" "$INPUT"; then
        exit 0
    fi
done

echo "effective corpus entry was not written" >&2
exit 1
