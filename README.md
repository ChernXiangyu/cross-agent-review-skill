# cross-agent-review — a Claude Code skill

A [Claude Code](https://claude.com/claude-code) skill that gets Claude's work reviewed by a different
coding agent: [OpenAI Codex](https://developers.openai.com/codex/cli), [Cursor's agent](https://cursor.com/cli)
or `agy`. A model reviewing its own work tends to agree with itself, so the review goes to another vendor's
model, and Claude's job becomes checking what comes back.

## What it teaches Claude

- **Hand off the review**: pick the scope, write a short focus file, run the other agent from a script.
- **Keep the reviewer read-only**: each CLI is started in its read-only mode (`codex exec -s read-only`,
  `cursor-agent --mode ask`, `agy --mode plan --sandbox`), and Claude checks `git status` afterwards.
  Tested with codex-cli 0.166, cursor-agent 2026.11.13 and agy 1.5.9.
- **Verify before reporting**: every finding is checked against the code and marked confirmed, partly right
  or wrong. Unchecked findings never reach the user.
- **Report, do not fix**: findings are grouped by consequence with Claude's own assessment, and nothing is
  changed until the user says so.
- **Mind what leaves the machine**: the reviewer is another company's model, so the skill tells Claude to
  check that the code and data may be sent before the first review in a project.

## Contents

| File | Purpose |
|---|---|
| `SKILL.md` | The skill: instructions Claude loads when asked for a review or a second opinion |
| `scripts/agent_review.sh` | Runs one reviewer read-only on a repository and saves the report, the prompt and a log |

## Install

Personal (all your projects):

```bash
git clone https://github.com/ChernXiangyu/cross-agent-review-skill.git ~/.claude/skills/cross-agent-review
```

Or per project: clone into `<project>/.claude/skills/cross-agent-review`.

Claude Code picks the skill up automatically. It triggers when you ask for a code review, a second opinion,
or name a reviewer ("let Codex review this", "have Cursor check it").

## Use the script on its own

```bash
bash scripts/agent_review.sh codex  /path/to/repo /tmp/review "git diff main..HEAD"
bash scripts/agent_review.sh cursor /path/to/repo /tmp/review "uncommitted changes: git diff HEAD" focus.md
bash scripts/agent_review.sh agy    /path/to/repo /tmp/review "src/parser.py"
```

Options: `REVIEW_MODEL`, `REVIEW_EFFORT` (codex and agy), `REVIEW_PROMPT_FILE` to replace the built-in
review instructions.

## Requirements

- At least one of the reviewer CLIs, installed and signed in: `codex`, `cursor-agent`, `agy`.
- `git` and `bash`.

## License

MIT — see [LICENSE](LICENSE).
