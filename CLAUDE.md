# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Conway's Game of Life implementation written in Zig. The project implements an interactive, terminal-based Game of Life simulator with toroidal wrapping, now organized into multiple modules for better maintainability.

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

The project is organized into several modules in the `src/` directory:

### Module Structure
- **`main.zig`**: Entry point, orchestrates all modules and main game loop
- **`game.zig`**: Core Conway's Game of Life logic and grid operations
- **`config.zig`**: Configuration file parsing and management (`cgol.toml`)
- **`cli.zig`**: Command-line argument parsing and help display
- **`renderer.zig`**: Terminal rendering with ANSI escape sequences
- **`input.zig`**: User input handling for interactive prompts
- **`constants.zig`**: Centralized constants and configuration values

### Key Functions
- **Game logic**: Grid initialization, neighbor counting with toroidal wrapping
- **Configuration**: TOML parsing, CLI argument handling, interactive prompts
- **Rendering**: ANSI terminal control, frame rendering, layout calculation

### Main Logic Flow
1. **CLI Parsing**: Process command-line arguments and help requests
2. **Configuration**: Load from file, merge with CLI args, prompt for missing values
3. **Setup**: Initialize renderer, allocate grids, calculate terminal layout
4. **Simulation**: Double-buffered grid updates with configurable timing
5. **Rendering**: Frame-by-frame display with generation counter

### Technical Details
- Uses ANSI escape sequences for cursor control and colored output
- Implements toroidal topology (edges wrap around)
- Memory-efficient double-buffering approach
- Arena allocator for temporary allocations, GeneralPurposeAllocator for grid data
- Modular design using Zig's import system
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
