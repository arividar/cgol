const std = @import("std");
const constants = @import("constants.zig");

/// Error types for save/load operations
pub const SaveLoadError = error{
    InvalidFileFormat,
    UnsupportedVersion,
    CorruptedData,
    IncompatibleGridSize,
    FileNotFound,
    PermissionDenied,
    CompressionFailed,
    DecompressionFailed,
    SerializationFailed,
    DeserializationFailed,
    OutOfMemory,
};

/// Saved game state containing all necessary data to restore a simulation
pub const SavedGameState = struct {
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
    
    /// Clean up allocated strings
    pub fn deinit(self: *SavedGameState, allocator: std.mem.Allocator) void {
        allocator.free(self.version);
        allocator.free(self.saved_at);
        if (self.description) |desc| {
            allocator.free(desc);
        }
        if (self.original_pattern) |pattern| {
            allocator.free(pattern);
        }
        allocator.free(self.grid_data);
    }
};

/// Configuration for save operations
pub const SaveConfig = struct {
    description: ?[]const u8 = null,
    original_pattern: ?[]const u8 = null,
    compression_enabled: bool = true,
};

/// Configuration for load operations
pub const LoadConfig = struct {
    validate_dimensions: bool = true,
    allow_version_mismatch: bool = false,
};

/// Compress grid data using Run-Length Encoding (RLE)
/// Returns compressed data in standard RLE format
pub fn compressGrid(grid: []const u8, rows: usize, cols: usize, allocator: std.mem.Allocator) SaveLoadError![]u8 {
    if (grid.len != rows * cols) {
        return SaveLoadError.IncompatibleGridSize;
    }
    
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) {
            const idx = row * cols + col;
            const cell = grid[idx];
            var count: u32 = 1;
            
            // Count consecutive identical cells in this row
            while (col + count < cols and grid[idx + count] == cell) {
                count += 1;
            }
            
            // Write count and cell type
            if (count > 1) {
                try std.fmt.format(result.writer(), "{d}", .{count});
            }
            
            try result.append(if (cell == constants.CELL_ALIVE) 'o' else 'b');
            
            col += count;
        }
        
        // Add row separator
        try result.append('$');
    }
    
    return result.toOwnedSlice();
}

/// Decompress RLE data back into grid format
pub fn decompressGrid(compressed: []const u8, grid: []u8, rows: usize, cols: usize) SaveLoadError!void {
    if (grid.len != rows * cols) {
        return SaveLoadError.IncompatibleGridSize;
    }
    
    // Clear the grid first
    @memset(grid, constants.CELL_DEAD);
    
    var i: usize = 0;
    var current_row: usize = 0;
    var current_col: usize = 0;
    
    while (i < compressed.len and current_row < rows) {
        const c = compressed[i];
        
        if (c == '$') {
            // Row separator - move to next row
            current_row += 1;
            current_col = 0;
            i += 1;
            continue;
        }
        
        if (c == 'o' or c == 'b') {
            // Single cell
            const idx = current_row * cols + current_col;
            if (idx < grid.len) {
                grid[idx] = if (c == 'o') constants.CELL_ALIVE else constants.CELL_DEAD;
            }
            current_col += 1;
            i += 1;
            continue;
        }
        
        // Parse count (multi-digit number)
        var count: u32 = 0;
        var j = i;
        while (j < compressed.len and compressed[j] >= '0' and compressed[j] <= '9') {
            count = count * 10 + (compressed[j] - '0');
            j += 1;
        }
        
        if (count == 0) count = 1;
        
        // Get the cell type
        if (j >= compressed.len) {
            return SaveLoadError.CorruptedData;
        }
        
        const cell_type = compressed[j];
        if (cell_type != 'o' and cell_type != 'b') {
            return SaveLoadError.CorruptedData;
        }
        
        const cell_value = if (cell_type == 'o') constants.CELL_ALIVE else constants.CELL_DEAD;
        
        // Fill the grid with the repeated cell
        var k: u32 = 0;
        while (k < count and current_col < cols) : (k += 1) {
            const idx = current_row * cols + current_col;
            if (idx < grid.len) {
                grid[idx] = cell_value;
            }
            current_col += 1;
        }
        
        i = j + 1; // Skip the processed characters
    }
}

/// Generate current timestamp as ISO 8601 string
fn getCurrentTimestamp(allocator: std.mem.Allocator) ![]u8 {
    const timestamp = std.time.timestamp();
    // Convert to a more readable ISO-like format
    return std.fmt.allocPrint(allocator, "{d}", .{timestamp});
}

/// Create saves directory if it doesn't exist
pub fn ensureSaveDirectory(directory: []const u8) SaveLoadError!void {
    std.fs.cwd().makeDir(directory) catch |err| {
        return switch (err) {
            error.PathAlreadyExists => {}, // Directory already exists, this is fine
            error.AccessDenied => SaveLoadError.PermissionDenied,
            else => SaveLoadError.SerializationFailed,
        };
    };
}

