# Save/Load Game States - Implementation Plan

## Overview
This document outlines the detailed implementation plan for step 2.2 of the Conway's Game of Life improvements: Save/Load Game States functionality.

## Current Codebase Analysis

### Existing Architecture
- **Modular structure**: Well-organized modules (game.zig, config.zig, cli.zig, etc.)
- **Configuration system**: Already has TOML-based config loading/saving
- **CLI parsing**: Supports named flags and positional arguments
- **Grid representation**: Simple `[]u8` array with helper functions
- **Memory management**: Uses arena allocator for temporary allocations

### Integration Points
- **CLI module**: Extend with `--save` and `--load` flags
- **Game module**: Add serialization/deserialization functions
- **Main loop**: Add save/load trigger points
- **Config system**: Reuse existing file I/O patterns

## Design Specifications

### 1. File Format Design

#### Option A: TOML Format (Recommended)
**Advantages**: Human-readable, consistent with existing config system, familiar format
**File extension**: `.cgol`

```toml
# Conway's Game of Life Save File
version = "1.0"

[metadata]
saved_at = "2025-09-23T14:30:00Z"
description = "Gosper glider gun at generation 150"
original_pattern = "gosperglidergun.rle"

[game_state]
current_generation = 150
rows = 40
cols = 60
generations = 1000
delay_ms = 100

[grid_data]
encoding = "rle_compressed"
data = "40b$5bo$3bo$4b2o$..."
```

#### Option B: Binary Format
**Advantages**: Smaller file size, faster I/O
**File extension**: `.cgol`

```zig
const SaveFileHeader = struct {
    magic: [4]u8 = "CGOL",
    version: u16 = 1,
    rows: u32,
    cols: u32,
    generation: u64,
    generations: u64,
    delay_ms: u64,
    metadata_size: u32,
    grid_data_size: u32,
};
```

### 2. Data Structures

```zig
// In a new module: src/saveload.zig

const SavedGameState = struct {
    // Metadata
    version: []const u8,
    saved_at: []const u8,
    description: ?[]const u8,
    original_pattern: ?[]const u8,
    
    // Game state
    current_generation: u64,
    rows: usize,
    cols: usize,
    generations: u64,
    delay_ms: u64,
    
    // Grid data (compressed)
    grid_data: []const u8,
    
    pub fn deinit(self: *SavedGameState, allocator: std.mem.Allocator) void {
        // Cleanup allocated strings
    }
};

const SaveLoadError = error{
    InvalidFileFormat,
    UnsupportedVersion,
    CorruptedData,
    IncompatibleGridSize,
    FileNotFound,
    PermissionDenied,
};
```

### 3. Grid Compression Strategy

#### RLE (Run-Length Encoding) for Sparse Grids
```zig
// Compress grid using RLE for efficient storage
fn compressGrid(grid: []const u8, rows: usize, cols: usize, allocator: std.mem.Allocator) ![]u8 {
    // Implementation: Count consecutive dead/alive cells
    // Format: "40b$5bo$3bo$4b2o$..." (standard RLE format)
}

fn decompressGrid(compressed: []const u8, grid: []u8, rows: usize, cols: usize) !void {
    // Implementation: Parse RLE and populate grid
}
```

### 4. CLI Interface Extensions

#### New Command Line Options
```bash
# Save current state
cgol --save checkpoint.cgol --generations 1000 --delay 100

# Load saved state
cgol --load checkpoint.cgol

# Save with metadata
cgol --save "glider_gen_50.cgol" --description "Glider pattern at generation 50"

# Auto-save every N generations
cgol --auto-save-every 100 --save-prefix "backup_"

# List available save files
cgol --list-saves
```

