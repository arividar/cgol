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

fn neighborCount(grid: []const u8, rows: usize, cols: usize, r: usize, c: usize) u8 {
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
    return n;
}

fn stepGrid(curr: []const u8, rows: usize, cols: usize, next: []u8) void {
    var r: usize = 0;
    while (r < rows) : (r += 1) {
        var c: usize = 0;
        while (c < cols) : (c += 1) {
            const n = neighborCount(curr, rows, cols, r, c);
            const alive = curr[idx(r, c, cols)] == 1;
            next[idx(r, c, cols)] = if (alive and (n == 2 or n == 3)) 1 else if (!alive and n == 3) 1 else 0;
        }
    }
}

pub fn main() !void {
    const stdout_file = std.fs.File{ .handle = 1 }; // stdout is fd 1
    
    // Create a print function for stdout
    const print = struct {
        fn print(comptime format: []const u8, args: anytype) !void {
            var buf: [4096]u8 = undefined;
            const formatted = try std.fmt.bufPrint(buf[0..], format, args);
            _ = try stdout_file.writeAll(formatted);
        }
    }.print;
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Hide cursor now; restore at exit
    try print("\x1b[?25l", .{});
    defer print("\x1b[?25h\x1b[0m\n", .{}) catch {};

    const stdin_file = std.fs.File{ .handle = 0 }; // stdin is fd 0
    
    // Simple input reading function
    const readLine = struct {
        var input_buffer: [1024]u8 = undefined;
        var buffer_pos: usize = 0;
        var buffer_end: usize = 0;
        
        fn readLine(alloc: std.mem.Allocator, _: usize) !?[]u8 {
            var line: [256]u8 = undefined;
            var line_pos: usize = 0;
            
            while (line_pos < line.len - 1) {
                // Refill buffer if empty
                if (buffer_pos >= buffer_end) {
                    buffer_end = try stdin_file.read(input_buffer[0..]);
                    buffer_pos = 0;
                    if (buffer_end == 0) {
                        if (line_pos == 0) return null;
                        break;
                    }
                }
                
                const char = input_buffer[buffer_pos];
                buffer_pos += 1;
                
                if (char == '\n') break;
                line[line_pos] = char;
                line_pos += 1;
            }
            
            return try alloc.dupe(u8, std.mem.trim(u8, line[0..line_pos], " \t\r\n"));
        }
    }.readLine;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    try print("Enter rows and cols (e.g., 25 60): ", .{});
    const line1_opt = try readLine(alloc, 256);
    const line1 = line1_opt orelse return error.InvalidInput;
    var it = std.mem.tokenizeAny(u8, line1, " \t\r");
    const rows = try std.fmt.parseUnsigned(usize, it.next() orelse return error.InvalidInput, 10);
    const cols = try std.fmt.parseUnsigned(usize, it.next() orelse return error.InvalidInput, 10);

    try print("Generations to run (0 = infinite, default=100): ", .{});
    const line2_opt = try readLine(alloc, 128);
    const line2 = line2_opt orelse return error.InvalidInput;
    var gens: u64 = 100;
    if (line2_opt) |l2| {
        const t = std.mem.trim(u8, l2, " \t\r\n");
        if (t.len != 0) 
            gens = try std.fmt.parseUnsigned(usize, std.mem.trim(u8, line2, " \t\r\n"), 10);
    }

    try print("Delay per generation in ms [default 100]: ", .{});
    const line3_opt = try readLine(alloc, 128);
    var delay_ms: u64 = 100;
    if (line3_opt) |l3| {
        const t = std.mem.trim(u8, l3, " \t\r\n");
        if (t.len != 0) delay_ms = try std.fmt.parseUnsigned(u64, t, 10);
    }

    const count = rows * cols;
    const a = allocator;

    var grid = try a.alloc(u8, count);
    defer a.free(grid);
    var next = try a.alloc(u8, count);
    defer a.free(next);

    // Seed RNG & randomize initial state (~35% alive)
    var prng = std.Random.DefaultPrng.init(@as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))));
    const rand = prng.random();
    for (grid) |*cell| cell.* = if (rand.float(f64) < 0.35) 1 else 0;

    // Prepare screen: clear & home
    try print("\x1b[2J\x1b[H", .{});

    var gen: usize = 0;
    while (gens == 0 or gen < gens) : (gen += 1) {
        // Draw frame
        try print("\x1b[H", .{}); // move cursor home
        for (0..rows) |r| {
            for (0..cols) |c| {
                const alive = grid[idx(r, c, cols)] == 1;
                if (alive) try print("\x1b[38;5;46m\u{2588}", .{}) else try print(" ", .{});
            }
            try print("\n", .{});
        }
        try print("\x1b[0mGen: {d}  (Ctrl+C to quit)\n", .{gen+1});

        // Compute next generation (toroidal wrap)
        stepGrid(grid, rows, cols, next);

        // Swap buffers
        const tmp = grid; grid = next; next = tmp;

        std.Thread.sleep(delay_ms * std.time.ns_per_ms);
    }
}

