# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Conway's Game of Life implementation written in Zig. The project consists of a single file (`cgol.zig`) that implements an interactive, terminal-based Game of Life simulator with toroidal wrapping.

## Build and Development Commands

### Building the Project
```bash
zig build                              # Debug build
zig build -Doptimize=ReleaseSafe      # Release build
zig build install                     # Install to zig-out/bin/cgol
```

### Running the Application
```bash
zig build run                         # Run via build system
zig build run -- -p                   # Force prompts (--prompt-user-for-config)
./zig-out/bin/cgol                    # Run installed binary
```

### Running Tests
```bash
zig build test
```

### Code Formatting
```bash
zig fmt .                             # Format all Zig files
```

### Configuration
The application will prompt for missing values or you can provide them via:

#### Configuration File (`cgol.toml`)
```toml
# Game of Life config
rows = 40
cols = 60
generations = 0    # 0 = infinite
delay_ms = 100
```

#### Command Line Options
```bash
# Named flags
cgol --height 40 --width 60 --generations 100 --delay 80
cgol --height=40 --width=60 --generations=100 --delay=80

# Positional arguments
cgol 40 60 100 80    # rows cols generations delay_ms
```

**Flag Options:**
- `--height <rows>` / `--width <cols>` — Set board dimensions
- `--generations <n>` — Number of generations (0 = infinite)
- `--delay <ms>` — Delay between generations in milliseconds

## Code Architecture

The implementation is self-contained in a single Zig file with these key components:

### Core Functions
- `idx(r: usize, c: usize, cols: usize)`: Converts 2D grid coordinates to 1D array index
- `addWrap(i: usize, delta: i32, max: usize)`: Handles toroidal boundary wrapping for the Game of Life grid

### Main Logic Flow
1. **Input Phase**: Collects user preferences for grid size, generations, and animation speed
2. **Memory Management**: Allocates two grids (current and next generation) using Zig's allocators
3. **Initialization**: Seeds the grid with ~35% probability of live cells using random number generation
4. **Game Loop**: 
   - Renders current state using ANSI escape codes for terminal graphics
   - Calculates next generation following Conway's rules with 8-neighbor toroidal topology
   - Double-buffers between grids for efficient updates
   - Applies configurable delay between generations

### Technical Details
- Uses ANSI escape sequences for cursor control and colored output
- Implements toroidal topology (edges wrap around)
- Memory-efficient double-buffering approach
- Arena allocator for temporary allocations, GeneralPurposeAllocator for grid data
- Single-file implementation using only Zig standard library
- Terminal size detection for optimal display
- Configuration auto-saves to `cgol.toml` after prompts

## Development Guidelines

### Code Style
- Use `zig fmt` before committing (4 spaces, no tabs)
- Types: `UpperCamelCase`; functions/vars/consts: `lowerCamelCase`
- Prefer explicit types (`u8`, `usize`) and `const` over `var`
- Keep functions small and isolate I/O from logic

### Testing
- Use inline `test { ... }` blocks colocated with code
- Add unit tests for pure helper functions
- Run `zig build test` locally before commits
