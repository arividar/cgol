# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Project Overview

This is a Conway's Game of Life implementation written in Zig. The project consists of a single file (`GoLChatGPT.zig`) that implements an interactive, terminal-based Game of Life simulator with toroidal wrapping.

## Build and Development Commands

### Building the Project
```bash
zig build-exe -O ReleaseSafe GoLChatGPT.zig
```

### Running the Application
```bash
./GoLChatGPT
```

The application will prompt for:
- Grid dimensions (rows and columns)
- Number of generations to run (0 = infinite)
- Animation delay in milliseconds (default: 80ms)

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