test "addWrap" {
    try std.testing.expectEqual(@as(usize, 9), addWrap(0, -1, 10));
    try std.testing.expectEqual(@as(usize, 1), addWrap(0, 1, 10));
    try std.testing.expectEqual(@as(usize, 0), addWrap(9, 1, 10));
}

test "neighborCount wraps across edges" {
    const rows: usize = 5;
    const cols: usize = 5;
    var grid = [_]u8{0} ** (rows * cols);
    // Place neighbors that should wrap to (0,0)'s neighborhood
    grid[idx(0, 4, cols)] = 1; // left neighbor wraps from col 4
    grid[idx(4, 0, cols)] = 1; // top neighbor wraps from row 4
    grid[idx(4, 4, cols)] = 1; // top-left diagonal wraps
    const n = neighborCount(grid[0..], rows, cols, 0, 0);
    try std.testing.expectEqual(@as(u8, 3), n);
}

test "stepGrid preserves block still life" {
    const rows: usize = 5;
    const cols: usize = 5;
    var curr = [_]u8{0} ** (rows * cols);
    var next = [_]u8{0} ** (rows * cols);
    // 2x2 block at (2,2), (2,3), (3,2), (3,3)
    curr[idx(2, 2, cols)] = 1;
    curr[idx(2, 3, cols)] = 1;
    curr[idx(3, 2, cols)] = 1;
    curr[idx(3, 3, cols)] = 1;

    stepGrid(curr[0..], rows, cols, next[0..]);

    // Expect unchanged
    const eql = std.mem.eql(u8, curr[0..], next[0..]);
    try std.testing.expect(eql);
}

test "stepGrid blinker oscillates" {
    const rows: usize = 5;
    const cols: usize = 5;
    var a = [_]u8{0} ** (rows * cols);
    var b = [_]u8{0} ** (rows * cols);
    var c = [_]u8{0} ** (rows * cols);

    // Horizontal blinker centered at row 2, cols 1..3
    a[idx(2, 1, cols)] = 1;
    a[idx(2, 2, cols)] = 1;
    a[idx(2, 3, cols)] = 1;

    // Expected after 1 step: vertical at col 2, rows 1..3
    var expected1 = [_]u8{0} ** (rows * cols);
    expected1[idx(1, 2, cols)] = 1;
    expected1[idx(2, 2, cols)] = 1;
    expected1[idx(3, 2, cols)] = 1;

    stepGrid(a[0..], rows, cols, b[0..]);
    try std.testing.expect(std.mem.eql(u8, b[0..], expected1[0..]));

    // After second step, should return to original
    stepGrid(b[0..], rows, cols, c[0..]);
    try std.testing.expect(std.mem.eql(u8, c[0..], a[0..]));
}
