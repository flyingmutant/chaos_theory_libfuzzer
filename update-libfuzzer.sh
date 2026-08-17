#!/bin/bash -ex

# Usage:
#
#     $ ./update-libfuzzer.sh

set -ex

# The LLVM commit from which we are vendoring libfuzzer. This must be a commit
# hash from https://github.com/llvm/llvm-project
COMMIT=a47b42eb9f9b302167b4fc413e6c92798d65dd0b

cd "$(dirname $0)"
project_dir="$(pwd)"

tmp_dir="$(mktemp -d)"
# This fork carries its libFuzzer changes as the single commit on top of
# upstream. Preserve that commit's vendored-source delta while refreshing the
# pinned LLVM checkout. Comparing against HEAD^ also includes worktree edits,
# which lets maintainers regenerate before amending the fork commit.
fork_patch="$tmp_dir/effective-input.patch"
git diff --binary HEAD^ -- libfuzzer/ > "$fork_patch"

cd "$tmp_dir"

git init
git remote add llvm https://github.com/llvm/llvm-project.git
git sparse-checkout set compiler-rt/lib/fuzzer

git fetch --depth 1 llvm "$COMMIT" --filter=blob:none
git checkout "$COMMIT"

rm -rf "$project_dir/libfuzzer/"
mv "$tmp_dir/compiler-rt/lib/fuzzer/" "$project_dir/libfuzzer/"

if [[ -s "$fork_patch" ]]; then
  git -C "$project_dir" apply "$fork_patch"
fi
