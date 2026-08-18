#!/bin/bash -ex

# Usage:
#
#     $ ./update-libfuzzer.sh

set -ex

# The rust-fuzz/libfuzzer commit this fork is based on. Update this after
# rebasing the fork onto a newer upstream commit.
UPSTREAM_COMMIT=719e4efb9b8857ebaa782ae59376c8cbb78fed0f

# The LLVM commit from which we are vendoring libfuzzer. This must be a commit
# hash from https://github.com/llvm/llvm-project.
LLVM_COMMIT=a47b42eb9f9b302167b4fc413e6c92798d65dd0b

cd "$(dirname $0)"
project_dir="$(pwd)"

tmp_dir="$(mktemp -d)"
# Preserve all of the fork's vendored-source changes while refreshing the
# pinned LLVM checkout. This also includes worktree edits, which lets
# maintainers regenerate before committing changes.
fork_patch="$tmp_dir/effective-input.patch"
git diff --binary "$UPSTREAM_COMMIT" -- libfuzzer/ > "$fork_patch"

cd "$tmp_dir"

git init
git remote add llvm https://github.com/llvm/llvm-project.git
git sparse-checkout set compiler-rt/lib/fuzzer

git fetch --depth 1 llvm "$LLVM_COMMIT" --filter=blob:none
git checkout "$LLVM_COMMIT"

rm -rf "$project_dir/libfuzzer/"
mv "$tmp_dir/compiler-rt/lib/fuzzer/" "$project_dir/libfuzzer/"

if [[ -s "$fork_patch" ]]; then
  git -C "$project_dir" apply "$fork_patch"
fi
