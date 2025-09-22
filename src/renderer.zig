const std = @import("std");
const posix = std.posix;
const game = @import("game.zig");

pub const TermSize = struct { rows: usize, cols: usize };

/// Get terminal size using ioctl
pub fn getTermSize() TermSize {
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

/// Terminal renderer for Game of Life
pub const Renderer = struct {
    stdout: std.fs.File,
    term_size: TermSize,
    vert_pad: usize,
    horiz_pad_chars: usize,

    pub fn init() Renderer {
        const stdout_file = std.fs.File{ .handle = 1 };
        const term = getTermSize();
        return Renderer{
            .stdout = stdout_file,
            .term_size = term,
            .vert_pad = 0,
            .horiz_pad_chars = 0,
        };
    }

    /// Calculate padding and adjust grid dimensions to fit terminal
    pub fn calculateLayout(self: *Renderer, rows: *usize, cols: *usize) void {
        // Cells must fit within: top frame + rows + bottom frame + status = rows + 3 lines
        const max_rows_cells: usize = if (self.term_size.rows > 3) self.term_size.rows - 3 else 1;
        // Each cell is 2 chars wide; plus left/right frame and one space padding on each side = +4
        var max_cols_cells: usize = if (self.term_size.cols > 4) (self.term_size.cols - 4) / 2 else 1;
        if (max_cols_cells == 0) max_cols_cells = 1;

        // Clamp requested board to what fits visibly
        rows.* = if (rows.* > max_rows_cells) max_rows_cells else rows.*;
        cols.* = if (cols.* > max_cols_cells) max_cols_cells else cols.*;

        // Compute padding to center the grid (accounting for frame)
        self.vert_pad = if (self.term_size.rows > rows.* + 3) (self.term_size.rows - 3 - rows.*) / 2 else 0;
        self.horiz_pad_chars = blk: {
            const needed = cols.* * 2 + 4; // +4 for left/right frame + inside padding
            if (self.term_size.cols > needed) break :blk (self.term_size.cols - needed) / 2 else break :blk 0;
        };
    }

    /// Print formatted text to stdout
    pub fn print(self: *Renderer, comptime format: []const u8, args: anytype) !void {
        var buf: [4096]u8 = undefined;
        const formatted = try std.fmt.bufPrint(buf[0..], format, args);
        _ = try self.stdout.writeAll(formatted);
    }

    /// Hide cursor
    pub fn hideCursor(self: *Renderer) !void {
        try self.print("\x1b[?25l", .{});
    }

    /// Show cursor and reset terminal
    pub fn showCursor(self: *Renderer) !void {
        try self.print("\x1b[?25h\x1b[0m\n", .{});
    }

    /// Clear screen
    pub fn clearScreen(self: *Renderer) !void {
        try self.print("\x1b[2J", .{});
    }

    /// Render the game grid with frame and status
    pub fn renderFrame(self: *Renderer, grid: []const u8, rows: usize, cols: usize, generation: usize) !void {
        // Draw top frame
        try self.print("\x1b[{d};{d}H\x1b[0m\u{250C}", .{ self.vert_pad + 1, self.horiz_pad_chars + 1 });
        try self.print("\u{2500}", .{}); // padding space
        for (0..cols) |_| {
            try self.print("\u{2500}\u{2500}", .{});
        }
        try self.print("\u{2500}\u{2510}", .{}); // padding space + corner

        // Draw grid with side frames
        for (0..rows) |r| {
            // Position cursor and draw left frame
            try self.print("\x1b[{d};{d}H\x1b[0m\u{2502}", .{ self.vert_pad + 2 + r, self.horiz_pad_chars + 1 });
            // Draw grid row with padding
            try self.print(" ", .{});
            for (0..cols) |c| {
                const alive = grid[game.idx(r, c, cols)] == 1;
                if (alive) try self.print("\x1b[38;5;46m\u{2588}\u{2588}", .{}) else try self.print("  ", .{});
            }
            // Draw right frame
            try self.print("\x1b[0m \u{2502}", .{});
        }

        // Draw bottom frame
        try self.print("\x1b[{d};{d}H\x1b[0m\u{2514}", .{ self.vert_pad + 2 + rows, self.horiz_pad_chars + 1 });
        try self.print("\u{2500}", .{}); // padding space
        for (0..cols) |_| {
            try self.print("\u{2500}\u{2500}", .{});
        }
        try self.print("\u{2500}\u{2518}", .{}); // padding space + corner

        // Status line below the frame
        try self.print("\x1b[{d};1H\x1b[0m\x1b[2KGen: {d}  (Ctrl+C to quit)", .{ self.vert_pad + 3 + rows, generation + 1 });
    }
};
