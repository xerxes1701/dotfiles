---
name: verify-rebase
description: Use after rebasing a branch that was already pushed -- or a stack of stacked merge-request branches -- and before any force-push (`git push --force-with-lease`), or when asked to verify or check a rebase. Runs `git verify-rebase --diff` for a deterministic list of what the rebase changed, analyses its diffs (conflict resolutions, changed, added and dropped commits) and reports the findings with a verdict.
argument-hint: "[branch | --stack [top] | bottom … top] [-b <target>]"
---

# Verify a rebase before the force-push

A rebase can change more than the base: a conflict resolved the wrong way, a
hunk lost, an edit slipped into an `edit`/`fixup` step. `git verify-rebase`
(`~/.local/bin/git-verify-rebase.cs`, aliases `git verify-rebase` and
`git rbv`) finds those differences deterministically. It replays the pushed
commits onto the new base with `git merge-tree`, compares that clean replay
with the rebased branch file by file, and pairs the pushed and rebased commits
by their patches. Your job is to run it, read what it reports, judge every
difference, and give a verdict.

Run it after **every** rebase of a pushed branch, before any force-push. That
includes `git rebase -i`, `--onto`, `--update-refs` and `git pull --rebase`.
Never force-push before the verdict, and only push if the user asked for the
push (see 5).

## 1. Run it

- The rebase must be finished. The script refuses to run while one is in progress.
- Don't `git fetch` between the rebase and the check: a fetch moves
  `origin/<branch>`, which is what the check compares against and what the
  lease expects. Pass `--check-remote` to ask the remote instead; that moves nothing.
- Always pass `--diff`, and `-O <dir>` with an absolute path to a new
  directory (in your scratchpad if you have one). The report goes there, one
  file per branch, without colors and with long lines whole, because `--diff`
  output can be long. The terminal shows only the verdict (for a stack, its
  table), the push command and the files written. Note the exit code.
- Re-run into the same directory: the script clears the files of its last run
  there. It refuses a directory that holds anything else.

How to call it:

```bash
# a repository in the Linux filesystem, or on Windows:
git rbv <args> --diff -O "$DIR"; echo "exit $?"

# WSL, repository under /mnt/<drive>: keep WSL's git out of it (the script itself uses git.exe)
dotnet run --file "$(readlink -f ~/.local/bin/git-verify-rebase.cs)" -- -C <repo> <args> --diff -O "$DIR"; echo "exit $?"
```

The first run builds the script, which takes a few seconds. `git rbv -h` lists every option.

Which arguments:

| what was rebased | arguments |
|---|---|
| the checked-out branch, onto the remote's default branch | (none) |
| a branch whose merge request targets another branch | `<branch> -b origin/<target>` |
| `git rebase --onto <new> <old> <branch>` | `<branch> --old-base <old> -b <new>` |
| a stack of merge requests | `--stack <top> -b origin/<target of the bottom MR>` |
| a stack, branches named explicitly | `<bottom> … <top> -b origin/<target of the bottom MR>` |

`-b` is the branch you rebased onto. You know it from the rebase you ran;
otherwise take it from the merge request's target branch. A wrong `-b` doesn't
corrupt the result, but it pulls the target's commits into the report as noise.

For a stack, every branch is checked as a merge request on the one below it,
so each section shows only what the rebase changed in that merge request.
Check the whole stack before you push any part of it. If a branch reports
"Could not tell which version of <parent> … was built on" (a fresh clone, or an
expired reflog), check that branch alone with
`--old-base <old parent commit> --new-base <parent>`.

## 2. Read the report

Read `00-summary.txt` first. For a stack it lists the branches, then the
table and the overall verdict with the push command; for one branch it holds
just the verdict. Then read each branch's file, `01-<branch>.txt` and on, from
the bottom of the stack up, section by section. The sections start with `── `
rules. If the script stopped before it checked anything (exit 2),
`00-summary.txt` holds only its error.

- **Header rows**: `rebased` (local), `pushed` (the version the force-push
  would overwrite), `onto`, `fork point` (old → new base, and what moved
  underneath), `commits` (pushed → rebased counts; merge commits are left out
  of the pairing, but not out of the content check).
- **commits** table, one row per commit pair:
  - `same` and `reworded` are fine.
  - `upstream` means the new base already has the commit. Fine.
  - `squashed into X` is fine if squashing was intended (`fixup!` and the like).
  - `↕ moved` means it was reordered. Fine if intended.
  - `changed N files` means the commit's patch differs. Look at its interdiff.
  - `dropped` and `added`: were they meant to be?
  - `author changed`: always mention it.
- **files whose changes differ**: for each changed, added or dropped commit, its files.
- **content** table: the files of the rebased branch that differ from the
  clean replay, each with a "why":
  - `the rebase had a conflict here`: a conflict resolution. Judge it (step 3).
  - `changed by the added commit X` / `by the dropped commit Y`: the difference
    is explained by that commit. Check that the commit belongs there or not.
  - `a clean replay gives other content`: **unexplained**. Git could have
    replayed this file differently, and the branch has something else. That
    is an edit made during the rebase, or a mistake. Find out which.
  - `conflict markers were committed`: always a defect.
