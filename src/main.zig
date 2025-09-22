const std = @import("std");
const game = @import("game.zig");
const config = @import("config.zig");
const renderer = @import("renderer.zig");
const cli = @import("cli.zig");
const input = @import("input.zig");
const constants = @import("constants.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    const args = try cli.parseArgs(allocator);

    // Initialize renderer
    var render = renderer.Renderer.init();

    // Show help if requested
    if (args.show_help) {
        try cli.printHelp(&render);
        return;
    }

    // Hide cursor now; restore at exit
    try render.hideCursor();
    defer render.showCursor() catch {};

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Load configuration; prompt only for missing fields unless forced by CLI
    const cfg = if (args.force_prompt) config.ConfigPartial{} else config.loadConfig(alloc);
    var rows: usize = args.rows orelse (cfg.rows orelse constants.DEFAULT_ROWS);
    var cols: usize = args.cols orelse (cfg.cols orelse constants.DEFAULT_COLS);

    // Handle interactive prompts for missing configuration
    var input_reader = input.InputReader.init();
    const have_rows = (args.rows != null) or (cfg.rows != null);
    const have_cols = (args.cols != null) or (cfg.cols != null);
    const need_prompt_rows_cols = (args.force_prompt and !(args.rows != null and args.cols != null)) or (!have_rows or !have_cols);

    if (need_prompt_rows_cols) {
        try render.print(constants.PROMPT_ROWS_COLS, .{ rows, cols });
        const line1_opt = try input_reader.readLine(alloc);
        if (line1_opt) |line1_raw| {
            const line1 = std.mem.trim(u8, line1_raw, constants.WHITESPACE_CHARS);
            if (line1.len != 0) {
                var it1 = std.mem.tokenizeAny(u8, line1, constants.TRIM_CHARS);
                if (it1.next()) |rows_s| rows = try std.fmt.parseUnsigned(usize, rows_s, constants.DECIMAL_BASE);
                if (it1.next()) |cols_s| cols = try std.fmt.parseUnsigned(usize, cols_s, constants.DECIMAL_BASE);
            }
        }
    }

    var gens: u64 = args.generations orelse (cfg.generations orelse constants.DEFAULT_GENERATIONS);
    if ((args.force_prompt and args.generations == null) or (cfg.generations == null and args.generations == null)) {
        try render.print(constants.PROMPT_GENERATIONS, .{gens});
        const line2_opt = try input_reader.readLine(alloc);
        if (line2_opt) |l2| {
            const t = std.mem.trim(u8, l2, constants.WHITESPACE_CHARS);
            if (t.len != 0) gens = try std.fmt.parseUnsigned(u64, t, constants.DECIMAL_BASE);
        }
    }

    var delay_ms: u64 = args.delay_ms orelse (cfg.delay_ms orelse constants.DEFAULT_DELAY_MS);
    if ((args.force_prompt and args.delay_ms == null) or (cfg.delay_ms == null and args.delay_ms == null)) {
        try render.print(constants.PROMPT_DELAY, .{delay_ms});
        const line3_opt = try input_reader.readLine(alloc);
        if (line3_opt) |l3| {
            const t = std.mem.trim(u8, l3, constants.WHITESPACE_CHARS);
            if (t.len != 0) delay_ms = try std.fmt.parseUnsigned(u64, t, constants.DECIMAL_BASE);
        }
    }

    // Persist full config so future runs do not prompt
    config.writeConfig(rows, cols, gens, delay_ms) catch {};

    // Calculate layout and adjust grid size to fit terminal
    render.calculateLayout(&rows, &cols);

    // Allocate grids
    const count = rows * cols;
    var grid = try allocator.alloc(u8, count);
    defer allocator.free(grid);
    var next = try allocator.alloc(u8, count);
    defer allocator.free(next);

    // Initialize with random pattern
    var prng = std.Random.DefaultPrng.init(@as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))));
    const rand = prng.random();
    game.initializeRandomGrid(grid, constants.DEFAULT_INITIAL_DENSITY, rand);

    // Clear screen and start simulation
    try render.clearScreen();

    var gen: usize = 0;
    while (gens == constants.INFINITE_GENERATIONS or gen < gens) : (gen += 1) {
        // Render current generation
        try render.renderFrame(grid, rows, cols, gen);

        // Compute next generation
        game.stepGrid(grid, rows, cols, next);

        // Swap buffers
        const tmp = grid;
        grid = next;
        next = tmp;

        std.Thread.sleep(delay_ms * std.time.ns_per_ms);
    }
}
