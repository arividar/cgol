const std = @import("std");
const game = @import("game.zig");
const config = @import("config.zig");
const renderer = @import("renderer.zig");
const cli = @import("cli.zig");
const input = @import("input.zig");
const constants = @import("constants.zig");

/// Configuration parameters for the game
const GameConfig = struct {
    rows: usize,
    cols: usize,
    generations: u64,
    delay_ms: u64,
};

/// Game state containing grids and simulation data
const GameState = struct {
    grid: []u8,
    next: []u8,
    rows: usize,
    cols: usize,
    generations: u64,
    delay_ms: u64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GameState) void {
        self.allocator.free(self.grid);
        self.allocator.free(self.next);
    }
};

/// Handle early exit conditions (help, etc.)
fn handleEarlyExit(args: cli.CliArgs, render: *renderer.Renderer) !bool {
    if (args.show_help) {
        try cli.printHelp(render);
        return true;
    }
    return false;
}

/// Prompt user for grid dimensions if needed
fn promptForGridDimensions(
    args: cli.CliArgs,
    cfg: config.ConfigPartial,
    render: *renderer.Renderer,
    input_reader: *input.InputReader,
    alloc: std.mem.Allocator,
) !struct { rows: usize, cols: usize } {
    var rows: usize = args.rows orelse (cfg.rows orelse constants.DEFAULT_ROWS);
    var cols: usize = args.cols orelse (cfg.cols orelse constants.DEFAULT_COLS);

    const have_rows = (args.rows != null) or (cfg.rows != null);
    const have_cols = (args.cols != null) or (cfg.cols != null);
    const need_prompt_rows_cols = (args.force_prompt and !(args.rows != null and args.cols != null)) or (!have_rows or !have_cols);

    if (need_prompt_rows_cols) {
        try render.print(constants.PROMPT_ROWS_COLS, .{ rows, cols });
        const line_opt = try input_reader.readLine(alloc);
        if (line_opt) |line_raw| {
            const line = std.mem.trim(u8, line_raw, constants.WHITESPACE_CHARS);
            if (line.len != 0) {
                var it = std.mem.tokenizeAny(u8, line, constants.TRIM_CHARS);
                if (it.next()) |rows_s| rows = try std.fmt.parseUnsigned(usize, rows_s, constants.DECIMAL_BASE);
                if (it.next()) |cols_s| cols = try std.fmt.parseUnsigned(usize, cols_s, constants.DECIMAL_BASE);
            }
        }
    }

    return .{ .rows = rows, .cols = cols };
}

/// Prompt user for number of generations if needed
fn promptForGenerations(
    args: cli.CliArgs,
    cfg: config.ConfigPartial,
    render: *renderer.Renderer,
    input_reader: *input.InputReader,
    alloc: std.mem.Allocator,
) !u64 {
    var gens: u64 = args.generations orelse (cfg.generations orelse constants.DEFAULT_GENERATIONS);

    if ((args.force_prompt and args.generations == null) or (cfg.generations == null and args.generations == null)) {
        try render.print(constants.PROMPT_GENERATIONS, .{gens});
        const line_opt = try input_reader.readLine(alloc);
        if (line_opt) |line| {
            const trimmed = std.mem.trim(u8, line, constants.WHITESPACE_CHARS);
            if (trimmed.len != 0) gens = try std.fmt.parseUnsigned(u64, trimmed, constants.DECIMAL_BASE);
        }
    }

    return gens;
}

/// Prompt user for delay between generations if needed
fn promptForDelay(
    args: cli.CliArgs,
    cfg: config.ConfigPartial,
    render: *renderer.Renderer,
    input_reader: *input.InputReader,
    alloc: std.mem.Allocator,
) !u64 {
    var delay_ms: u64 = args.delay_ms orelse (cfg.delay_ms orelse constants.DEFAULT_DELAY_MS);

    if ((args.force_prompt and args.delay_ms == null) or (cfg.delay_ms == null and args.delay_ms == null)) {
        try render.print(constants.PROMPT_DELAY, .{delay_ms});
        const line_opt = try input_reader.readLine(alloc);
        if (line_opt) |line| {
            const trimmed = std.mem.trim(u8, line, constants.WHITESPACE_CHARS);
            if (trimmed.len != 0) delay_ms = try std.fmt.parseUnsigned(u64, trimmed, constants.DECIMAL_BASE);
        }
    }

    return delay_ms;
}

