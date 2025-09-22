const std = @import("std");
const constants = @import("constants.zig");

pub const ConfigPartial = struct {
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
};

/// Parse a single configuration line
fn parseConfigLine(line: []const u8, result: *ConfigPartial) void {
    const trimmed_line = std.mem.trim(u8, line, constants.TRIM_CHARS);

    // Skip empty lines and comments
    if (trimmed_line.len == 0 or trimmed_line[0] == constants.COMMENT_CHAR) {
        return;
    }

    // Find the equals sign
    const eq_idx_opt = std.mem.indexOfScalar(u8, trimmed_line, constants.EQUALS_CHAR);
    if (eq_idx_opt == null) return;

    const eq_idx = eq_idx_opt.?;
    const key = std.mem.trim(u8, trimmed_line[0..eq_idx], constants.TRIM_CHARS);
    const val_str = std.mem.trim(u8, trimmed_line[eq_idx + 1 ..], constants.TRIM_CHARS);

    if (val_str.len == 0) return;

    // Parse the value based on the key
    if (std.mem.eql(u8, key, constants.CONFIG_KEY_ROWS)) {
        result.rows = std.fmt.parseUnsigned(usize, val_str, constants.DECIMAL_BASE) catch null;
    } else if (std.mem.eql(u8, key, constants.CONFIG_KEY_COLS)) {
        result.cols = std.fmt.parseUnsigned(usize, val_str, constants.DECIMAL_BASE) catch null;
    } else if (std.mem.eql(u8, key, constants.CONFIG_KEY_GENERATIONS)) {
        result.generations = std.fmt.parseUnsigned(u64, val_str, constants.DECIMAL_BASE) catch null;
    } else if (std.mem.eql(u8, key, constants.CONFIG_KEY_DELAY_MS)) {
        result.delay_ms = std.fmt.parseUnsigned(u64, val_str, constants.DECIMAL_BASE) catch null;
    }
}

/// Read configuration file content
fn readConfigFile(alloc: std.mem.Allocator) ?[]u8 {
    const cwd = std.fs.cwd();
    const file = cwd.openFile(constants.CONFIG_FILENAME, .{}) catch return null;
    defer file.close();

    return file.readToEndAlloc(alloc, constants.CONFIG_FILE_MAX_SIZE) catch null;
}

/// Load configuration from cgol.toml file
pub fn loadConfig(alloc: std.mem.Allocator) ConfigPartial {
    var result: ConfigPartial = .{};

    const buf = readConfigFile(alloc) orelse return result;
    defer alloc.free(buf);

    var line_iterator = std.mem.splitScalar(u8, buf, constants.NEWLINE_CHAR);
    while (line_iterator.next()) |line| {
        parseConfigLine(line, &result);
    }

    return result;
}

/// Write configuration to cgol.toml file
pub fn writeConfig(rows: usize, cols: usize, generations: u64, delay_ms: u64) !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile(constants.CONFIG_FILENAME, .{ .truncate = true });
    defer file.close();
    var buf: [constants.CONFIG_WRITE_BUFFER_SIZE]u8 = undefined;
    const out = try std.fmt.bufPrint(
        &buf,
        constants.CONFIG_COMMENT ++ "\n" ++ constants.CONFIG_KEY_ROWS ++ " = {d}\n" ++ constants.CONFIG_KEY_COLS ++ " = {d}\n" ++ constants.CONFIG_KEY_GENERATIONS ++ " = {d}\n" ++ constants.CONFIG_KEY_DELAY_MS ++ " = {d}\n",
        .{ rows, cols, generations, delay_ms },
    );
    try file.writeAll(out);
}
