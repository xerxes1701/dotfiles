#!/usr/bin/env python3
"""Print one day's Claude Code activity: user prompts per session, then git commits.

Usage: day.py [YYYY-MM-DD] [--exclude SESSION_ID]
All times are local. Transcript timestamps are UTC and are converted.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import subprocess

ap = argparse.ArgumentParser()
ap.add_argument("date", nargs="?", default=dt.date.today().isoformat())
ap.add_argument("--exclude", action="append", default=[])
a = ap.parse_args()

day = dt.date.fromisoformat(a.date)
start = dt.datetime.combine(day, dt.time.min).astimezone()
end = start + dt.timedelta(days=1)
root = os.path.expanduser("~/.claude/projects")

NOISE = ("<local-command-caveat", "<local-command-stdout", "<system-reminder",
         "<task-notification", "<bash-stdout", "<bash-stderr")


def local(ts):
    return dt.datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()


def prompt_text(d):
    c = d.get("message", {}).get("content")
    if isinstance(c, list):
        c = " ".join(x.get("text", "") for x in c
                     if isinstance(x, dict) and x.get("type") == "text")
    if not isinstance(c, str):
        return None
    c = c.strip()
    if not c or c.startswith(NOISE):
        return None
    m = re.match(r"<command-name>(.*?)</command-name>.*?<command-args>(.*?)</command-args>", c, re.S)
    if m:
        return f"{m.group(1)} {m.group(2)}".strip()
    m = re.match(r"<bash-input>(.*?)</bash-input>", c, re.S)
    if m:
        return "! " + m.group(1).strip()
    return re.sub(r"\s+", " ", c)


sessions, repos = [], set()
for f in glob.glob(f"{root}/*/*.jsonl"):
    sid = os.path.basename(f)[:-6]
    if sid in a.exclude:
        continue
    if dt.datetime.fromtimestamp(os.path.getmtime(f)).astimezone() < start:
        continue
    prompts, cwd, branch, first, last = [], None, None, None, None
    for line in open(f, errors="replace"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        ts = d.get("timestamp")
        if not ts:
            continue
        t = local(ts)
        if not (start <= t < end):
            continue
        cwd = cwd or d.get("cwd")
        branch = d.get("gitBranch") or branch
        first, last = first or t, t
        if d.get("type") != "user" or d.get("isMeta") or d.get("isSidechain"):
            continue
        p = prompt_text(d)
        if p and p not in ("/clear", "/exit"):
            prompts.append((t, p[:500]))
    if prompts:
        sessions.append((first, last, sid, cwd, branch, prompts))
        if cwd:
            repos.add(cwd)

for first, last, sid, cwd, branch, prompts in sorted(sessions):
    print(f"=== {first:%H:%M}-{last:%H:%M}  {cwd}  [{branch}]  session {sid[:8]}")
    for t, p in prompts:
        print(f"  [{t:%H:%M}] {p}")
    print()

# Worktrees of one repo share a common git dir; list each repo once.
tops = {}
for cwd in sorted(repos):
    r = subprocess.run(["git", "-C", cwd, "rev-parse", "--path-format=absolute",
                        "--git-common-dir", "--show-toplevel"],
                       capture_output=True, text=True)
    if r.returncode == 0:
        common, top = r.stdout.split()
        tops.setdefault(common, top)

print("##### git commits (all branches, by you)")
for top in sorted(tops.values()):
    email = subprocess.run(["git", "-C", top, "config", "user.email"],
                           capture_output=True, text=True).stdout.strip()
    r = subprocess.run(["git", "-C", top, "log", "--all", "--author", email,
                        f"--since={start.isoformat()}", f"--until={end.isoformat()}",
                        "--date=format-local:%H:%M", "--format=%cd  %h  %s  (%D)"],
                       capture_output=True, text=True)
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    if lines:
        print(f"== {top}")
        print("\n".join(lines))