/// Get full path for a save file in the default saves directory
pub fn getSaveFilePath(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Ensure the filename has the correct extension
    const name_with_ext = if (std.mem.endsWith(u8, filename, constants.SAVE_FILE_EXTENSION))
        filename
    else
        try std.fmt.allocPrint(allocator, "{s}{s}", .{ filename, constants.SAVE_FILE_EXTENSION });
    
    if (name_with_ext.ptr != filename.ptr) {
        defer allocator.free(name_with_ext);
    }
    
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ constants.SAVE_DIR_DEFAULT, name_with_ext });
}

/// Save game state to TOML file
pub fn saveGameState(
    filepath: []const u8,
    grid: []const u8,
    rows: usize,
    cols: usize,
    generation: u64,
    generations: u64,
    delay_ms: u64,
    save_config: SaveConfig,
    allocator: std.mem.Allocator,
) SaveLoadError!void {
    // Compress grid data
    const compressed_data = compressGrid(grid, rows, cols, allocator) catch |err| {
        return switch (err) {
            SaveLoadError.IncompatibleGridSize => SaveLoadError.IncompatibleGridSize,
            else => SaveLoadError.CompressionFailed,
        };
    };
    defer allocator.free(compressed_data);
    
    // Generate timestamp
    const timestamp = getCurrentTimestamp(allocator) catch return SaveLoadError.SerializationFailed;
    defer allocator.free(timestamp);
    
    // Create TOML content
    var toml_content = std.ArrayList(u8).init(allocator);
    defer toml_content.deinit();
    
    const writer = toml_content.writer();
    
    // Write TOML header
    try writer.print("# Conway's Game of Life Save File\n", .{});
    try writer.print("version = \"{s}\"\n\n", .{constants.SAVE_FILE_VERSION});
    
    // Write metadata section
    try writer.print("[metadata]\n", .{});
    try writer.print("saved_at = \"{s}\"\n", .{timestamp});
    if (save_config.description) |desc| {
        try writer.print("description = \"{s}\"\n", .{desc});
    }
    if (save_config.original_pattern) |pattern| {
        try writer.print("original_pattern = \"{s}\"\n", .{pattern});
    }
    try writer.print("\n", .{});
    
    // Write game state section
    try writer.print("[game_state]\n", .{});
    try writer.print("current_generation = {d}\n", .{generation});
    try writer.print("rows = {d}\n", .{rows});
    try writer.print("cols = {d}\n", .{cols});
    try writer.print("generations = {d}\n", .{generations});
    try writer.print("delay_ms = {d}\n\n", .{delay_ms});
    
    // Write grid data section
    try writer.print("[grid_data]\n", .{});
    try writer.print("encoding = \"rle_compressed\"\n", .{});
    try writer.print("data = \"{s}\"\n", .{compressed_data});
    
    // Write to file
    const file = std.fs.cwd().createFile(filepath, .{}) catch |err| {
        return switch (err) {
            error.AccessDenied => SaveLoadError.PermissionDenied,
            else => SaveLoadError.SerializationFailed,
        };
    };
    defer file.close();
    
    file.writeAll(toml_content.items) catch |err| {
        return switch (err) {
            error.AccessDenied => SaveLoadError.PermissionDenied,
            else => SaveLoadError.SerializationFailed,
        };
    };
}

