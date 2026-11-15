#!/bin/bash
# Ask another coding agent for a read-only code review and save its report.
#
#   agent_review.sh <reviewer> <repo_dir> <out_dir> <scope> [focus_file]
#
#   reviewer    codex | cursor | agy
#   repo_dir    the repository to review (the reviewer reads it; it must not write to it)
#   out_dir     where review_<reviewer>_<stamp>.md (the report), the prompt and the log go.
#               Use a directory outside the repository, such as a scratch directory.
#   scope       what to review, in words the reviewer can act on, e.g.
#               "git diff main..HEAD", "uncommitted changes: git diff HEAD", "src/parser.py"
#   focus_file  optional text file: what the code does and which bugs matter most
#
# Env: REVIEW_MODEL (default: the reviewer's own default model)
#      REVIEW_EFFORT (codex and agy only, e.g. high)
#      REVIEW_PROMPT_FILE (replace the built-in review instructions)
set -euo pipefail

usage="usage: agent_review.sh <codex|cursor|agy> <repo_dir> <out_dir> <scope> [focus_file]"
reviewer=${1:?$usage}
repo=$(cd "${2:?$usage}" && pwd)
out_dir=${3:?$usage}
scope=${4:?$usage}
focus_file=${5:-}
model=${REVIEW_MODEL:-}
effort=${REVIEW_EFFORT:-}

mkdir -p "$out_dir"
out_dir=$(cd "$out_dir" && pwd)
stamp=$(date +%Y%m%d_%H%M%S)
prompt="$out_dir/prompt_${reviewer}_$stamp.md"
report="$out_dir/review_${reviewer}_$stamp.md"
log="$out_dir/log_${reviewer}_$stamp.txt"

{
  echo "Do a code review of this repository. Read-only: do not modify, create or delete any file."
  echo
  echo "Scope: $scope"
  echo
  if [ -n "$focus_file" ]; then echo "Context and focus:"; cat "$focus_file"; echo; fi
  if [ -n "${REVIEW_PROMPT_FILE:-}" ]; then
    cat "$REVIEW_PROMPT_FILE"
  else
    cat <<'PROMPT'
Read the project's own instructions first if it has any (README, CLAUDE.md, AGENTS.md). Look for the bugs
that matter: wrong results (units, scale, joins that duplicate or drop rows, filters, off-by-one), unhandled
missing values or errors that pass silently, non-determinism, checks and tests that cannot fail, and
documentation or rules the code does not actually apply. You may run read-only commands to confirm a bug
with a concrete example. Write nothing.

Report a ranked list of findings, most severe first. For each: severity (P1 wrong results / P2 weak check or
latent bug / P3 minor), file:line, the defect in one sentence, a concrete failure scenario (input -> wrong
output), and your confidence (high / medium / low). Say which findings you confirmed by running something
and which only by reading. Skip style nits. If you find nothing serious, say so.
PROMPT
  fi
} > "$prompt"

fail() { echo "$reviewer failed; last lines of $log:" >&2; tail -20 "$log" >&2; exit 1; }

case "$reviewer" in
  codex)
    # Pick the newest Codex binary: an old CLI rejects newer models.
    ver() { "$1" --version 2>/dev/null | awk '{print $2}' | cut -d- -f1; }
    best=""; best_v="0"
    for b in "$(command -v codex || true)" /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex; do
      [ -n "$b" ] && [ -x "$b" ] || continue
      v=$(ver "$b"); [ -n "$v" ] || continue
      if [ "$(printf '%s\n%s\n' "$best_v" "$v" | sort -V | tail -1)" = "$v" ] && [ "$v" != "$best_v" ]; then
        best=$b; best_v=$v
      fi
    done
    [ -n "$best" ] || { echo "no codex binary found" >&2; exit 2; }
    args=(exec -s read-only -C "$repo" -o "$report")
    [ -n "$model" ] && args+=(-m "$model")
    [ -n "$effort" ] && args+=(-c "model_reasoning_effort=$effort")
    echo "codex $best_v, model ${model:-default}; report: $report"
    "$best" "${args[@]}" - < "$prompt" > "$log" 2>&1 || fail
    ;;
  cursor)
    bin=$(command -v cursor-agent || true)
    [ -n "$bin" ] || { echo "cursor-agent not found" >&2; exit 2; }
    # ask mode is Cursor's read-only mode; print mode alone can write and run shell commands.
    args=(-p --mode ask --trust --workspace "$repo" --output-format text)
    [ -n "$model" ] && args+=(--model "$model")
    echo "cursor-agent $("$bin" --version 2>/dev/null | head -1), model ${model:-default}; report: $report"
    (cd "$repo" && "$bin" "${args[@]}" "$(cat "$prompt")") > "$report" 2> "$log" || fail
    ;;
  agy)
    bin=$(command -v agy || true)
    [ -n "$bin" ] || { echo "agy not found" >&2; exit 2; }
    # plan mode proposes without editing; the sandbox restricts its terminal. In print mode agy cannot ask
    # for permission to run a command and then returns nothing, so tell it to review by reading only.
    printf '\nDo not run shell commands. Review by reading files only.\n' >> "$prompt"
    args=(--mode plan --sandbox)
    [ -n "$model" ] && args+=(--model "$model")
    [ -n "$effort" ] && args+=(--effort "$effort")
    echo "agy $("$bin" --version 2>/dev/null | head -1), model ${model:-default}; report: $report"
    (cd "$repo" && "$bin" "${args[@]}" --print "$(cat "$prompt")") > "$report" 2> "$log" || fail
    ;;
  *)
    echo "unknown reviewer '$reviewer'. $usage" >&2; exit 2 ;;
esac

[ -s "$report" ] || { echo "$reviewer wrote an empty report" >&2; fail; }
echo "done: $report"
