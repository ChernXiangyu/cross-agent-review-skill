---
name: cross-agent-review
description: Get work done in Claude Code reviewed by a different coding agent (OpenAI Codex, Cursor's agent, or agy) instead of by Claude itself. Use it whenever the user asks for a code review, a second opinion or an independent check of recent commits, uncommitted changes, a module or a file, and whenever they say things like "let Codex review this", "have Cursor check it", "ask agy", "cross-review", "second opinion", 审查代码, 代码审查, 让 Codex 审一下, 让 Cursor 看看. Claude picks the scope, runs the other agent read-only, verifies every finding against the code, and reports with its own assessment. It does not fix anything until the user says so.
---

# Cross-agent review

A model reviewing its own work tends to agree with itself. This skill hands the review to a different agent
from a different vendor, run read-only from a script, and keeps Claude in the role of checking what comes
back. The reviewer finds things, Claude verifies them, the user decides what to fix.

## Reviewers

| Reviewer | CLI | How it is kept read-only |
|---|---|---|
| `codex` | `codex exec` | `-s read-only` sandbox |
| `cursor` | `cursor-agent -p` | `--mode ask` (print mode alone can write and run shell commands) |
| `agy` | `agy --print` | `--mode plan` with `--sandbox`, and told to review by reading only (in print mode it cannot ask permission to run a command, and returns nothing if it tries) |

Use the reviewer the user names. If they name none, use the one the project's instructions prefer, otherwise
ask once which they want. For a change that matters, running two reviewers and comparing is worth the wait:
a finding both report is rarely wrong.

## Steps

1. **Pick the scope.** If the user names none, default to the commits since the last review or the recent
   commits of the part being worked on (`git log --oneline --stat -10`). For uncommitted work use
   `git diff HEAD`. Say the scope in one line.
2. **Write a focus file** in a scratch directory, a few lines: what the code does, which outputs matter, and
   the kinds of bug most likely here (units for a parser, join keys and fan-out for a merge). Point to the
   project's own notes. Do not put your own suspicions in it as conclusions. The point is an independent look.
3. **Run the reviewer in the background.** A review takes from a minute to twenty.
   ```bash
   bash <skill dir>/scripts/agent_review.sh <codex|cursor|agy> <repo dir> <scratch dir> "<scope>" <scratch dir>/focus.md
   ```
   The report is `review_<reviewer>_<stamp>.md` in the scratch directory, next to the prompt that was sent
   and a log. Options: `REVIEW_MODEL=...`, `REVIEW_EFFORT=high` (codex and agy), `REVIEW_PROMPT_FILE=...` to
   replace the built-in instructions. Tell the user it is running and wait for it to finish. Do not poll.
4. **Verify every finding** against the code, and against data or a run where the finding names an example.
   Mark each one confirmed, partly right, or wrong. Reviewers are wrong often enough that an unchecked
   finding should never reach the user.
5. **Report** in the user's language and in plain words. Group by consequence (wrong results, weak checks,
   minor). Give each finding one or two sentences with the concrete example. Then give your own assessment:
   how good the review was, which findings matter most and why, and what fixing them would take. Say where
   the full report is. End by asking whether to fix. Do not fix in the same turn.
6. **Check that nothing was written.** Run `git status` in the repository after the review. The read-only
   modes above have held in testing, but they are the reviewer's promise, not a guarantee.

## What to send, and what not to

The reviewer is another company's model. The script sends it the scope, your focus file and access to the
repository. Before the first review in a project, check that the code and any data the reviewer can read are
allowed to leave the machine this way. If the project holds restricted data, review a copy without it, or
do not use this skill there.

## When it fails

- **`model ... not supported`** (Codex): the CLI is too old. Run `codex update`. The script already prefers
  the newest Codex binary it finds, including the one inside ChatGPT.app.
- **Login or usage-limit errors**: stop and tell the user. Do not fall back to reviewing it yourself without
  asking, because that removes the independence the user asked for.
- **Empty report**: read the log next to it. Cursor and agy print their answer to standard output, so an
  error there usually means the prompt never ran (not signed in, workspace not trusted).
- **The reviewer edited something**: restore it (`git checkout -- <file>`), tell the user, and check the
  mode flags in `scripts/agent_review.sh` against the CLI's current `--help`. These CLIs change quickly.
