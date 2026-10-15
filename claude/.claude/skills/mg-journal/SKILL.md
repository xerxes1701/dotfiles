---
name: mg-journal
description: Summarize a day's Claude Code sessions, write the summary to ~/journal/YYYY-MM-DD.md and commit it.
argument-hint: "[YYYY-MM-DD] (default: today)"
disable-model-invocation: true
---

Write the journal entry for the day in `$ARGUMENTS` (`YYYY-MM-DD`; empty means today).

## 1. Collect

Run:

```sh
python3 -I ~/.claude/skills/mg-journal/scripts/day.py $ARGUMENTS --exclude ${CLAUDE_SESSION_ID}
```

It prints every session of that day (local times, cwd, branch, the user's prompts), followed by the user's git commits in the repos those sessions ran in. If a prompt is unclear, read the matching transcript in `~/.claude/projects/*/<session>.jsonl` to find out how it ended.

## 2. Summarize

Group by **topic**, not by session: one session can cover several topics, and one topic can span several sessions and worktrees. Use the commits to say what actually landed (versions, tags, merges). Leave out test pings ("say ok", stray keystrokes) and bare slash commands.

Use this layout:

```markdown
# YYYY-MM-DD (Weekday)

Worked ~HH:MM–HH:MM across ~N Claude Code sessions.

## 1. <Topic> (<repo/worktree>, <branch>)

- **<Sub-topic>:** what was done and what the result was.
  - Details as nested bullets, no paragraphs.

## Off-topic questions

One line listing them.

## Open items

- Things left unfinished, uncommitted or unresolved.
```

Keep it brief: bullets, no narration. Name commits, tags and versions where they exist.

## 3. Write and commit

- Write the entry to `~/journal/<date>.md`. If the file already exists, read it and merge into it; don't overwrite it.
- If `~/journal` is not a git repo yet, run `git init` there.
- `git -C ~/journal add <date>.md && git -C ~/journal commit -m "journal: <date>"`. Add the commit attribution line if one is configured. Do not push.

Then show the summary to the user and give them the file path and the commit hash.
