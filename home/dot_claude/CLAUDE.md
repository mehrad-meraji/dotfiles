# Global rules

## Web search

**Use `mcp__glean__search` for open-web searches. Fall back to `WebSearch` only if Glean fails or returns nothing useful.**

Glean here is a web search tool (Google CSE) that also extracts page content, so one call usually replaces a search plus several fetches. Use `mcp__glean__extract` to pull the full text of specific URLs.

Glean tools are deferred, so load them first:

```
ToolSearch: select:mcp__glean__search,mcp__glean__extract
```

Fall back to `WebSearch` / `WebFetch` when:

- The Glean server is not connected or errors out.
- Results come back empty or off-topic.
- A result lists the URL under `failed_extracts` and you still need that page — try `WebFetch` on it.

This is about the open web only. Keep using Grep/Glob for local files.

## Git worktrees

**Worktrees live inside their own repo. Nowhere else.**

- Claude Code worktrees (`EnterWorktree`, `isolation: "worktree"`): `<repo>/.claude/worktrees/<name>`. This is the tool default, keep it.
- Manual `git worktree add` (superpowers skill, scripts, by hand): `<repo>/.worktrees/<name>`. This is the declared worktree directory for the `using-git-worktrees` skill.
- Never make a worktree as a sibling folder in `/Users/mehrad/Projects` (like `glean-sentinel` or `historytrail-task1`). It looks like a separate project and makes duplicates in the Projects index.
- Never use `~/.config/superpowers/worktrees` or other tool folders outside the repo.
- Before making one, check the folder is ignored: `git check-ignore -q .worktrees/x`. If not, add the folder to `.git/info/exclude`. Do not commit a `.gitignore` change for this.
- When the branch is merged or dropped, remove the worktree with `git worktree remove`. Save uncommitted work first (commit or `git stash`).

## Obsidian vault

Project notes live at:

```
/Users/mehrad/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes/Projects/
```

One folder per project. `Projects.md` is the **master index** — it maps every project to its vault note, its repo path under `/Users/mehrad/Projects`, and when it last moved.

Keep `Projects.md` current. Whenever a project is created, archived, renamed, or changes state, update its row there and bump `updated:` in the frontmatter. Archived repos move to the "Archived / superseded" section rather than being deleted. Do not start a second project list — `Projects.md` is the only one.

"Document X" means write a markdown note in that project's vault folder, not in the code repo.

## Maintain 

~/code/papercuts.md, a global log shared by all my Claude sessions of anything that slowed down development. When you lose time to one mid-session, append date · symptom · fix · project. Check this file first when tooling fails mysteriously.
