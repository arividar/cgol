// Save as: cgol.zig
// Build:   zig build
// Run:     zig build run
//            → Enter rows & cols (e.g., 40 60) or configure via gol.toml
//            → Enter generations to run (0 = infinite)
//            → Optional delay per generation in ms (default 100)

const std = @import("std");
const posix = std.posix;

fn idx(r: usize, c: usize, cols: usize) usize { return r * cols + c; }

fn addWrap(i: usize, delta: i32, max: usize) usize {
    const m: i64 = @as(i64, @intCast(max));
    var v: i64 = @as(i64, @intCast(i)) + @as(i64, @intCast(delta));
    v = @mod(v, m);
    if (v < 0) v += m;
    return @as(usize, @intCast(v));
}

const TermSize = struct { rows: usize, cols: usize };

fn getTermSize() TermSize {
    // Default conservative guess
    var ts: TermSize = .{ .rows = 25, .cols = 80 };
    var wsz: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    const fd: posix.fd_t = 1; // stdout
    const rc = posix.system.ioctl(fd, posix.T.IOCGWINSZ, @intFromPtr(&wsz));
    if (posix.errno(rc) == .SUCCESS and wsz.row != 0 and wsz.col != 0) {
        ts.rows = wsz.row;
        ts.cols = wsz.col;
    }
    return ts;
}

const ConfigPartial = struct {
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
};

fn loadConfig(alloc: std.mem.Allocator) ConfigPartial {
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
        const val_str = std.mem.trim(u8, line[i+1..], " \t");
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

fn writeConfig(rows: usize, cols: usize, generations: u64, delay_ms: u64) !void {
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

    // Parse CLI flags
    var force_prompt: bool = false;
    {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);
        var i: usize = 1; // skip program name
        while (i < args.len) : (i += 1) {
            const a = args[i];
            if (std.mem.eql(u8, a, "--prompt-user-for-config") or std.mem.eql(u8, a, "-p")) {
                force_prompt = true;
            }
        }
    }

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

    // Load configuration; prompt only for missing fields unless forced by CLI
    const cfg = if (force_prompt) ConfigPartial{} else loadConfig(alloc);
    var rows: usize = cfg.rows orelse 40;
    var cols: usize = cfg.cols orelse 60;
    const need_prompt_rows_cols = force_prompt or (cfg.rows == null or cfg.cols == null);
    if (need_prompt_rows_cols) {
        try print("Enter rows and cols (e.g., 25 60) [default {d} {d}]: ", .{rows, cols});
        const line1_opt = try readLine(alloc, 256);
        if (line1_opt) |line1_raw| {
            const line1 = std.mem.trim(u8, line1_raw, " \t\r\n");
            if (line1.len != 0) {
                var it1 = std.mem.tokenizeAny(u8, line1, " \t\r");
                if (it1.next()) |rows_s| rows = try std.fmt.parseUnsigned(usize, rows_s, 10);
                if (it1.next()) |cols_s| cols = try std.fmt.parseUnsigned(usize, cols_s, 10);
            }
        }
    }

    var gens: u64 = cfg.generations orelse 100;
    if (force_prompt or cfg.generations == null) {
        try print("Generations to run (0 = infinite, default={d}): ", .{gens});
        const line2_opt = try readLine(alloc, 128);
        if (line2_opt) |l2| {
            const t = std.mem.trim(u8, l2, " \t\r\n");
            if (t.len != 0) gens = try std.fmt.parseUnsigned(u64, t, 10);
        }
    }

    var delay_ms: u64 = cfg.delay_ms orelse 100;
    if (force_prompt or cfg.delay_ms == null) {
        try print("Delay per generation in ms [default {d}]: ", .{delay_ms});
        const line3_opt = try readLine(alloc, 128);
        if (line3_opt) |l3| {
            const t = std.mem.trim(u8, l3, " \t\r\n");
            if (t.len != 0) delay_ms = try std.fmt.parseUnsigned(u64, t, 10);
        }
    }

    // Persist full config so future runs do not prompt
    writeConfig(rows, cols, gens, delay_ms) catch {};

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

    // Determine terminal size and adjust/center grid
    const term = getTermSize();
    const max_rows = if (term.rows > 1) term.rows - 1 else 1; // leave one line for status
    var max_cols_cells = term.cols / 2; // two characters per cell
    if (max_cols_cells == 0) max_cols_cells = 1;

    var rows_adj = rows;
    var cols_adj = cols;
    if (rows_adj > max_rows) rows_adj = max_rows;
    if (cols_adj > max_cols_cells) cols_adj = max_cols_cells;

    // Reassign working dimensions
    rows = rows_adj;
    cols = cols_adj;

    // Compute padding to center the grid
    const vert_pad = if (term.rows > rows + 1) (term.rows - 1 - rows) / 2 else 0;
    const horiz_pad_chars = blk: {
        const needed = cols * 2;
        if (term.cols > needed) break :blk (term.cols - needed) / 2 else break :blk 0;
    };

    // Prepare screen: clear
    try print("\x1b[2J", .{});

    var gen: usize = 0;
    while (gens == 0 or gen < gens) : (gen += 1) {
        // Draw frame
        for (0..rows) |r| {
            // Position cursor at start of this row within centered area
            try print("\x1b[{d};{d}H", .{ vert_pad + 1 + r, horiz_pad_chars + 1 });
            for (0..cols) |c| {
                const alive = grid[idx(r, c, cols)] == 1;
                if (alive) try print("\x1b[38;5;46m\u{2588}\u{2588}", .{}) else try print("  ", .{});
            }
        }
        // Status line below the grid
        try print("\x1b[{d};1H\x1b[0mGen: {d}  (Ctrl+C to quit)\n", .{ vert_pad + rows + 1, gen + 1 });

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
