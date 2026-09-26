# AGENTS.md

Instructions for any AI agent (Cursor, Claude Code, others) working in this
repository. Read `CLAUDE.md` first: it has the build/test commands, the
server-authority rule and the code layout. This file adds how the two of us
work together at the same time.

## Two people, one game

- The **Luau files in this repo are the source of truth**. Roblox Studio (Team
  Create, experience "Multiverse Doomsday Tower Defense", place
  97132875544830) is a shared live preview, not where code lives.
- Never edit scripts directly inside Studio: the next sync or build overwrites
  them. Edit the files here, then push them into Studio (below).
- Before starting: `git pull --rebase`. Commit small, push often, and say in
  the commit what area you touched. `python tools/test.py` must pass before
  every commit.
- Split work by area to avoid conflicts (for example: one person on the
  lobby/`WorldBuilder.luau`, the other on a new hero/`Catalog.luau` + `Rules.luau`).
  `src/client/init.client.luau` is large and shared: keep edits there small
  and pull right before touching it.

## Seeing changes live in Studio (Windows)

1. Open the Team Create place in Studio and stay in **edit mode** (not Play).
2. Push only the files you changed:
   `python tools/studio_sync.py src/server/WorldBuilder.luau src/shared/Catalog.luau`
   Add `--preview-lobby` to rebuild the lobby in the editor viewport.
3. Everyone in the Team Create session sees the change immediately.

`tools/studio_sync.py` drives the Studio command bar through Windows UI
Automation (`tools/studio_action.ps1`), refuses to write during a playtest,
and confirms every file from Studio's log. Sync only the files you changed:
syncing everything can overwrite a file your partner just pushed into Studio.

## Language

The player-facing language is Portuguese (`{ pt = ..., en = ... }` for every
string). Reply to the humans in Portuguese.
