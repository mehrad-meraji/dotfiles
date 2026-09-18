Process all markdown files in the `!nbox/` directory of this Obsidian vault and sort them into the correct folders.

## Instructions

For each `.md` file in `!nbox/`:

1. Read the file content and existing frontmatter
2. Determine the correct `type` using these heuristics:
   - Contains a URL as primary content → `bookmark`
   - Technical how-to, command reference, tool notes → `knowledge`
   - References a known project or is clearly a project sub-note → `project-note`
   - New project overview with goals/scope → `project`
   - Product/item evaluation (shoes, gear, etc.) → `review`
   - Art or artist reference → `art`
   - Cannot determine confidently → leave in `!nbox/`, add to "uncertain" list
3. Determine the target folder:
   - `bookmark` → `Bookmarks/`
   - `knowledge` → `Knowledge Base/`
   - `project-note` → `Projects/<project-name>/` (if project folder exists; otherwise flag)
   - `project` → `Projects/<project-name>/` (create folder)
   - `review` → `Reviews/`
   - `art` → `Art/`
4. Build the correct frontmatter:
   - Base: `title`, `type`, `tags`, `summary` (generate 1-2 sentences), `created`, `updated` (today)
   - Type-specific extensions per the standard (bookmark adds source/publisher/read, project-note adds project/status, etc.)
   - Preserve any existing frontmatter values that map to standard fields
   - Remove deprecated fields: `done`, `priority`, `due-date`, `exclude-from-project`
5. Rewrite the frontmatter and move the file to the target folder

## Rules
- Never delete a file — only move it
- Never create a project folder silently — if a project-note's parent project doesn't exist as a folder, flag it and leave the file in `!nbox/`
- If uncertain about type → leave in `!nbox/`
- The `project:` field on project-notes uses wikilink format: `[[Project Name]]`

## Report Format
After processing all files, output a summary:

### Sorted
| File | Type | Moved to |
|------|------|----------|

### Left in !nbox (needs review)
| File | Reason |
|------|--------|