/// Load game state from TOML file
pub fn loadGameState(
    filepath: []const u8,
    load_config: LoadConfig,
    allocator: std.mem.Allocator,
) SaveLoadError!SavedGameState {
    _ = load_config; // TODO: Implement validation based on load_config
    // Read file
    const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => SaveLoadError.FileNotFound,
            error.AccessDenied => SaveLoadError.PermissionDenied,
            else => SaveLoadError.FileNotFound,
        };
    };
    defer file.close();
    
    const file_size = file.getEndPos() catch return SaveLoadError.CorruptedData;
    if (file_size > constants.MAX_SAVE_FILE_SIZE) {
        return SaveLoadError.CorruptedData;
    }
    
    const file_content = file.readToEndAlloc(allocator, file_size) catch return SaveLoadError.OutOfMemory;
    defer allocator.free(file_content);
    
    // Parse TOML content (simplified parser for our specific format)
    var result = SavedGameState{
        .version = try allocator.dupe(u8, ""),
        .saved_at = try allocator.dupe(u8, ""),
        .description = null,
        .original_pattern = null,
        .current_generation = 0,
        .rows = 0,
        .cols = 0,
        .generations = 0,
        .delay_ms = 0,
        .grid_data = try allocator.dupe(u8, ""),
    };
    
    // Simple TOML parsing (we'll improve this later)
    var lines = std.mem.tokenizeAny(u8, file_content, "\n");
    var current_section: []const u8 = "";
    
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        
        // Skip comments and empty lines
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        
        // Check for section headers
        if (trimmed.len > 2 and trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
            current_section = trimmed[1..trimmed.len-1];
            continue;
        }
        
        // Parse key-value pairs
        if (std.mem.indexOf(u8, trimmed, " = ")) |eq_pos| {
            const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
            const value = std.mem.trim(u8, trimmed[eq_pos + 3..], " \t");
            
            // Remove quotes from string values
            const unquoted_value = if (value.len >= 2 and value[0] == '"' and value[value.len-1] == '"') 
                value[1..value.len-1] else value;
            
            if (std.mem.eql(u8, current_section, "metadata")) {
                if (std.mem.eql(u8, key, "saved_at")) {
                    allocator.free(result.saved_at);
                    result.saved_at = try allocator.dupe(u8, unquoted_value);
                } else if (std.mem.eql(u8, key, "description")) {
                    result.description = try allocator.dupe(u8, unquoted_value);
                } else if (std.mem.eql(u8, key, "original_pattern")) {
                    result.original_pattern = try allocator.dupe(u8, unquoted_value);
                }
            } else if (std.mem.eql(u8, current_section, "game_state")) {
                if (std.mem.eql(u8, key, "current_generation")) {
                    result.current_generation = std.fmt.parseUnsigned(u64, unquoted_value, 10) catch return SaveLoadError.CorruptedData;
                } else if (std.mem.eql(u8, key, "rows")) {
                    result.rows = std.fmt.parseUnsigned(usize, unquoted_value, 10) catch return SaveLoadError.CorruptedData;
                } else if (std.mem.eql(u8, key, "cols")) {
                    result.cols = std.fmt.parseUnsigned(usize, unquoted_value, 10) catch return SaveLoadError.CorruptedData;
                } else if (std.mem.eql(u8, key, "generations")) {
                    result.generations = std.fmt.parseUnsigned(u64, unquoted_value, 10) catch return SaveLoadError.CorruptedData;
                } else if (std.mem.eql(u8, key, "delay_ms")) {
                    result.delay_ms = std.fmt.parseUnsigned(u64, unquoted_value, 10) catch return SaveLoadError.CorruptedData;
                }
            } else if (std.mem.eql(u8, current_section, "grid_data")) {
                if (std.mem.eql(u8, key, "data")) {
                    allocator.free(result.grid_data);
                    result.grid_data = try allocator.dupe(u8, unquoted_value);
                }
            }
        }
    }
    
    // Validate required fields
    if (result.rows == 0 or result.cols == 0) {
        return SaveLoadError.CorruptedData;
    }
    
    return result;
}

/// Convenience wrapper matching the implementation plan signature
pub fn saveGameStateSimple(
    filepath: []const u8,
    grid: []const u8,
    rows: usize,
    cols: usize,
    generation: u64,
    config: GameConfig,
    description: ?[]const u8,
    allocator: std.mem.Allocator,
) SaveLoadError!void {
    const save_config = SaveConfig{
        .description = description,
        .original_pattern = null,
        .compression_enabled = true,
    };
    
    return saveGameState(
        filepath,
        grid,
        rows,
        cols,
        generation,
        config.generations,
        config.delay_ms,
        save_config,
        allocator,
    );
}

/// Convenience wrapper for loading with minimal config
pub fn loadGameStateSimple(
    filepath: []const u8,
    allocator: std.mem.Allocator,
) SaveLoadError!SavedGameState {
    const load_config = LoadConfig{
        .validate_dimensions = true,
        .allow_version_mismatch = false,
    };
    
    return loadGameState(filepath, load_config, allocator);
}

/// Game configuration struct for compatibility with the implementation plan
pub const GameConfig = struct {
    rows: usize,
    cols: usize,
    generations: u64,
    delay_ms: u64,
};

/// List available save files in a directory
pub fn listSaveFiles(directory: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var dir = std.fs.cwd().openDir(directory, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => return &[_][]const u8{},
            else => return err,
        };
    };
    defer dir.close();
    
    var save_files = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (save_files.items) |file| {
            allocator.free(file);
        }
        save_files.deinit();
    }
    
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, constants.SAVE_FILE_EXTENSION)) {
            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{directory, entry.name});
            try save_files.append(full_path);
        }
    }
    
    return save_files.toOwnedSlice();
}

