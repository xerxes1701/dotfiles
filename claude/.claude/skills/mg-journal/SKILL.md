---
name: mg-journal
description: Summarize a day's Claude Code sessions, write the summary to ~/journal/YYYY-MM-DD.md (or update the entry if it exists) and commit it.
argument-hint: "[YYYY-MM-DD] (default: today)"
disable-model-invocation: true
---

Write the journal entry for the day in `$ARGUMENTS` (`YYYY-MM-DD`; empty means today). If `~/journal/<date>.md` already exists, this run **updates** that entry (see "Updating an existing entry").

## 1. Collect

Run:

```sh
python3 -I ~/.claude/skills/mg-journal/scripts/day.py $ARGUMENTS --exclude ${CLAUDE_SESSION_ID}
```

It prints every session of that day (local times, cwd, branch, the user's prompts), followed by the user's git commits in the repos those sessions ran in. If a prompt is unclear, read the matching transcript in `~/.claude/projects/*/<session>.jsonl` to find out how it ended.

If the entry already exists, add `--new-since <HH:MM>`, using the time of the entry's last journal commit:

```sh
git -C ~/journal log -1 --format=%cd --date=format-local:%H:%M -- <date>.md
```

Prompts and commits from that time on are then marked with `+`. The unmarked ones should already be in the entry.

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

## Updating an existing entry

The existing file is the base: read it first, and edit it rather than rewriting it from scratch. The user may have edited it by hand, so keep their wording and additions.

- Fold the `+` work into the topics it belongs to, and add new topics for the rest. A session that was already summarised can continue after the last run; its new prompts are marked too.
- Bring the parts that changed up to date: the time range and session count in the first line, results that have since landed (a merge, a tag, a commit), and **Open items**. Remove items that are now done, and add new ones.
- If nothing is marked `+`, say so and change nothing.

## 3. Write and commit

- Write the entry to `~/journal/<date>.md`.
- If `~/journal` is not a git repo yet, run `git init` there.
- `git -C ~/journal add <date>.md && git -C ~/journal commit -m "journal: <date>"`, or `-m "journal: update <date>"` when updating. Add the commit attribution line if one is configured. Do not push.

Then show the user the summary (for an update, only what changed) and give them the file path and the commit hash.
