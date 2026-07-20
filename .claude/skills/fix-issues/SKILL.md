---
name: fix-issues
description: Fix a batch of open GitHub issues end to end - one git worktree and one agent per issue (feature-dev for implementation, review-pr for review), individual PRs into develop, a release PR to main with a final multi-agent integration review, and optional tag/release/issue-comment publishing. Use when the user asks to sweep and fix open issues of this repo.
---

# Batch Issue Fixing Pipeline

Arguments: `$ARGUMENTS` — optional space-separated issue numbers to limit the batch. Empty means all open issues.

This skill encodes the full process: triage -> parallel fixes in isolated worktrees -> merge into `develop` -> release -> final review -> publish. Follow the phases in order. All `gh` commands run from the repo root (no `--repo` flag needed).

## Phase 0 — Preflight

1. `git fetch origin` and confirm the working tree is clean (`git status --short`). If dirty, stop and ask the user.
2. Compare branches: `git rev-list --left-right --count origin/main...origin/develop`.
   - If `develop` is strictly behind `main` (0 unique commits), fast-forward it: `git push origin origin/main:develop`.
   - If `develop` has unique commits, ask the user how to proceed before branching anything.
3. All fix branches are created from `origin/develop`.

## Phase 1 — Triage

1. List issues: `gh issue list --state open --limit 100 --json number,title,labels`.
2. Read EVERY issue in scope with comments: `gh issue view <n> --comments`. Comments often contain the real root cause or a maintainer-agreed approach.
3. Build a summary table (number, type bug/feature, one-line problem). Explicitly check for duplicates and overlapping fixes.
4. Ask the user (AskUserQuestion) before starting work:
   - Scope: which issues go into this batch (call out breaking changes and pure feature requests separately).
   - Whether to auto-merge fix PRs into `develop` or leave them open for manual review.
   - Anything that looks external/not-a-bug (e.g. Docker Hub rate limits): propose fix / message-only / skip-and-close options.
5. Decide the version bump now (semver table in CLAUDE.md) so the release phase is mechanical. The user may override.

## Phase 2 — Parallel fixes (one worktree + one agent per issue)

1. Create worktrees as siblings of the repo:
   ```bash
   git worktree add ../<repo-name>-worktrees/issue-<n> -b fix/issue-<n>-<slug> origin/develop
   ```
   Use `fix/` for bugs, `feat/` for features (`feat!` commit prefix for breaking changes).
2. Launch one background agent per issue, all in parallel. Each agent prompt MUST include:
   - Work EXCLUSIVELY in its worktree path; never touch the main checkout.
   - Work fully autonomously; never wait for user input.
   - Step 1: read the issue with `gh issue view <n> --comments` and the worktree's CLAUDE.md.
   - Step 2: invoke the Skill tool with `feature-dev:feature-dev` to implement. Skip interactive steps; prefer the minimal robust fix.
   - Step 3: commit with a conventional-commit message.
   - Step 4: invoke the Skill tool with `pr-review-toolkit:review-pr` on the diff `origin/develop...HEAD`. Fix ALL critical and important findings; ignore nitpicks. Commit fixes.
   - Step 5: `git push -u origin <branch>` and open a PR to `develop` with `gh pr create --base develop`. Body in plain English: summary, what changed, verification, and the line `Fixes #<n>`.
   - Constraints: do NOT modify `CHANGELOG.md` or `VERSION` (prevents 7-way merge conflicts; release handles both). Verification: `bash -n` on every changed script, `cp .env.example .env` (gitignored, delete after) + `docker compose -p localai config --quiet`, `node --check welcome/app.js` if touched. Docker CLI may not be on PATH — try `/usr/local/bin/docker`.
   - Known facts from the codebase report (file, line numbers, verified behavior) — give each agent everything already learned during triage.
   - Push the agent to verify root causes upstream (WebFetch the upstream repo/Dockerfile/entrypoint) rather than trusting the issue's proposed fix. Issues regularly misdiagnose (wrong mount path vs stale volume; missing tool vs wrong endpoint).

## Phase 3 — Merge into develop

