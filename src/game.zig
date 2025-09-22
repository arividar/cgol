const std = @import("std");
const constants = @import("constants.zig");

/// Convert 2D grid coordinates to 1D array index
pub fn idx(r: usize, c: usize, cols: usize) usize {
    return r * cols + c;
}

/// Add delta to index with wrapping (toroidal boundary)
pub fn addWrap(i: usize, delta: i32, max: usize) usize {
    const m: i64 = @as(i64, @intCast(max));
    var v: i64 = @as(i64, @intCast(i)) + @as(i64, @intCast(delta));
    v = @mod(v, m);
    if (v < 0) v += m;
    return @as(usize, @intCast(v));
}

/// Count live neighbors for a cell at position (r, c)
pub fn neighborCount(grid: []const u8, rows: usize, cols: usize, r: usize, c: usize) u8 {
    var n: u8 = 0;
    var dr: i32 = -1;
    while (dr <= 1) : (dr += 1) {
        var dc: i32 = -1;
        while (dc <= 1) : (dc += 1) {
            if (dr == 0 and dc == 0) continue;
            const rr = addWrap(r, dr, rows);
            const cc = addWrap(c, dc, cols);
            if (grid[idx(rr, cc, cols)] == constants.CELL_ALIVE) n += 1;
        }
    }
    return n;
}

/// Compute next generation using Conway's Game of Life rules
pub fn stepGrid(curr: []const u8, rows: usize, cols: usize, next: []u8) void {
    var r: usize = 0;
    while (r < rows) : (r += 1) {
        var c: usize = 0;
        while (c < cols) : (c += 1) {
            const n = neighborCount(curr, rows, cols, r, c);
            const alive = curr[idx(r, c, cols)] == constants.CELL_ALIVE;
            next[idx(r, c, cols)] = if (alive and (n == constants.NEIGHBOR_SURVIVE_MIN or n == constants.NEIGHBOR_SURVIVE_MAX)) constants.CELL_ALIVE else if (!alive and n == constants.NEIGHBOR_BIRTH) constants.CELL_ALIVE else constants.CELL_DEAD;
        }
    }
}

/// Initialize grid with random pattern
pub fn initializeRandomGrid(grid: []u8, density: f64, rand: std.Random) void {
    for (grid) |*cell| {
        cell.* = if (rand.float(f64) < density) constants.CELL_ALIVE else constants.CELL_DEAD;
    }
}

// Tests
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
    grid[idx(0, 4, cols)] = constants.CELL_ALIVE; // left neighbor wraps from col 4
    grid[idx(4, 0, cols)] = constants.CELL_ALIVE; // top neighbor wraps from row 4
    grid[idx(4, 4, cols)] = constants.CELL_ALIVE; // top-left diagonal wraps
    const n = neighborCount(grid[0..], rows, cols, 0, 0);
    try std.testing.expectEqual(@as(u8, 3), n);
}

test "stepGrid preserves block still life" {
    const rows: usize = 5;
    const cols: usize = 5;
    var curr = [_]u8{0} ** (rows * cols);
    var next = [_]u8{0} ** (rows * cols);
    // 2x2 block at (2,2), (2,3), (3,2), (3,3)
    curr[idx(2, 2, cols)] = constants.CELL_ALIVE;
    curr[idx(2, 3, cols)] = constants.CELL_ALIVE;
    curr[idx(3, 2, cols)] = constants.CELL_ALIVE;
    curr[idx(3, 3, cols)] = constants.CELL_ALIVE;

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
    a[idx(2, 1, cols)] = constants.CELL_ALIVE;
    a[idx(2, 2, cols)] = constants.CELL_ALIVE;
    a[idx(2, 3, cols)] = constants.CELL_ALIVE;

    // Expected after 1 step: vertical at col 2, rows 1..3
    var expected1 = [_]u8{constants.CELL_DEAD} ** (rows * cols);
    expected1[idx(1, 2, cols)] = constants.CELL_ALIVE;
    expected1[idx(2, 2, cols)] = constants.CELL_ALIVE;
    expected1[idx(3, 2, cols)] = constants.CELL_ALIVE;

    stepGrid(a[0..], rows, cols, b[0..]);
    try std.testing.expect(std.mem.eql(u8, b[0..], expected1[0..]));

    // After second step, should return to original
    stepGrid(b[0..], rows, cols, c[0..]);
    try std.testing.expect(std.mem.eql(u8, c[0..], a[0..]));
}