test "save and load game state integration" {
    const allocator = std.testing.allocator;
    const test_filename = "test_save.cgol";
    
    // Clean up any existing test file
    std.fs.cwd().deleteFile(test_filename) catch {};
    defer std.fs.cwd().deleteFile(test_filename) catch {};
    
    // Create test grid
    const rows: usize = 3;
    const cols: usize = 3; 
    const grid = [_]u8{
        constants.CELL_ALIVE, constants.CELL_DEAD, constants.CELL_ALIVE,
        constants.CELL_DEAD, constants.CELL_ALIVE, constants.CELL_DEAD,
        constants.CELL_DEAD, constants.CELL_DEAD, constants.CELL_ALIVE,
    };
    
    // Save game state
    const save_config = SaveConfig{
        .description = "Test save",
        .original_pattern = "test_pattern.rle",
    };
    
    try saveGameState(
        test_filename,
        &grid,
        rows,
        cols,
        42, // generation
        100, // generations
        150, // delay_ms
        save_config,
        allocator,
    );
    
    // Load game state
    const load_config = LoadConfig{};
    var loaded_state = try loadGameState(test_filename, load_config, allocator);
    defer loaded_state.deinit(allocator);
    
    // Verify metadata
    try std.testing.expect(loaded_state.current_generation == 42);
    try std.testing.expect(loaded_state.rows == rows);
    try std.testing.expect(loaded_state.cols == cols);
    try std.testing.expect(loaded_state.generations == 100);
    try std.testing.expect(loaded_state.delay_ms == 150);
    try std.testing.expectEqualStrings("Test save", loaded_state.description.?);
    try std.testing.expectEqualStrings("test_pattern.rle", loaded_state.original_pattern.?);
    
    // Decompress and verify grid data
    const decompressed_grid = try allocator.alloc(u8, rows * cols);
    defer allocator.free(decompressed_grid);
    
    try decompressGrid(loaded_state.grid_data, decompressed_grid, rows, cols);
    try std.testing.expectEqualSlices(u8, &grid, decompressed_grid);
}

test "listSaveFiles functionality" {
    const allocator = std.testing.allocator;
    
    // Test listing files in a directory that may not exist
    const save_files = listSaveFiles("nonexistent_directory", allocator) catch &[_][]const u8{};
    defer {
        for (save_files) |file| {
            allocator.free(file);
        }
        allocator.free(save_files);
    }
    
    // Should return empty list for non-existent directory
    try std.testing.expect(save_files.len == 0);
}

test "error handling for corrupted data" {
    const allocator = std.testing.allocator;
    const test_filename = "corrupted_test.cgol";
    
    // Create a corrupted save file
    const corrupted_content = "invalid toml content\n[broken";
    const file = try std.fs.cwd().createFile(test_filename, .{});
    defer file.close();
    defer std.fs.cwd().deleteFile(test_filename) catch {};
    
    try file.writeAll(corrupted_content);
    
    const load_config = LoadConfig{};
    const result = loadGameState(test_filename, load_config, allocator);
    try std.testing.expectError(SaveLoadError.CorruptedData, result);
}

test "compress and decompress grid" {
    const allocator = std.testing.allocator;
    
    // Test with a simple 3x3 grid
    const rows: usize = 3;
    const cols: usize = 3;
    const grid = [_]u8{
        constants.CELL_ALIVE, constants.CELL_DEAD, constants.CELL_ALIVE,
        constants.CELL_DEAD, constants.CELL_ALIVE, constants.CELL_DEAD,
        constants.CELL_ALIVE, constants.CELL_ALIVE, constants.CELL_DEAD,
    };
    
    const compressed = try compressGrid(&grid, rows, cols, allocator);
    defer allocator.free(compressed);
    
    var decompressed = [_]u8{constants.CELL_DEAD} ** (rows * cols);
    try decompressGrid(compressed, &decompressed, rows, cols);
    
    try std.testing.expectEqualSlices(u8, &grid, &decompressed);
}

test "compress empty grid" {
    const allocator = std.testing.allocator;
    
    const rows: usize = 2;
    const cols: usize = 2;
    const grid = [_]u8{constants.CELL_DEAD} ** (rows * cols);
    
    const compressed = try compressGrid(&grid, rows, cols, allocator);
    defer allocator.free(compressed);
    
    var decompressed = [_]u8{constants.CELL_ALIVE} ** (rows * cols);
    try decompressGrid(compressed, &decompressed, rows, cols);
    
    try std.testing.expectEqualSlices(u8, &grid, &decompressed);
}

test "compress full grid" {
    const allocator = std.testing.allocator;
    
    const rows: usize = 2;
    const cols: usize = 2;
    const grid = [_]u8{constants.CELL_ALIVE} ** (rows * cols);
    
    const compressed = try compressGrid(&grid, rows, cols, allocator);
    defer allocator.free(compressed);
    
    var decompressed = [_]u8{constants.CELL_DEAD} ** (rows * cols);
    try decompressGrid(compressed, &decompressed, rows, cols);
    
    try std.testing.expectEqualSlices(u8, &grid, &decompressed);
}