As each agent finishes (do not wait for all):
1. Read its PR diff (`gh pr diff <pr>`) and sanity-check it yourself — minimal, on-topic, matches the report.
2. Check mergeability: `gh pr view <pr> --json mergeable -q .mergeable`. `UNKNOWN` right after another merge is normal — poll a few times with short sleeps.
3. Merge with a merge commit (repo convention): `gh pr merge <pr> --merge`. Resolve conflicts manually if `CONFLICTING`.
4. After ALL merges, validate the combined `develop`: full `bash -n` list from CLAUDE.md "Testing Changes", `python3 -m py_compile start_services.py`, `node --check welcome/app.js`, compose config with a temp `.env`, and a repo-wide grep for anything a removal-type fix should have fully cleaned.

## Phase 4 — Release on develop

1. In a `develop` worktree: set `VERSION`, add the `CHANGELOG.md` section `## [X.Y.Z] - <today>` under `[Unreleased]` with Added/Changed/Removed/Fixed entries in the file's established style (one bold service name + detailed prose + `(#issue)` per entry). Match the file's actual conventions, not assumed ones (e.g. this changelog has never used compare links at the bottom).
2. Commit (`chore: release X.Y.Z`), push `develop`.
3. Open the release PR: `gh pr create --base main --head develop --title "Release X.Y.Z"` with a per-issue summary and `Fixes #<n>` lines for every issue in the batch (auto-close only fires when the merge reaches `main`, so these lines belong HERE, not only in the fix PRs).

## Phase 5 — Final integration review

The per-fix reviews cannot see interactions between fixes, so review the aggregate diff `origin/main...origin/develop`:
1. Launch review agents in parallel (read-only, on the main checkout): `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:comment-analyzer`, `pr-review-toolkit:silent-failure-hunter`. Skip test/type analyzers (no test suite, no typed code here).
2. Point them explicitly at cross-fix interactions (e.g. does fix A's preserve/cleanup logic interact with fix B's removals? Is the update-flow ordering in `apply_update.sh` still correct?), CHANGELOG factual accuracy, and paths other than `make update` (`git pull` + `make restart` is a documented user path — new secrets are NOT generated there).
3. Fix all critical and important findings (plus cheap correctness suggestions) directly on `develop`, verify (`bash -n`, targeted roundtrip tests under `bash -c`, compose config), push. The PR updates automatically.
4. If an external reviewer bot (e.g. CodeRabbit) commented on the PR, fetch its findings (`gh api repos/{owner}/{repo}/pulls/<pr>/comments`), verify each against the code, fix the valid ones, and reply to the inline comments with the fix commit.
5. Present the aggregated report (Critical / Important / Suggestions / deliberately skipped) and leave the release PR open for the user unless they said to merge it.

## Phase 6 — Publish (only on explicit user go-ahead)

1. `gh pr merge <release-pr> --merge`, then tag the merge commit: `git tag vX.Y.Z <sha> && git push origin vX.Y.Z` (v-prefix per existing tags).
2. `gh release create vX.Y.Z --title "vX.Y.Z"` — match the format of previous releases (`gh release view <prev>` first): changelog sections, an `## Upgrade` block with `make update` plus per-service migration notes, and a `**Full Changelog**` compare link.
3. Verify the issues auto-closed, then comment on each: fixed in release (link), one-line what changed, any caveat specific to that issue, and "please update with `make update`".

## Cleanup

Remove worktrees and branches once merged:
```bash
git worktree remove --force ../<repo-name>-worktrees/issue-<n>
git branch -D <branch> && git push origin --delete <branch>
```

## Hard-won rules (violating these caused real problems)

- Fix agents must never edit `CHANGELOG.md`/`VERSION` — the release commit owns them.
- Poll `mergeable` when it reports `UNKNOWN`; GitHub recomputes it after every merge to the base.
- `Fixes #N` in a PR targeting `develop` closes nothing — repeat the keywords in the release PR to `main`.
- New secrets in `03_generate_secrets.sh` are only generated by `make update`/`make install`; every fix that adds one needs a `doctor.sh` check and, where it matters, a `restart.sh` warning for the `git pull` + `make restart` path.
- When a fix removes a service, grep the whole repo for its name at the end; expect leftovers in GOST_NO_PROXY, wizard, welcome page, doctor, final report, update_preview, Caddyfile, docs, and add a one-time migration (see `cleanup_removed_*` functions in `scripts/utils.sh`).
- Never log success after a suppressed command (`|| true`); branch the message on the actual result.
