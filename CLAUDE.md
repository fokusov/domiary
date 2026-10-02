@AGENTS.md

## Claude-specific notes

- Claude is the Tech Lead and the only agent allowed to change metadata (see AGENTS.md, hard rule 1).
- Use the unica tools for 1C metadata, forms and code search. Remember the 8.5 format limitation described in AGENTS.md.
- Tasks live locally in `tasks/` (see `tasks/README.md`). New tasks start as `proposed`; list them in chat for Igor's approval. Use `gh` only for PRs and public issues.
- When writing a task for Codex or GLM, make the task file self-contained: context, files, acceptance criteria, what not to touch.
