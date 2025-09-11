# Repository Guidelines

## Project Structure & Module Organization
- `cgol.zig` — main Zig source (terminal Game of Life).
- `cgol` — compiled binary (regenerate after changes).
- `CLAUDE.md`, `GEMINI.md`, `.claude/` — agent docs and prompts.
- `.gitignore` — Zig defaults. No separate assets or modules yet.

## Build, Test, and Development Commands
- Build (debug): `zig build`
- Build (release): `zig build -Doptimize=ReleaseSafe`
- Install binary: `zig build install` (outputs to `zig-out/bin/cgol`)
- Run via build: `zig build run`
- Run with prompts forced: `zig build run -- -p` (or `--prompt-user-for-config`)
- Run installed binary: `./zig-out/bin/cgol`
- Tests: `zig build test`
- Format: `zig fmt .`

Notes: Target Zig 0.15.1+ (see history). If you change source layout or names, update `build.zig` accordingly.

## Coding Style & Naming Conventions
- Use `zig fmt` before committing; no manual stylistic tweaks.
- Indentation: 4 spaces; no tabs.
- Naming: types `UpperCamelCase`; functions/vars/consts `lowerCamelCase`; tests use short descriptive strings.
- Prefer explicit sizes (`u8`, `usize`) and `const` over `var` unless mutation is required.
- Keep functions small; isolate I/O from logic where practical.

## Testing Guidelines
- Use inline `test { ... }` blocks colocated with code (see `test "addWrap"`).
- Add focused unit tests for pure helpers; avoid flaky time-dependent checks.
- Run `zig build test` locally; add tests for new helpers.

## Commit & Pull Request Guidelines
- Commits: imperative, concise, scoped (e.g., `Fix wrap logic at edges`).
- Reference issues/PRs when relevant. Group unrelated changes into separate commits.
- PRs should include: clear summary, rationale, manual run steps (`zig run ...`), and screenshots/gifs if UI-visible output changed.
- Keep diffs minimal. Explain any behavior or CLI changes in the description.

## Architecture Overview & Tips
- Single-file terminal app using ANSI escape codes, toroidal grid wrap, RNG seeding, and `std.Thread.sleep` for pacing.
- Avoid introducing external deps; stick to Zig standard library.
- Terminal must support ANSI; Ctrl+C exits. No secrets/config required.

## Configuration
- File: `cgol.toml` in repo root. Missing or partial values trigger prompts; complete files skip prompts.
- Keys: `rows` (usize), `cols` (usize), `generations` (u64, 0=infinite), `delay_ms` (u64).
- Example:
  ```toml
  rows = 40
  cols = 60
  generations = 100
  delay_ms = 100
  ```
- Update behavior: the app writes a full `cgol.toml` after resolving values. Delete the file to re-prompt.

## CLI Options
- `--height <rows>` / `--width <cols>` — set board size.
- `--generations <n>` — 0 for infinite.
- `--delay <ms>` — delay per generation in milliseconds.
- Positional form: `cgol <rows> <cols> <generations> <delay>` (e.g., `cgol 30 15 50 40`).
