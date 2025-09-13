# Repository Guidelines

## Project Structure & Module Organization
- `cgol.zig` — main Zig source (terminal Conway’s Game of Life).
- `build.zig` — build configuration; update if paths/names change.
- `zig-out/bin/cgol` — installed binary (via `zig build install`).
- `CLAUDE.md`, `GEMINI.md`, `.claude/` — agent docs/prompts.
- `.gitignore` — Zig defaults. No external assets/modules.

## Build, Test, and Development Commands
- Build (debug): `zig build` — compiles with debug info.
- Build (release): `zig build -Doptimize=ReleaseSafe` — safer optimizations.
- Install: `zig build install` — places binary at `zig-out/bin/cgol`.
- Run (build runner): `zig build run`.
- Force prompts: `zig build run -- -p` (alias `--prompt-user-for-config`).
- Run installed: `./zig-out/bin/cgol`.
- Tests: `zig build test` — runs inline tests.
- Format: `zig fmt .` — formats all Zig files.

## Coding Style & Naming Conventions
- Use `zig fmt` before committing; no manual styling tweaks.
- Indentation: 4 spaces; no tabs.
- Naming: types `UpperCamelCase`; functions/vars/consts `lowerCamelCase`.
- Prefer explicit sizes (`u8`, `usize`) and `const` unless mutation is required.
- Keep functions small; separate I/O from pure logic where practical.

## Testing Guidelines
- Use inline `test { ... }` blocks colocated with code (e.g., `test "addWrap"`).
- Add focused unit tests for pure helpers; avoid time-dependent checks.
- Run locally with `zig build test` and keep tests deterministic.

## Commit & Pull Request Guidelines
- Commits: imperative, concise, and scoped (e.g., `Fix wrap logic at edges`).
- Reference related issues/PRs. Group unrelated changes into separate commits.
- PRs include: clear summary, rationale, manual run steps (`zig build run`), and screenshots/gifs if terminal output changed. Document any CLI/config behavior changes.

## Architecture & Configuration
- Single-file terminal app using ANSI escape codes, toroidal wrap, RNG seeding, and `std.Thread.sleep` for pacing. No external dependencies beyond Zig std.
- Config file: `cgol.toml` at repo root. Keys: `rows` (usize), `cols` (usize), `generations` (u64, 0=infinite), `delay_ms` (u64). Missing/partial config triggers prompts; the app writes a full `cgol.toml`. Delete it to re-prompt.
- CLI options: `--height <rows>`, `--width <cols>`, `--generations <n>`, `--delay <ms>`, or positional `cgol <rows> <cols> <generations> <delay>`.
