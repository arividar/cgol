const std = @import("std");
const constants = @import("constants.zig");

pub const ConfigPartial = struct {
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
};

/// Load configuration from cgol.toml file
pub fn loadConfig(alloc: std.mem.Allocator) ConfigPartial {
    var result: ConfigPartial = .{};
    const cwd = std.fs.cwd();
    const file = cwd.openFile(constants.CONFIG_FILENAME, .{}) catch return result;
    defer file.close();

    const buf = file.readToEndAlloc(alloc, constants.CONFIG_FILE_MAX_SIZE) catch return result;
    defer alloc.free(buf);

    var it = std.mem.splitScalar(u8, buf, constants.NEWLINE_CHAR);
    while (it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, constants.TRIM_CHARS);
        if (line.len == 0 or line[0] == constants.COMMENT_CHAR) continue;
        const eq_idx_opt = std.mem.indexOfScalar(u8, line, constants.EQUALS_CHAR);
        if (eq_idx_opt == null) continue;
        const i = eq_idx_opt.?;
        const key = std.mem.trim(u8, line[0..i], constants.TRIM_CHARS);
        const val_str = std.mem.trim(u8, line[i + 1 ..], constants.TRIM_CHARS);
        if (val_str.len == 0) continue;
        // parse unsigned integer values only
        if (std.mem.eql(u8, key, constants.CONFIG_KEY_ROWS)) {
            const v = std.fmt.parseUnsigned(usize, val_str, constants.DECIMAL_BASE) catch continue;
            result.rows = v;
        } else if (std.mem.eql(u8, key, constants.CONFIG_KEY_COLS)) {
            const v = std.fmt.parseUnsigned(usize, val_str, constants.DECIMAL_BASE) catch continue;
            result.cols = v;
        } else if (std.mem.eql(u8, key, constants.CONFIG_KEY_GENERATIONS)) {
            const v = std.fmt.parseUnsigned(u64, val_str, constants.DECIMAL_BASE) catch continue;
            result.generations = v;
        } else if (std.mem.eql(u8, key, constants.CONFIG_KEY_DELAY_MS)) {
            const v = std.fmt.parseUnsigned(u64, val_str, constants.DECIMAL_BASE) catch continue;
            result.delay_ms = v;
        }
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
