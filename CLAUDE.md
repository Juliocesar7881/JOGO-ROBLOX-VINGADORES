# CLAUDE.md

Guidance for Claude Code sessions working in this repository.

## What this is

"Multiverse Doomsday — Última Defesa," a cooperative Roblox tower-defense
built entirely from Luau source (no Toolbox assets — maps, heroes, enemies
and VFX are all authored by script and built to `.rbxlx` by
`tools/build.py`). Heroes, villains and places are original: no third-party
name reaches a player (`tests/ip_blocklist.json`, `tests/test_ip_safety.py`). Portuguese is the primary player-facing language; English
is the secondary one via the `text(pt, en)` helper. Reply to the user in
Portuguese unless they switch.

## Build and test

```bash
python tools/setup_luau.py   # once: downloads the official Luau CLI, checks its SHA256
python tools/build.py        # generates dist/Doomsday-{Studio,Lobby,Match}.rbxlx
python tools/test.py         # compiles everything, runs the whole suite, then builds
```

`tools/test.py` is the single command that must pass before any commit: Luau
compile of every source file, `docs/HEROES.md` freshness, ~900k rule/economy
assertions, PlayerService/PartyService against deterministic Roblox doubles,
a full match simulated end to end outside Roblox, the real server and client
booted against Roblox stand-ins (fails on any Lua error, not just a wrong
assertion), UI layout on ~9 real screen sizes, and native-place generation.
It does **not** cover teleport, reserved servers, real Robux purchases,
mobile performance or touch input — those need a published place and a real
device.

Useful narrower runs:
- `python tests/test_match_simulation.py --sweep rosters [--roster <name>]` —
  table of wave/win-rate per roster/map/mode (`tests/balance_sweep.luau`).
- `python tests/test_match_simulation.py --sweep heroes` — every hero paired
  with Iron Man, ranked mode: the way to check one hero's power in isolation
  (`tests/hero_sweep.luau`).
- `python tests/test_match_simulation.py --sweep duel` — raw tower DPS at
  equal match-Gold budget, no ability (`tests/duel_sweep.luau`).
- `.tools/luau/luau.exe tools/gen_heroes_doc.luau > docs/HEROES.md` —
  regenerate the hero reference after any Catalog change.
- `python tools/generate_audio.py` — rebuild the original WAVs in
  `assets/audio` (own synthesis; `manifest.json` holds their hashes, checked
  by `tests/test_audio.py`/`tests/test_release.py`).
- `python tools/release.py --config deployment/local.json --check` — validate
  the real account IDs; drop `--check` to write release places to
  `dist/release`. `deployment/local.json` is gitignored; only
  `deployment/template.json` (all zeros) is committed. See `docs/DEPLOYMENT.md`.

## The one invariant that matters most

**The client sends intent; the server decides.** Cost, ownership, range,
balance, cooldown, damage and reward are computed only in
`src/server/*.luau`, from data in `src/shared/Catalog.luau` and pure
functions in `src/shared/Rules.luau`. The client (`src/client/*.luau`) never
computes a rule — it renders whatever the server's `State`/`FX` events say
and sends a `Request` action naming what the player wants to do. An invalid
request is refused without changing state, never silently clamped. See
`IMPLEMENTATION.md` for the full networking contract (action names, snapshot
shape) before adding a new one.

## Layout

```
src/shared/   Catalog (all game data), Config (IDs/environment), Rules (pure
              functions), Waves (deterministic wave generator)
src/server/   init.server (bootstrap/router), MatchService, PlayerService,
              PartyService, ElevatorService, WorldBuilder, PresenceService,
              AnalyticsService, RejoinService
src/client/   init.client (controller), UI (layout + widgets), Panels (lobby
              panels), MatchHud, LobbyWorld, Tutorial (arrow-taught training),
              Effects, Audio, Nameplates, AutoQuality, Review (Studio only)
tools/        build.py, test.py, setup_luau.py, gen_heroes_doc.luau, sweeps
tests/        real-module tests via the official Luau CLI + deterministic
              Roblox stand-ins (tests/roblox_stubs.luau and friends)
docs/         HEROES.md (generated), design/balance/deployment/status notes
assets/audio/ original WAVs + manifest (import into Roblox, then put IDs in
              deployment/local.json)
deployment/   template.json of every account ID the release needs
```

## Working conventions

- `src/shared/*.luau` are data or pure functions only — never
  `game:GetService`. That is what lets `Rules.luau` be tested completely
  outside Roblox, in seconds.
- Every player-facing string is `{ pt = "...", en = "..." }`.
- A chest's random rolls are drawn **before** the DataStore transaction,
  because `UpdateAsync` may replay its callback; drawing the roll inside the
  callback would let a replay pick a different hero for the same commit.
- Balance numbers (hero cost/damage/range, ability power, chest odds) live in
  `Catalog.luau`; the formulas that turn them into behaviour live in
  `Rules.luau`. A new hero, ability, card or chest is a data change, not a
  new code path, unless it needs a genuinely new mechanic.
- This repo is worked on by two people (plus their AI sessions) at once. Run
  `git status` before editing, keep commits small and focused, and see
  `CONTRIBUTING.md` for the rest.

## Attribution

Commit messages and PR descriptions end with the attribution lines given in
this session's own system reminder — do not hand-write different ones.

## What the owner has asked for (standing rules)

- No mascot or guide character: the newcomer is taught by arrows (`Tutorial.luau`).
- No blown-out glow (Bloom <= ~0.2, no pale Neon: `World.TameNeon`); `tools/studio_review.py`
  prints GLARE when a capture is washed out.
- Scenery is solid (`World.SolidifyProps`); decoration carries no floating title.
- Language follows the Roblox locale; every server message is "pt / en".
- Hero names are descriptive epithets (see `docs/HEROES.md`); exact third-party names
  stay on `tests/ip_blocklist.json`. The look of the league heroes is a close homage:
  flag the IP risk before any public release.
- Run `python tools/test.py > out.txt; echo $?`: piping into `tail` hides a failing exit code.