/// Gather all configuration from CLI args, config file, and user prompts
fn gatherConfiguration(
    args: cli.CliArgs,
    render: *renderer.Renderer,
    alloc: std.mem.Allocator,
) !GameConfig {
    // Load configuration from file
    const cfg = if (args.force_prompt) config.ConfigPartial{} else config.loadConfig(alloc);

    // Initialize input reader for prompts
    var input_reader = input.InputReader.init();

    // Get grid dimensions
    const dimensions = try promptForGridDimensions(args, cfg, render, &input_reader, alloc);

    // Get generations count
    const generations = try promptForGenerations(args, cfg, render, &input_reader, alloc);

    // Get delay
    const delay_ms = try promptForDelay(args, cfg, render, &input_reader, alloc);

    return GameConfig{
        .rows = dimensions.rows,
        .cols = dimensions.cols,
        .generations = generations,
        .delay_ms = delay_ms,
    };
}

/// Initialize the game state with allocated grids and random pattern
fn initializeGameState(
    game_config: GameConfig,
    render: *renderer.Renderer,
    allocator: std.mem.Allocator,
) !GameState {
    // Adjust grid size to fit terminal
    var rows = game_config.rows;
    var cols = game_config.cols;
    render.calculateLayout(&rows, &cols);

    // Allocate grids
    const count = rows * cols;
    const grid = try allocator.alloc(u8, count);
    errdefer allocator.free(grid);
    const next = try allocator.alloc(u8, count);
    errdefer allocator.free(next);

    // Initialize with random pattern
    var prng = std.Random.DefaultPrng.init(@as(u64, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))));
    const rand = prng.random();
    game.initializeRandomGrid(grid, constants.DEFAULT_INITIAL_DENSITY, rand);

    return GameState{
        .grid = grid,
        .next = next,
        .rows = rows,
        .cols = cols,
        .generations = game_config.generations,
        .delay_ms = game_config.delay_ms,
        .allocator = allocator,
    };
}

/// Run the main simulation loop
fn runSimulation(game_state: *GameState, render: *renderer.Renderer) !void {
    try render.clearScreen();

    var gen: usize = 0;
    while (game_state.generations == constants.INFINITE_GENERATIONS or gen < game_state.generations) : (gen += 1) {
        // Render current generation
        try render.renderFrame(game_state.grid, game_state.rows, game_state.cols, gen);

        // Compute next generation
        game.stepGrid(game_state.grid, game_state.rows, game_state.cols, game_state.next);

        // Swap buffers
        const tmp = game_state.grid;
        game_state.grid = game_state.next;
        game_state.next = tmp;

        std.Thread.sleep(game_state.delay_ms * std.time.ns_per_ms);
    }
}

/// Main entry point - orchestrates the entire application flow
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    const args = try cli.parseArgs(allocator);

    // Initialize renderer
    var render = renderer.Renderer.init();

    // Handle early exit conditions (help, etc.)
    if (try handleEarlyExit(args, &render)) {
        return;
    }

    // Setup terminal (hide cursor, restore on exit)
    try render.hideCursor();
    defer render.showCursor() catch {};

    // Setup arena allocator for temporary allocations
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Gather all configuration (CLI, file, prompts)
    const game_config = try gatherConfiguration(args, &render, alloc);

    // Persist configuration for future runs
    config.writeConfig(game_config.rows, game_config.cols, game_config.generations, game_config.delay_ms) catch {};

    // Initialize game state with grids and random pattern
    var game_state = try initializeGameState(game_config, &render, allocator);
    defer game_state.deinit();

    // Run the main simulation loop
    try runSimulation(&game_state, &render);
}
