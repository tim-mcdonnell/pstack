# Syncing this mirror

This repo mirrors [`cursor/plugins/pstack`](https://github.com/cursor/plugins/tree/main/pstack) so it installs with `npx skills add` and runs in Claude Code (and Codex, Pi, OpenCode). The approach and the initial harness-neutral rewrites come from [`backnotprop/pstack`](https://github.com/backnotprop/pstack) (MIT).

Two branches keep upstream and our edits apart:

- `upstream` holds Cursor's `pstack/` folder byte for byte. Never edit it by hand.
- `main` is `upstream` plus this mirror's edits: the top of `README.md`, this file, `sync/`, `.upstream-rev`, `skills/no-comments/references/comment-sicko.md`, and harness-neutral rewrites inside some skills.

Never copy Cursor's files onto `main` directly. That erases the edits. Always go through `upstream` and merge.

`.upstream-rev` records the `cursor/plugins` commit that `upstream` mirrors. `.cursor-plugin/plugin.json` stays on `main` only because upstream bumps its `version` every release; deleting it would cause a modify/delete conflict on every sync. It is inert outside Cursor.

## Sync procedure

```bash
sync/sync.sh check     # exit 0 = nothing to do, exit 10 = upstream moved
sync/sync.sh pull      # refresh upstream branch, merge into main, print the Cursor-ism report
# ...resolve conflicts / rewrite new Cursor-only instructions (see below)...
sync/sync.sh push      # push main + upstream
```

`pull` already refreshes the bundled Comment Sicko prompt (`skills/no-comments/references/comment-sicko.md` is a copy of `agents/comment-sicko.md`) and records the new rev.

After `pull`, work through its report:

1. **Conflicts.** A conflict means Cursor changed a line we also changed. Keep Cursor's new meaning and reapply the harness-neutral wording from the rules below.
2. **New Cursor-specific lines.** Every hit in the report is either rewritten per the rules, or deliberately left (and said so in the commit message) because it is a Cursor-only feature with no analogue, such as Bugbot triage internals.
3. **New skills or playbooks.** Read each new file in full, not just the grep hits. Apply the rules.
4. **Verify.** `grep -rnE 'Task tool|AskQuestion|~/.cursor/rules|agent-transcripts' skills | grep -v 'in Cursor'` should return only lines that already name the non-Cursor alternative.
5. Commit on `main` with the message `Sync upstream cursor/plugins/pstack @ <rev> (<version>)` plus a short list of what was rewritten and what was left Cursor-only.

## Conversion rules

The authoritative mapping lives in the **Harness** section of `skills/poteto-mode/SKILL.md`. Keep that section and these rules in agreement. Edits are additive: name the Cursor thing, then the equivalent elsewhere. Do not delete Cursor instructions, because the mirror must stay faithful and later upstream diffs must still apply.

| Cursor-specific | Rewrite to |
|---|---|
| `Task` tool / `subagent_type: generalPurpose` | "your subagent tool: `Agent` in Claude Code (`subagent_type: general-purpose`), `task` in OpenCode (`subagent_type: general`), `spawn_agent` in Codex. Drop parameters your tool doesn't have. Without a subagent tool, do each step yourself in sequence." Add this once per skill as an **Other harnesses.** paragraph next to the first spawn. |
| `environment: "cloud"`, `cloud_base_branch`, Cursor cloud agents | Run locally in its own worktree; drop the parameter. |
| `AskQuestion` | "your structured-question tool (`AskQuestion` in Cursor, `AskUserQuestion` in Claude Code, `question` in OpenCode); without one, ask in chat with numbered options." |
| `~/.cursor/rules/pstack-models.mdc`, "the `pstack-models.mdc` rule" | "the pstack settings file (`~/.cursor/rules/pstack-models.mdc` in Cursor, `~/.agents/pstack-models.md` in other harnesses)". "If the rule ... is missing" becomes "If the file ... is missing". |
| `agent-transcripts/`, `~/.cursor/projects/<slug>/` | Per-harness list: Cursor `~/.cursor/projects/<slug>/agent-transcripts/`; Claude Code `~/.claude/projects/<slug>/*.jsonl` (slug = path with every non-alphanumeric char turned into `-`); Pi `~/.pi/agent/sessions/--<slug>--/`; Codex `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` filtered by `payload.cwd`; OpenCode `~/.local/share/opencode/storage/`. |
| `.cursor/skills/`, `~/.cursor/skills/` | Add `.claude/skills/`, `.pi/skills/`, `.agents/skills/` (project) and `~/.claude/skills/`, `~/.pi/agent/skills/`, `~/.codex/skills/`, `~/.agents/skills/` (user). |
| `create-skill` (Cursor built-in) | "your skill-authoring skill: `create-skill` in Cursor or Anthropic's `skill-creator`; otherwise follow the Agent Skills format at agentskills.io." |
| `deslop`, `control-cli`, `control-ui` (`cursor-team-kit`) | Point at the **Harness** section: without `deslop`, reread the diff and cut slop yourself; without control skills, drive the app with Playwright/CDP or tmux/PTY. |
| `poteto-agent`, `Comment Sicko` as registered subagents | Spawn a general subagent whose prompt starts with the agent file's contents (`agents/*.md`). `no-comments` ships its copy under `references/`. |
| "a Cursor restart" and similar incidental mentions | "a Cursor or harness restart". |
| `mcps/` directory Cursor exposes | MCP tools appear in the tool list, e.g. `mcp__<server>__<tool>` in Claude Code. |
| Scripts (`*.sh`, `*.ts`) hard-coding `~/.cursor/projects` | Add the Claude Code and Pi paths alongside, as `worktree-audit.sh` does. |
| Cursor model slugs (`claude-opus-5-5-max`, `grok-4.7-xhigh-fast`) in Claude Code | Covered once by the **Claude Code specifics** Harness bullet: `Agent` takes `opus`/`sonnet`/`haiku`; `gpt-*`/`grok-*` roles run on `opus` or go cross-provider via T3 `delegate_task`. Don't rewrite the slugs themselves; they are the settings-file vocabulary. |
| macOS-only shell (`stat -f`, `date -r`, BSD `sed -i ''`) in scripts | Branch on GNU vs BSD at the top of the script, as `worktree-audit.sh` does. Not a Cursor-ism, but upstream is written on macOS and we run on Linux. |
| Cursor-only frontmatter (`mode`, `icon`, `color`, `reminder`, `is_background`) | Leave it. Claude Code ignores unknown keys; `paths` and `disable-model-invocation` are shared vocabulary. |
| Custom Modes (Option+Enter / Alt+Enter on a skill, "Use as Mode", the old "sticky mode") | "Other harnesses have no Custom Modes. In Claude Code an invoked skill stays in the transcript until compaction; reinvoke it or pin it from `CLAUDE.md` / `AGENTS.md`." Point at the **Custom Modes** Harness bullet. |
| `/add-plugin pstack`, Customize sidebar | Add `npx skills add <repo url>` from the mirror README. |

Leave alone: `README.md` below the `mirror:end` marker, `docs/guide/*` (upstream prose, mentions Cursor as the product and that is fine), `automations/benny/*` (Cursor cloud automations by design), `.cursor-plugin/plugin.json`, and `scripts/watch-pr/*` GitHub code that merely names Bugbot as a reviewer.

## Beyond the grep

The report in `sync/sync.sh` only catches known patterns. On every sync also check:

- **New scripts** under `skills/*/scripts/` for macOS-only commands. Run any `.sh` once on this machine.
- **New frontmatter keys** in `SKILL.md` and `agents/*.md`. Only add a mapping if a key breaks Claude Code's loader.
- **New runtime dependencies** (`bun`, `node`, `rg`, `gh`). Note them in the mirror README if a skill cannot run without one.
- **New model slugs or roles** in `setup-pstack`. The Claude Code specifics bullet in the Harness section must still describe how to map them.

## Where this mirror differs from backnotprop/pstack

backnotprop's rewrites were the seed. These are ours and must survive syncs:

- Harness section bullets **Claude Code specifics** and **T3 Code specifics** in `skills/poteto-mode/SKILL.md`.
- Pointers back to the Harness section in `playbooks/orchestrate.md`, `playbooks/opening-a-pr.md`, and `playbooks/multi-phase-plan.md`, which backnotprop left Cursor-only.
- GNU/BSD portability in `scripts/worktree-audit.sh`.
- `sync/sync.sh` and `.upstream-rev` instead of a manual checklist.

When backnotprop ships a rewrite we lack, cherry-pick the idea, not the commit: our `main` history is not related to his.

## Sync agent brief

This is the prompt the T3 Code scheduled task runs. It is reproduced here so a human can run the same thing by hand.

> You maintain the pstack mirror at this repo. Run `sync/sync.sh check`. If it exits 0, reply with one line and stop. If it exits 10, run `sync/sync.sh pull`, then follow MIRROR.md "Sync procedure" steps 1 to 5: resolve conflicts, rewrite every new Cursor-specific instruction per the "Conversion rules" table, read any newly added skill or playbook in full, run the verification grep, work through the "Beyond the grep" checklist, and commit on `main`. Keep edits additive and minimal; never delete upstream content. Update the **Harness** section of `skills/poteto-mode/SKILL.md` if a new mapping was needed, and add the row to MIRROR.md's table. Finally run `sync/sync.sh push`. If push fails because the Forgejo remote is unreachable, say so and leave the commits local. Report: upstream old and new rev and version, files rewritten, anything left Cursor-only and why, and the push result.
