const std = @import("std");

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
    const file = cwd.openFile("cgol.toml", .{}) catch return result;
    defer file.close();

    const buf = file.readToEndAlloc(alloc, 64 * 1024) catch return result;
    defer alloc.free(buf);

    var it = std.mem.splitScalar(u8, buf, '\n');
    while (it.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const eq_idx_opt = std.mem.indexOfScalar(u8, line, '=');
        if (eq_idx_opt == null) continue;
        const i = eq_idx_opt.?;
        const key = std.mem.trim(u8, line[0..i], " \t");
        const val_str = std.mem.trim(u8, line[i + 1 ..], " \t");
        if (val_str.len == 0) continue;
        // parse unsigned integer values only
        if (std.mem.eql(u8, key, "rows")) {
            const v = std.fmt.parseUnsigned(usize, val_str, 10) catch continue;
            result.rows = v;
        } else if (std.mem.eql(u8, key, "cols")) {
            const v = std.fmt.parseUnsigned(usize, val_str, 10) catch continue;
            result.cols = v;
        } else if (std.mem.eql(u8, key, "generations")) {
            const v = std.fmt.parseUnsigned(u64, val_str, 10) catch continue;
            result.generations = v;
        } else if (std.mem.eql(u8, key, "delay_ms")) {
            const v = std.fmt.parseUnsigned(u64, val_str, 10) catch continue;
            result.delay_ms = v;
        }
    }
    return result;
}

/// Write configuration to cgol.toml file
pub fn writeConfig(rows: usize, cols: usize, generations: u64, delay_ms: u64) !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile("cgol.toml", .{ .truncate = true });
    defer file.close();
    var buf: [256]u8 = undefined;
    const out = try std.fmt.bufPrint(
        &buf,
        "# Game of Life config\nrows = {d}\ncols = {d}\ngenerations = {d}\ndelay_ms = {d}\n",
        .{ rows, cols, generations, delay_ms },
    );
    try file.writeAll(out);
}