- **diffs**: two kinds (step 3).
- **verdict** box, and below it the exact push command. It leases to the
  version that was checked, with the full SHA. For a stack, each branch's
  file has its verdict, and `00-summary.txt` the one push for all of them.

Exit codes:
- `0`: the same, or only reshaped commits.
- `1`: something differs, or the remote moved.
- `2`: the script could not verify. Its box says why and what to do; fix that and run it again.

## 3. Analyse the diffs

**Content diffs**, headed `<file>  − a clean replay, + <branch>`. The `−` lines
are what replaying the pushed changes onto the new base gives; the `+` lines
are what the rebased branch has instead.

- After a **conflict**, the `−` side holds the replay's conflict markers:
  `<<<<<<< <new base>`, the new base's version; then `||||||| <old base>`, the
  common ancestor (if shown); then `=======`, followed by the pushed branch's
  version, up to `>>>>>>> <pushed>`. The SHAs match the `fork point` and
  `pushed` rows.
  - The `+` lines are the resolution. Work out what each side changed
    relative to the ancestor, and check that the resolution keeps **both**
    intents.
  - Typical defects:
    - It keeps only one side, silently reverting the other.
    - It duplicates code.
    - It leaves half a change.
    - It adds something neither side had.
  - For code, think about semantics too: a renamed symbol on one side and a new
    use of the old name on the other side compiles on neither.
- **Without a conflict**, each `+`/`−` line is a change the rebase introduced
  beyond moving the branch. Tie it to a cause:
  - an intended edit, e.g. the user asked for it, or a `fixup` was applied
  - an added or dropped commit
  - nothing. A difference with no cause is a defect until explained.

**Commit interdiffs**, headed `<file> in <subject>  outer − the patch in <old>,
outer + the patch in <new>`. They work like `git range-diff`: the first column
says which version a line belongs to, and the second is the patch's own `+`/`−`.

- ` ` + `+x`: both patches add `x`.
- `-` + `+x`: only the old patch added `x`.
- `+` + `+x`: only the new patch adds `x`.
- `+` + `-x`: only the new patch removes `x`.

A commit whose patch changed only because its context or the base moved
underneath is fine. A commit that now adds or removes different lines must
match a conflict resolution or an intended edit.

Use the git objects the report names (e.g. `git show <sha>:<path>`) when a hunk
needs more context. Don't replace the report with ad-hoc diffs of your own:
the report is the deterministic list, and every item on it gets a judgement.

Judge every finding against **what the rebase was meant to do**. Take that
from the conversation, e.g. "rebase onto the new develop", "squash the
fixups", "drop the debug commit", "resolve the review comments while
rebasing". State that intent in the summary.

## 4. Summarize

For a stack, report each merge request in its own section, then the overall result.

```markdown
## Rebase check: <branch> onto <base>
**Verdict: SAFE TO PUSH | NEEDS YOUR REVIEW | DO NOT PUSH**: <one sentence why>

Intent: <what the rebase was meant to do>
Script: exit <n>, "<the script's verdict title>"; <pushed → rebased commits>; <N files differ, k after conflicts>

| # | file / commit | kind | finding | judgement |
|---|---|---|---|---|
| 1 | `path` | conflict resolution | keeps the new base's X and the branch's Y | ✔ ok |
| 2 | `path` | no conflict | adds Z that neither side had | ✘ unexplained |

Push (if the verdict allows it): `<the exact command the script printed>`
```

Choosing the verdict:
- **SAFE TO PUSH**: exit 0. Or every difference is checked and correct:
  resolutions that keep both sides, intended added, dropped or squashed
  commits, and reworded commits.
- **NEEDS YOUR REVIEW**: differences you cannot judge with confidence, such as
  semantic merges in code, or a resolution where both readings are plausible.
  Name the exact hunks to look at, and why.
- **DO NOT PUSH**: any of these:
  - a concrete defect: a lost or reverted change, a wrong resolution,
    committed conflict markers, or an unexplained change
  - a dropped commit that wasn't meant to be dropped
  - "a force-push would drop commits" (the remote has commits the branch lacks)
  - "the remote moved" (`--check-remote`)
  - exit 2

List every content difference and every changed, dropped or added commit. A
clean result is one line, not a table.

## 5. Then

- Push only if the user asked for the push **and** the verdict is SAFE TO
  PUSH. Use exactly the command the script printed: one lease per branch,
  with full SHAs, and `--atomic` for a stack. For a stack it also publishes a
  top branch that was never pushed; leave that branch out if it shouldn't go
  out yet.
- Otherwise present the verdict and wait.
- If you made the defect yourself, e.g. in a conflict resolution, fix it with
  a commit or another rebase, then **run the check again** and report the new
  result. Never report a verdict from a run made before the last change to
  the branch.
