const std = @import("std");
const constants = @import("constants.zig");

pub const CliArgs = struct {
    force_prompt: bool = false,
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
    pattern_file: ?[]const u8 = null,
    show_help: bool = false,

    pub fn deinit(self: *CliArgs, allocator: std.mem.Allocator) void {
        if (self.pattern_file) |pattern_file| {
            allocator.free(pattern_file);
        }
    }
};

/// Parse command line arguments
pub fn parseArgs(allocator: std.mem.Allocator) !CliArgs {
    var result = CliArgs{};

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var pos_vals: [constants.CLI_MAX_POSITIONAL_ARGS]u64 = undefined;
    var pos_count: usize = 0;
    var i: usize = 1; // skip program name

    while (i < args.len) : (i += 1) {
        const a = args[i];

        // Help
        if (std.mem.eql(u8, a, "--help") or std.mem.eql(u8, a, "-h")) {
            result.show_help = true;
            return result;
        }

        if (std.mem.eql(u8, a, "--prompt-for-config") or std.mem.eql(u8, a, "-p")) {
            result.force_prompt = true;
            continue;
        }

        if (std.mem.startsWith(u8, a, "--height=")) {
            const vstr = a["--height=".len..];
            result.rows = std.fmt.parseUnsigned(usize, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--height")) {
            if (i + 1 < args.len) {
                result.rows = std.fmt.parseUnsigned(usize, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--width=")) {
            const vstr = a["--width=".len..];
            result.cols = std.fmt.parseUnsigned(usize, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--width")) {
            if (i + 1 < args.len) {
                result.cols = std.fmt.parseUnsigned(usize, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--generations=")) {
            const vstr = a["--generations=".len..];
            result.generations = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--generations")) {
            if (i + 1 < args.len) {
                result.generations = std.fmt.parseUnsigned(u64, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--delay=")) {
            const vstr = a["--delay=".len..];
            result.delay_ms = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--delay")) {
            if (i + 1 < args.len) {
                result.delay_ms = std.fmt.parseUnsigned(u64, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--pattern=")) {
            const vstr = a["--pattern=".len..];
            result.pattern_file = try allocator.dupe(u8, vstr);
            continue;
        }

        if (std.mem.eql(u8, a, "--pattern")) {
            if (i + 1 < args.len) {
                result.pattern_file = try allocator.dupe(u8, args[i + 1]);
                i += 1;
            }
            continue;
        }

        // Positional arguments
        if (a.len > 0 and a[0] != '-') {
            if (pos_count < pos_vals.len) {
                if (std.fmt.parseUnsigned(u64, a, constants.DECIMAL_BASE)) |v| {
                    pos_vals[pos_count] = v;
                    pos_count += 1;
                } else |_| {}
            }
            continue;
        }
    }

    // Apply positional ordered params: height width generations delay
    if (pos_count > 0 and result.rows == null)
        result.rows = @as(usize, @intCast(pos_vals[0]));
    if (pos_count > 1 and result.cols == null)
        result.cols = @as(usize, @intCast(pos_vals[1]));
    if (pos_count > 2 and result.generations == null)
        result.generations = pos_vals[2];
    if (pos_count > 3 and result.delay_ms == null)
        result.delay_ms = pos_vals[3];

    return result;
}

/// Print help message
pub fn printHelp(renderer: anytype) !void {
    try renderer.print(constants.HELP_TEXT, .{});
}
