# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Project Overview

This is a Conway's Game of Life implementation written in Zig. The project is a terminal-based application that has been refactored from a single file into a modular, multi-file structure. It implements an interactive Game of Life simulator with toroidal wrapping, pattern loading, and configuration management.

## Build and Development Commands

### Building the Project
```bash
zig build
```

### Running the Application
```bash
zig build run
```

The application will first look for a `cgol.toml` file for configuration. If the file is not found, or if some settings are missing, it will prompt the user for:
- Grid dimensions (rows and columns)
- Number of generations to run (0 = infinite)
- Animation delay in milliseconds

The application also supports command-line arguments to override the configuration file and prompts.

## Code Architecture

The implementation is organized into several files within the `src` directory, each with a specific responsibility:

- `main.zig`: The main entry point of the application. It orchestrates the entire application flow, from parsing arguments and configuration to running the simulation.
- `game.zig`: Contains the core Game of Life logic, including functions for calculating the next generation (`stepGrid`), counting neighbors, and initializing the grid.
- `renderer.zig`: Manages all terminal output, including rendering the game grid, drawing the frame, and displaying status information. It also handles terminal size detection and layout calculations.
- `config.zig`: Handles loading and saving game configuration to and from the `cgol.toml` file.
- `cli.zig`: Responsible for parsing command-line arguments.
- `input.zig`: Provides a simple reader for user input from the terminal.
- `patterns.zig`: Implements the logic for loading and applying patterns from various file formats (`.rle`, `.cells`, `.life`).
- `constants.zig`: A central place for all the constants used in the application, such as default values, ANSI escape codes, and file names.

### Core Functions
- `game.idx(r: usize, c: usize, cols: usize)`: Converts 2D grid coordinates to a 1D array index.
- `game.addWrap(i: usize, delta: i32, max: usize)`: Handles toroidal boundary wrapping for the Game of Life grid.
- `game.stepGrid(curr: []const u8, rows: usize, cols: usize, next: []u8)`: Computes the next generation of the grid.
- `renderer.renderFrame(grid: []const u8, rows: usize, cols:usize, generation: usize)`: Renders a single frame of the simulation to the terminal.
- `patterns.loadPattern(allocator: std.mem.Allocator, filename: []const u8)`: Loads a pattern from a file.

### Main Logic Flow
1.  **Argument Parsing**: The application starts by parsing command-line arguments using the `cli` module.
2.  **Configuration**: It then loads the configuration from `cgol.toml` using the `config` module. If the file doesn't exist or is incomplete, it prompts the user for the missing values.
3.  **Initialization**: The `main` module initializes the game state, including allocating the grids and setting up the initial pattern (either random or from a file).
4.  **Terminal Setup**: The `renderer` module sets up the terminal, hiding the cursor and determining the terminal dimensions.
5.  **Game Loop**: The main loop in `main.zig` runs the simulation for the configured number of generations. In each iteration, it:
    - Renders the current state of the grid using the `renderer` module.
    - Calculates the next generation of the grid using the `game.stepGrid` function.
    - Swaps the current and next grid buffers.
    - Pauses for the configured delay.
6.  **Cleanup**: After the loop finishes, the application restores the terminal state.

### Technical Details
- Uses ANSI escape sequences for cursor control and colored output.
- Implements toroidal topology (edges wrap around).
- Memory-efficient double-buffering approach for grid updates.
- Supports loading patterns from `.rle`, `.cells`, and `.life` files.
- Manages configuration through a `cgol.toml` file.
- Automatically adjusts the grid size to fit the terminal.