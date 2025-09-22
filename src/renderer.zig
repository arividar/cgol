const std = @import("std");
const posix = std.posix;
const game = @import("game.zig");
const constants = @import("constants.zig");

pub const TermSize = struct { rows: usize, cols: usize };

/// Get terminal size using ioctl
pub fn getTermSize() TermSize {
    // Default conservative guess
    var ts: TermSize = .{ .rows = constants.DEFAULT_TERM_ROWS, .cols = constants.DEFAULT_TERM_COLS };
    var wsz: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    const fd: posix.fd_t = constants.STDOUT_FD;
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
        const stdout_file = std.fs.File{ .handle = constants.STDOUT_FD };
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
        // Cells must fit within: top frame + rows + bottom frame + status
        const max_rows_cells: usize = if (self.term_size.rows > constants.FRAME_OVERHEAD_ROWS) self.term_size.rows - constants.FRAME_OVERHEAD_ROWS else constants.MIN_GRID_SIZE;
        // Each cell is 2 chars wide; plus left/right frame and padding
        var max_cols_cells: usize = if (self.term_size.cols > constants.FRAME_OVERHEAD_COLS) (self.term_size.cols - constants.FRAME_OVERHEAD_COLS) / constants.CELL_WIDTH_CHARS else constants.MIN_GRID_SIZE;
        if (max_cols_cells == 0) max_cols_cells = constants.MIN_GRID_SIZE;

        // Clamp requested board to what fits visibly
        rows.* = if (rows.* > max_rows_cells) max_rows_cells else rows.*;
        cols.* = if (cols.* > max_cols_cells) max_cols_cells else cols.*;

        // Compute padding to center the grid (accounting for frame)
        self.vert_pad = if (self.term_size.rows > rows.* + constants.FRAME_OVERHEAD_ROWS) (self.term_size.rows - constants.FRAME_OVERHEAD_ROWS - rows.*) / 2 else 0;
        self.horiz_pad_chars = blk: {
            const needed = cols.* * constants.CELL_WIDTH_CHARS + constants.FRAME_OVERHEAD_COLS;
            if (self.term_size.cols > needed) break :blk (self.term_size.cols - needed) / 2 else break :blk 0;
        };
    }

    /// Print formatted text to stdout
    pub fn print(self: *Renderer, comptime format: []const u8, args: anytype) !void {
        var buf: [constants.PRINT_BUFFER_SIZE]u8 = undefined;
        const formatted = try std.fmt.bufPrint(buf[0..], format, args);
        _ = try self.stdout.writeAll(formatted);
    }

    /// Hide cursor
    pub fn hideCursor(self: *Renderer) !void {
        try self.print(constants.ANSI_HIDE_CURSOR, .{});
    }

    /// Show cursor and reset terminal
    pub fn showCursor(self: *Renderer) !void {
        try self.print(constants.ANSI_SHOW_CURSOR ++ constants.ANSI_RESET_TERMINAL, .{});
    }

    /// Clear screen
    pub fn clearScreen(self: *Renderer) !void {
        try self.print(constants.ANSI_CLEAR_SCREEN, .{});
    }

    /// Draw top frame line
    fn drawTopFrame(self: *Renderer, cols: usize) !void {
        try self.print("\x1b[{d};{d}H" ++ constants.ANSI_RESET_COLOR ++ constants.BOX_TOP_LEFT, .{ self.vert_pad + 1, self.horiz_pad_chars + 1 });
        try self.print(constants.BOX_HORIZONTAL, .{}); // padding space
        for (0..cols) |_| {
            try self.print(constants.BOX_HORIZONTAL ++ constants.BOX_HORIZONTAL, .{});
        }
        try self.print(constants.BOX_HORIZONTAL ++ constants.BOX_TOP_RIGHT, .{}); // padding space + corner
    }

    /// Draw bottom frame line
    fn drawBottomFrame(self: *Renderer, rows: usize, cols: usize) !void {
        try self.print("\x1b[{d};{d}H" ++ constants.ANSI_RESET_COLOR ++ constants.BOX_BOTTOM_LEFT, .{ self.vert_pad + 2 + rows, self.horiz_pad_chars + 1 });
        try self.print(constants.BOX_HORIZONTAL, .{}); // padding space
        for (0..cols) |_| {
            try self.print(constants.BOX_HORIZONTAL ++ constants.BOX_HORIZONTAL, .{});
        }
        try self.print(constants.BOX_HORIZONTAL ++ constants.BOX_BOTTOM_RIGHT, .{}); // padding space + corner
    }

    /// Draw a single grid row with side frames
    fn drawGridRow(self: *Renderer, grid: []const u8, row: usize, cols: usize, grid_row: usize) !void {
        // Position cursor and draw left frame
        try self.print("\x1b[{d};{d}H" ++ constants.ANSI_RESET_COLOR ++ constants.BOX_VERTICAL, .{ row, self.horiz_pad_chars + 1 });

        // Draw grid row with padding
        try self.print(" ", .{});
        for (0..cols) |c| {
            const alive = grid[game.idx(grid_row, c, cols)] == constants.CELL_ALIVE;
            if (alive) {
                try self.print(constants.ANSI_LIVE_CELL_COLOR ++ constants.LIVE_CELL_CHAR, .{});
            } else {
                try self.print(constants.DEAD_CELL_CHAR, .{});
            }
        }

        // Draw right frame
        try self.print(constants.ANSI_RESET_COLOR ++ " " ++ constants.BOX_VERTICAL, .{});
    }

    /// Draw the status line below the game grid
    fn drawStatusLine(self: *Renderer, rows: usize, generation: usize) !void {
        try self.print("\x1b[{d};1H" ++ constants.ANSI_RESET_COLOR ++ constants.ANSI_CLEAR_LINE ++ constants.STATUS_MESSAGE, .{ self.vert_pad + 3 + rows, generation + 1 });
    }

    /// Render the game grid with frame and status
    pub fn renderFrame(self: *Renderer, grid: []const u8, rows: usize, cols: usize, generation: usize) !void {
        // Draw top frame
        try self.drawTopFrame(cols);

        // Draw grid with side frames
        for (0..rows) |r| {
            try self.drawGridRow(grid, self.vert_pad + 2 + r, cols, r);
        }

        // Draw bottom frame
        try self.drawBottomFrame(rows, cols);

        // Draw status line
        try self.drawStatusLine(rows, generation);
    }
};
