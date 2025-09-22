# Repository Guidelines

## Project Structure & Module Organization
Runtime code now lives under `src/`: `main.zig` orchestrates configuration, rendering, and simulation; `cli.zig`, `config.zig`, `input.zig`, and `renderer.zig` own the interface work; `game.zig` houses core rules plus inline tests; `patterns.zig` loads RLE/plaintext/Life 1.06 files; shared constants sit in `constants.zig`. Keep build logic in `build.zig`, which targets `src/main.zig`. Sample seeds reside in `patterns/`, and generated binaries land in `zig-out/bin/cgol`. Reference docs for other agents remain in `CLAUDE.md`, `GEMINI.md`, and `.claude/`.

## Build, Test, and Development Commands
`zig build` compiles a debug build; add `-Doptimize=ReleaseSafe` for safer release binaries. `zig build run` executes the app; append `-- --prompt-for-config` (or `-p`) to force interactive prompts, or `-- --pattern patterns/gosperglidergun.rle` to load a preset. Install to `zig-out/bin/` with `zig build install`, then run `./zig-out/bin/cgol` for smoke checks. Always finish with `zig build test` to execute inline unit tests.

## Coding Style & Naming Conventions
Run `zig fmt .` before posting changes—manual spacing tweaks are discouraged. Use four spaces, no tabs. Prefer explicit integer widths and default to `const` unless mutation is required. Follow Zig casing: `UpperCamelCase` types, `lowerCamelCase` functions, variables, and consts. Keep rendering/input concerns in their modules and leave pure grid logic inside `game.zig` to simplify testing.

## Testing Guidelines
Inline `test "description" { ... }` blocks should sit next to the logic they exercise—see `src/game.zig` for patterns. Cover toroidal wrapping, oscillator regressions, pattern parsing, and failure paths. Use deterministic seeds or fixtures (e.g., small buffers, sample files in `patterns/`) so `zig build test` stays fast and reliable. Document any helper routines inside the test block when intent is not obvious.

## Commit & Pull Request Guidelines
Write imperative, scoped commits (`Add RLE parser fallback`). Reference related issues or PRs when applicable. Pull requests should explain motivation, list manual verification (`zig build run`, `zig build test`, key CLI invocations), and call out config or UX changes. Include terminal captures when rendering behavior shifts.

## Configuration & Runtime Notes
The app reads `cgol.toml` at the repo root with keys `rows`, `cols`, `generations` (`0` = infinite), and `delay_ms`. Missing values trigger prompts; the program then rewrites the full file for future runs. Remove `cgol.toml` or pass `-p/--prompt-for-config` to regenerate. When loading patterns, files must fit the grid; the renderer centers them automatically and falls back to pseudo-random initialization if parsing fails.