#### Extended CliArgs Structure
```zig
pub const CliArgs = struct {
    // Existing fields...
    force_prompt: bool = false,
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
    pattern_file: ?[]const u8 = null,
    show_help: bool = false,
    
    // New save/load fields
    save_file: ?[]const u8 = null,
    load_file: ?[]const u8 = null,
    save_description: ?[]const u8 = null,
    auto_save_every: ?u64 = null,
    save_prefix: ?[]const u8 = null,
    list_saves: bool = false,
};
```

## Implementation Plan

### Phase 1: Core Save/Load Infrastructure ✅ COMPLETED
**Estimated time**: 2-3 hours

#### 1.1 Create saveload.zig Module ✅ COMPLETED
- [x] Define data structures (`SavedGameState`, error types)
- [x] Implement grid compression/decompression functions
- [x] Create TOML serialization/deserialization functions
- [x] Add file I/O functions with error handling

#### 1.2 Extend CLI Parser ✅ COMPLETED
- [x] Add new save/load command line options
- [x] Update help text with new options
- [x] Add validation for save/load file paths
- [x] Handle conflicting options (save + load together)

#### 1.3 Core Functions Implementation ✅ COMPLETED
```zig
// Primary interface functions
pub fn saveGameState(
    filepath: []const u8,
    grid: []const u8,
    rows: usize,
    cols: usize,
    generation: u64,
    config: GameConfig,
    description: ?[]const u8,
    allocator: std.mem.Allocator
) SaveLoadError!void

pub fn loadGameState(
    filepath: []const u8,
    allocator: std.mem.Allocator
) SaveLoadError!SavedGameState

pub fn listSaveFiles(
    directory: []const u8,
    allocator: std.mem.Allocator
) ![][]const u8
```

### Phase 2: Main Loop Integration
**Estimated time**: 1-2 hours

#### 2.1 Modify Main Function
- [ ] Check for `--load` flag and load state before simulation
- [ ] Handle grid allocation based on loaded dimensions
- [ ] Initialize generation counter from loaded state
- [ ] Restore configuration from saved state

#### 2.2 Save Trigger Points
- [ ] Save on explicit `--save` flag
- [ ] Auto-save functionality during main loop
- [ ] Save on graceful exit (SIGINT handling)
- [ ] Save before pattern loading (backup current state)

#### 2.3 Error Handling Integration
- [ ] Graceful handling of corrupted save files
- [ ] Fallback to default initialization on load failure
- [ ] User-friendly error messages for save/load issues

### Phase 3: Advanced Features
**Estimated time**: 2-3 hours

#### 3.1 Interactive Save/Load
- [ ] Keyboard shortcuts during simulation:
  - 's': Quick save with timestamp
  - 'l': List and load from available saves
  - 'S': Save with custom name prompt
- [ ] Integration with existing input handling

#### 3.2 Auto-Save System
- [ ] Configurable auto-save intervals
- [ ] Rotating backup system (keep last N saves)
- [ ] Background save to avoid simulation interruption
- [ ] Progress indication for large grid saves

#### 3.3 Metadata Enhancement
- [ ] Pattern detection and classification
- [ ] Statistical summaries (population, stability)
- [ ] Save preview/thumbnail generation
- [ ] File validation and repair utilities

### Phase 4: Testing and Documentation
**Estimated time**: 1-2 hours

#### 4.1 Unit Tests
```zig
test "save and load grid state" {
    // Test basic save/load functionality
}

test "grid compression and decompression" {
    // Test RLE compression preserves data
}

test "handle corrupted save files" {
    // Test error handling for malformed files
}

test "auto-save functionality" {
    // Test periodic saving during simulation
}
```

#### 4.2 Integration Tests
- [ ] Test full CLI workflow with save/load
- [ ] Test large grid performance
- [ ] Test edge cases (empty grids, single cells)
- [ ] Test file permissions and disk space handling

#### 4.3 Documentation Updates
- [ ] Update CLAUDE.md with new commands
- [ ] Add save/load examples to README
- [ ] Document file format specification
- [ ] Create troubleshooting guide

## File Organization

