const std = @import("std");

pub const CliArgs = struct {
    force_prompt: bool = false,
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
    show_help: bool = false,
};

/// Parse command line arguments
pub fn parseArgs(allocator: std.mem.Allocator) !CliArgs {
    var result = CliArgs{};

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var pos_vals: [4]u64 = undefined;
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
            result.rows = std.fmt.parseUnsigned(usize, vstr, 10) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--height")) {
            if (i + 1 < args.len) {
                result.rows = std.fmt.parseUnsigned(usize, args[i + 1], 10) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--width=")) {
            const vstr = a["--width=".len..];
            result.cols = std.fmt.parseUnsigned(usize, vstr, 10) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--width")) {
            if (i + 1 < args.len) {
                result.cols = std.fmt.parseUnsigned(usize, args[i + 1], 10) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--generations=")) {
            const vstr = a["--generations=".len..];
            result.generations = std.fmt.parseUnsigned(u64, vstr, 10) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--generations")) {
            if (i + 1 < args.len) {
                result.generations = std.fmt.parseUnsigned(u64, args[i + 1], 10) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--delay=")) {
            const vstr = a["--delay=".len..];
            result.delay_ms = std.fmt.parseUnsigned(u64, vstr, 10) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--delay")) {
            if (i + 1 < args.len) {
                result.delay_ms = std.fmt.parseUnsigned(u64, args[i + 1], 10) catch null;
                i += 1;
            }
            continue;
        }

        // Positional arguments
        if (a.len > 0 and a[0] != '-') {
            if (pos_count < pos_vals.len) {
                if (std.fmt.parseUnsigned(u64, a, 10)) |v| {
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
    try renderer.print(
        "Conway's Game of Life (terminal)\n\n" ++
            "Usage:\n" ++
            "  cgol [options]\n" ++
            "  cgol <rows> <cols> <generations> <delay_ms>\n\n" ++
            "Options:\n" ++
            "  --height <rows>          Board height (also --height=40)\n" ++
            "  --width <cols>           Board width (also --width=60)\n" ++
            "  --generations <n>        0 for infinite (also --generations=0)\n" ++
            "  --delay <ms>             Delay per generation in ms (also --delay=120)\n" ++
            "  -p, --prompt-for-config  Force interactive prompts for missing values\n" ++
            "  -h, --help               Show this help and exit\n\n" ++
            "Configuration:\n" ++
            "  Reads/writes cgol.toml at repo root. Missing/partial values prompt.\n",
        .{},
    );
}
