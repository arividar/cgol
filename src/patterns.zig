const std = @import("std");
const constants = @import("constants.zig");
const game = @import("game.zig");

/// Supported pattern file formats
pub const PatternFormat = enum {
    rle, // Run Length Encoded
    plaintext, // Plaintext format
    life106, // Life 1.06 format

    /// Detect format from file extension
    pub fn fromExtension(filename: []const u8) ?PatternFormat {
        if (std.mem.endsWith(u8, filename, ".rle")) return .rle;
        if (std.mem.endsWith(u8, filename, ".cells")) return .plaintext;
        if (std.mem.endsWith(u8, filename, ".life")) return .life106;
        if (std.mem.endsWith(u8, filename, ".lif")) return .life106;
        return null;
    }
};

/// Pattern metadata
pub const PatternInfo = struct {
    name: []const u8,
    author: ?[]const u8 = null,
    description: ?[]const u8 = null,
    width: usize,
    height: usize,
    rule: []const u8 = "B3/S23", // Conway's standard rule
    allocator: std.mem.Allocator,

    pub fn deinit(self: *PatternInfo) void {
        self.allocator.free(self.name);
        if (self.author) |author| {
            self.allocator.free(author);
        }
        if (self.description) |description| {
            self.allocator.free(description);
        }
        if (!std.mem.eql(u8, self.rule, "B3/S23")) {
            self.allocator.free(self.rule);
        }
    }
};

/// Loaded pattern data
pub const Pattern = struct {
    info: PatternInfo,
    cells: []const Coord,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Pattern) void {
        self.allocator.free(self.cells);
        self.info.deinit();
    }
};

/// Coordinate for pattern cells
pub const Coord = struct {
    x: i32,
    y: i32,
};

/// Pattern loading errors
pub const PatternError = error{
    UnsupportedFormat,
    InvalidFormat,
    FileNotFound,
    ParseError,
    OutOfMemory,
};

/// Load pattern from file
pub fn loadPattern(allocator: std.mem.Allocator, filename: []const u8) PatternError!Pattern {
    const format = PatternFormat.fromExtension(filename) orelse return PatternError.UnsupportedFormat;

    const file = std.fs.cwd().openFile(filename, .{}) catch return PatternError.FileNotFound;
    defer file.close();

    const content = file.readToEndAlloc(allocator, constants.MAX_PATTERN_FILE_SIZE) catch return PatternError.OutOfMemory;
    defer allocator.free(content);

    return switch (format) {
        .rle => parseRLE(allocator, content),
        .plaintext => parsePlaintext(allocator, content),
        .life106 => parseLife106(allocator, content),
    };
}

/// Parse RLE (Run Length Encoded) format
fn parseRLE(allocator: std.mem.Allocator, content: []const u8) PatternError!Pattern {
    var lines = std.mem.splitSequence(u8, content, "\n");
    var info = PatternInfo{
        .name = try allocator.dupe(u8, "Unknown"),
        .width = 0,
        .height = 0,
        .allocator = allocator,
    };

    // Use a temporary buffer for cells
    var temp_cells: [1000]Coord = undefined;
    var cell_count: usize = 0;

    var parsing_header = true;
    var current_y: i32 = 0;

    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;

        // Comments and metadata
        if (line[0] == '#') {
            if (std.mem.startsWith(u8, line, "#N ")) {
                allocator.free(info.name);
                info.name = try allocator.dupe(u8, line[3..]);
            } else if (std.mem.startsWith(u8, line, "#O ")) {
                info.author = try allocator.dupe(u8, line[3..]);
            } else if (std.mem.startsWith(u8, line, "#C ")) {
                info.description = try allocator.dupe(u8, line[3..]);
            }
            continue;
        }

        // Header line: x = width, y = height, rule = B3/S23
        if (parsing_header and line[0] == 'x') {
            parsing_header = false;
            var parts = std.mem.tokenizeAny(u8, line, " =,");
            while (parts.next()) |part| {
                if (std.mem.eql(u8, part, "x")) {
                    if (parts.next()) |width_str| {
                        info.width = std.fmt.parseUnsigned(usize, width_str, 10) catch return PatternError.ParseError;
                    }
                } else if (std.mem.eql(u8, part, "y")) {
                    if (parts.next()) |height_str| {
                        info.height = std.fmt.parseUnsigned(usize, height_str, 10) catch return PatternError.ParseError;
                    }
                } else if (std.mem.eql(u8, part, "rule")) {
                    if (parts.next()) |rule_str| {
                        info.rule = try allocator.dupe(u8, rule_str);
                    }
                }
            }
            continue;
        }

        // Pattern data
        if (!parsing_header) {
            parseRLELine(line, temp_cells[0..], &cell_count, &current_y);
        }
    }

    // Allocate final array
    const cells = try allocator.alloc(Coord, cell_count);
    @memcpy(cells, temp_cells[0..cell_count]);

    return Pattern{
        .info = info,
        .cells = cells,
        .allocator = allocator,
    };
}