### New Files
```
src/
├── saveload.zig          # New: Save/load functionality
└── ...existing files...

saves/                    # New: Default save directory
├── .gitkeep
└── README.md            # Instructions for save files

tests/
├── saveload_test.zig    # New: Save/load tests
└── ...existing tests...
```

### Constants Additions
```zig
// In constants.zig
pub const SAVE_FILE_EXTENSION = ".cgol";
pub const SAVE_FILE_VERSION = "1.0";
pub const SAVE_DIR_DEFAULT = "saves";
pub const AUTO_SAVE_PREFIX = "auto_";
pub const MAX_SAVE_DESCRIPTION_LEN = 256;
pub const MAX_SAVES_TO_LIST = 50;
```

## Error Handling Strategy

### Validation Levels
1. **CLI Level**: Validate file paths and permissions
2. **File Level**: Check file format and version compatibility  
3. **Data Level**: Validate grid dimensions and generation numbers
4. **Memory Level**: Handle allocation failures gracefully

### Recovery Mechanisms
- **Corrupted files**: Attempt partial recovery, fallback to defaults
- **Version mismatches**: Provide migration utilities
- **Disk space**: Warn before saving, cleanup old auto-saves
- **Permissions**: Suggest alternative save locations

## Performance Considerations

### Optimization Strategies
- **Lazy loading**: Only decompress grid when needed
- **Streaming**: Process large grids in chunks
- **Compression**: Use efficient RLE for sparse grids
- **Caching**: Keep recently loaded states in memory

### Memory Management
- **Arena allocator**: For temporary save/load operations
- **Careful cleanup**: Ensure no memory leaks in error paths
- **Grid reuse**: Avoid unnecessary allocations during load

## Security Considerations

### File Safety
- **Path validation**: Prevent directory traversal attacks
- **Size limits**: Prevent excessive memory consumption
- **Format validation**: Strict parsing to prevent crashes
- **Sandboxing**: Restrict save/load to designated directories

## Success Criteria

### Functional Requirements
- [ ] Save current game state to file with metadata
- [ ] Load saved game state and resume simulation
- [ ] Handle grid compression for efficient storage
- [ ] Support auto-save functionality
- [ ] Provide CLI interface for all operations

### Quality Requirements
- [ ] Robust error handling for all failure modes
- [ ] Performance suitable for grids up to 1000x1000
- [ ] Memory efficient (no unnecessary copies)
- [ ] Human-readable TOML save format for debugging
- [ ] Comprehensive test coverage (>90%)

### User Experience Requirements
- [ ] Intuitive command line interface
- [ ] Helpful error messages and suggestions
- [ ] Fast save/load operations (<1 second for typical grids)
- [ ] Seamless integration with existing workflow
- [ ] Clear documentation and examples

## Timeline Estimate

**Total Estimated Time: 6-10 hours**

- **Phase 1** (Core Infrastructure): 2-3 hours
- **Phase 2** (Main Loop Integration): 1-2 hours  
- **Phase 3** (Advanced Features): 2-3 hours
- **Phase 4** (Testing & Documentation): 1-2 hours

## Risk Assessment

### Technical Risks
- **Memory usage**: Large grids may consume significant memory
- **File I/O performance**: Slow on some filesystems
- **Compression efficiency**: RLE may not be optimal for all patterns

### Mitigation Strategies
- **Progressive loading**: Load grids in chunks if needed
- **Format options**: Support both TOML and binary formats
- **Compression alternatives**: Consider other algorithms if RLE insufficient

## Next Steps

1. **Create saveload.zig module** with basic data structures
2. **Implement TOML serialization** for SavedGameState
3. **Add CLI parsing** for save/load options
4. **Integrate with main loop** for basic save/load functionality
5. **Add comprehensive testing** and error handling
6. **Document the new features** and update examples

This implementation plan provides a solid foundation for adding robust save/load functionality to the Conway's Game of Life simulator while maintaining the existing code quality and architectural principles.