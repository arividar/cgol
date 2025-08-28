// Save as: game_of_life.zig
// Build:   zig build-exe -O ReleaseSafe game_of_life.zig
// Run:     ./game_of_life
//            → Enter rows & cols (e.g., 25 60)
//            → Enter generations to run (0 = infinite)
//            → Optional delay per generation in ms (default 80)

const std = @import("std");

fn idx(r: usize, c: usize, cols: usize) usize { return r * cols + c; }

fn addWrap(i: usize, delta: i32, max: usize) usize {
    const m: i64 = @as(i64, @intCast(max));
    var v: i64 = @as(i64, @intCast(i)) + @as(i64, @intCast(delta));
    v = @mod(v, m);
    if (v < 0) v += m;
    return @as(usize, @intCast(v));
}

pub fn main() !void {
    const stdout = std.process.getStdOut().writer();
    const stdin = std.process.getStdIn().reader();

    // Hide cursor now; restore at exit
    try stdout.print("\x1b[?25l", .{});
    defer stdout.print("\x1b[?25h\x1b[0m\n", .{}) catch {};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    try stdout.print("Enter rows and cols (e.g., 25 60): ", .{});
    const line1_opt = try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', 256);
    const line1 = line1_opt orelse return error.InvalidInput;
    var it = std.mem.tokenizeAny(u8, line1, " \t\r");
    const rows = try std.fmt.parseUnsigned(usize, it.next() orelse return error.InvalidInput, 10);
    const cols = try std.fmt.parseUnsigned(usize, it.next() orelse return error.InvalidInput, 10);

    try stdout.print("Generations to run (0 = infinite): ", .{});
    const line2_opt = try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', 128);
    const line2 = line2_opt orelse return error.InvalidInput;
    const gens = try std.fmt.parseUnsigned(usize, std.mem.trim(u8, line2, " \t\r\n"), 10);

    try stdout.print("Delay per generation in ms [default 80]: ", .{});
    const line3_opt = try stdin.readUntilDelimiterOrEofAlloc(alloc, '\n', 128);
    var delay_ms: u64 = 80;
    if (line3_opt) |l3| {
        const t = std.mem.trim(u8, l3, " \t\r\n");
        if (t.len != 0) delay_ms = try std.fmt.parseUnsigned(u64, t, 10);
    }

    const count = rows * cols;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    var grid = try a.alloc(u8, count);
    defer a.free(grid);
    var next = try a.alloc(u8, count);
    defer a.free(next);

    // Seed RNG & randomize initial state (~35% alive)
    var prng = std.rand.DefaultPrng.init(@truncate(std.time.nanoTimestamp()));
    const rand = prng.random();
    for (grid) |*cell| cell.* = if (rand.float(f64) < 0.35) 1 else 0;

    // Prepare screen: clear & home
    try stdout.print("\x1b[2J\x1b[H", .{});

    var gen: usize = 0;
    while (gens == 0 or gen < gens) : (gen += 1) {
        // Draw frame
        try stdout.print("\x1b[H", .{}); // move cursor home
        for (rows) |r| {
            for (cols) |c| {
                const alive = grid[idx(r, c, cols)] == 1;
                if (alive) try stdout.print("\x1b[38;5;46m\u{2588}", .{}) else try stdout.print(" ", .{});
            }
            try stdout.print("\n", .{});
        }
        try stdout.print("\x1b[0mGen: {d}  (Ctrl+C to quit)\n", .{gen});

        // Compute next generation (toroidal wrap)
        for (rows) |r| {
            for (cols) |c| {
                var n: u8 = 0;
                var dr: i32 = -1;
                while (dr <= 1) : (dr += 1) {
                    var dc: i32 = -1;
                    while (dc <= 1) : (dc += 1) {
                        if (dr == 0 and dc == 0) continue;
                        const rr = addWrap(r, dr, rows);
                        const cc = addWrap(c, dc, cols);
                        if (grid[idx(rr, cc, cols)] == 1) n += 1;
                    }
                }
                const alive = grid[idx(r, c, cols)] == 1;
                next[idx(r, c, cols)] = if (alive and (n == 2 or n == 3)) 1 else if (!alive and n == 3) 1 else 0;
            }
        }

        // Swap buffers
        const tmp = grid; grid = next; next = tmp;

        std.time.sleep(delay_ms * std.time.ns_per_ms);
    }
}

test "addWrap" {
    try std.testing.expectEqual(@as(usize, 0), addWrap(0, -1, 10));
    try std.testing.expectEqual(@as(usize, 9), addWrap(0, -1, 10));
    try std.testing.expectEqual(@as(usize, 1), addWrap(0, 1, 10));
    try std.testing.expectEqual(@as(usize, 0), addWrap(9, 1, 10));
}