/// Parse a single RLE data line
fn parseRLELine(line: []const u8, cells: []Coord, cell_count: *usize, current_y: *i32) void {
    var x: i32 = 0;
    var count: u32 = 1;
    var i: usize = 0;

    while (i < line.len) {
        const char = line[i];

        if (std.ascii.isDigit(char)) {
            // Parse run count
            const num_start = i;
            while (i < line.len and std.ascii.isDigit(line[i])) i += 1;
            count = std.fmt.parseUnsigned(u32, line[num_start..i], 10) catch 1;
            continue;
        }

        switch (char) {
            'b' => {
                // Dead cells - just advance x
                x += @as(i32, @intCast(count));
            },
            'o' => {
                // Live cells
                var j: u32 = 0;
                while (j < count and cell_count.* < cells.len) : (j += 1) {
                    cells[cell_count.*] = Coord{ .x = x, .y = current_y.* };
                    cell_count.* += 1;
                    x += 1;
                }
            },
            '$' => {
                // End of line
                var j: u32 = 0;
                while (j < count) : (j += 1) {
                    current_y.* += 1;
                    x = 0;
                }
            },
            '!' => {
                // End of pattern
                return;
            },
            else => {
                // Ignore other characters
            },
        }

        count = 1;
        i += 1;
    }
}

/// Parse Plaintext format (.cells)
fn parsePlaintext(allocator: std.mem.Allocator, content: []const u8) PatternError!Pattern {
    var lines = std.mem.splitSequence(u8, content, "\n");
    var info = PatternInfo{
        .name = try allocator.dupe(u8, "Unknown"),
        .width = 0,
        .height = 0,
        .allocator = allocator,
    };

    var temp_cells: [1000]Coord = undefined;
    var cell_count: usize = 0;

    var y: i32 = 0;
    var max_width: usize = 0;

    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;

        // Comments
        if (line[0] == '!') {
            if (std.mem.startsWith(u8, line, "!Name: ")) {
                allocator.free(info.name);
                info.name = try allocator.dupe(u8, line[7..]);
            } else if (std.mem.startsWith(u8, line, "!Author: ")) {
                info.author = try allocator.dupe(u8, line[9..]);
            }
            continue;
        }

        // Pattern data
        for (line, 0..) |char, x| {
            if ((char == 'O' or char == '*') and cell_count < temp_cells.len) {
                temp_cells[cell_count] = Coord{ .x = @as(i32, @intCast(x)), .y = y };
                cell_count += 1;
            }
        }

        max_width = @max(max_width, line.len);
        y += 1;
    }

    info.width = max_width;
    info.height = @as(usize, @intCast(y));

    // Allocate final array
    const cells = try allocator.alloc(Coord, cell_count);
    @memcpy(cells, temp_cells[0..cell_count]);

    return Pattern{
        .info = info,
        .cells = cells,
        .allocator = allocator,
    };
}

/// Parse Life 1.06 format
fn parseLife106(allocator: std.mem.Allocator, content: []const u8) PatternError!Pattern {
    var lines = std.mem.splitSequence(u8, content, "\n");
    var info = PatternInfo{
        .name = try allocator.dupe(u8, "Unknown"),
        .width = 0,
        .height = 0,
        .allocator = allocator,
    };

    var temp_cells: [1000]Coord = undefined;
    var cell_count: usize = 0;

    var min_x: i32 = std.math.maxInt(i32);
    var max_x: i32 = std.math.minInt(i32);
    var min_y: i32 = std.math.maxInt(i32);
    var max_y: i32 = std.math.minInt(i32);

    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;

        // Comments
        if (line[0] == '#') {
            if (std.mem.startsWith(u8, line, "#D ")) {
                info.description = try allocator.dupe(u8, line[3..]);
            } else if (std.mem.startsWith(u8, line, "#N ")) {
                allocator.free(info.name);
                info.name = try allocator.dupe(u8, line[3..]);
            }
            continue;
        }

        // Life 1.06 header
        if (std.mem.startsWith(u8, line, "#Life 1.06")) {
            continue;
        }

        // Coordinate pairs
        var parts = std.mem.tokenizeAny(u8, line, " \t");
        if (parts.next()) |x_str| {
            if (parts.next()) |y_str| {
                const x = std.fmt.parseInt(i32, x_str, 10) catch continue;
                const y = std.fmt.parseInt(i32, y_str, 10) catch continue;

                if (cell_count < temp_cells.len) {
                    temp_cells[cell_count] = Coord{ .x = x, .y = y };
                    cell_count += 1;

                    min_x = @min(min_x, x);
                    max_x = @max(max_x, x);
                    min_y = @min(min_y, y);
                    max_y = @max(max_y, y);
                }
            }
        }
    }

    info.width = if (max_x >= min_x) @as(usize, @intCast(max_x - min_x + 1)) else 0;
    info.height = if (max_y >= min_y) @as(usize, @intCast(max_y - min_y + 1)) else 0;

    // Allocate final array
    const cells = try allocator.alloc(Coord, cell_count);
    @memcpy(cells, temp_cells[0..cell_count]);

    return Pattern{
        .info = info,
        .cells = cells,
        .allocator = allocator,
    };
}

/// Apply pattern to grid at specified position
pub fn applyPattern(pattern: *const Pattern, grid: []u8, grid_rows: usize, grid_cols: usize, offset_x: i32, offset_y: i32) void {
    for (pattern.cells) |coord| {
        const x = coord.x + offset_x;
        const y = coord.y + offset_y;

        if (x >= 0 and y >= 0 and x < grid_cols and y < grid_rows) {
            const idx = game.idx(@as(usize, @intCast(y)), @as(usize, @intCast(x)), grid_cols);
            grid[idx] = constants.CELL_ALIVE;
        }
    }
}
