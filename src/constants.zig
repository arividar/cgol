const std = @import("std");

/// Game of Life Configuration Constants
/// This module centralizes all configurable values that were previously scattered throughout the codebase

// === Default Game Parameters ===
pub const DEFAULT_ROWS: usize = 40;
pub const DEFAULT_COLS: usize = 60;
pub const DEFAULT_GENERATIONS: u64 = 100;
pub const DEFAULT_DELAY_MS: u64 = 100;
pub const DEFAULT_INITIAL_DENSITY: f64 = 0.35;

// === Terminal and Display Constants ===
pub const DEFAULT_TERM_ROWS: usize = 25;
pub const DEFAULT_TERM_COLS: usize = 80;
pub const FRAME_OVERHEAD_ROWS: usize = 3; // top frame + bottom frame + status line
pub const FRAME_OVERHEAD_COLS: usize = 4; // left frame + right frame + padding
pub const CELL_WIDTH_CHARS: usize = 2; // Each cell is 2 characters wide
pub const MIN_GRID_SIZE: usize = 1; // Minimum grid dimension

// === Buffer and Memory Constants ===
pub const CONFIG_FILE_MAX_SIZE: usize = 64 * 1024; // 64KB max config file size
pub const CONFIG_WRITE_BUFFER_SIZE: usize = 256;
pub const PRINT_BUFFER_SIZE: usize = 4096;
pub const INPUT_BUFFER_SIZE: usize = 1024;
pub const INPUT_LINE_MAX_SIZE: usize = 256;
pub const CLI_MAX_POSITIONAL_ARGS: usize = 4;

// === File and Configuration Constants ===
pub const CONFIG_FILENAME: []const u8 = "cgol.toml";
pub const CONFIG_COMMENT: []const u8 = "# Game of Life config";

// === Terminal Control Sequences ===
pub const ANSI_HIDE_CURSOR: []const u8 = "\x1b[?25l";
pub const ANSI_SHOW_CURSOR: []const u8 = "\x1b[?25h";
pub const ANSI_RESET_TERMINAL: []const u8 = "\x1b[0m\n";
pub const ANSI_CLEAR_SCREEN: []const u8 = "\x1b[2J";
pub const ANSI_CLEAR_LINE: []const u8 = "\x1b[2K";
pub const ANSI_RESET_COLOR: []const u8 = "\x1b[0m";
pub const ANSI_LIVE_CELL_COLOR: []const u8 = "\x1b[38;5;46m"; // Bright green

// === Unicode Box Drawing Characters ===
pub const BOX_TOP_LEFT: []const u8 = "\u{250C}";
pub const BOX_TOP_RIGHT: []const u8 = "\u{2510}";
pub const BOX_BOTTOM_LEFT: []const u8 = "\u{2514}";
pub const BOX_BOTTOM_RIGHT: []const u8 = "\u{2518}";
pub const BOX_HORIZONTAL: []const u8 = "\u{2500}";
pub const BOX_VERTICAL: []const u8 = "\u{2502}";
pub const LIVE_CELL_CHAR: []const u8 = "\u{2588}\u{2588}"; // Double block character
pub const DEAD_CELL_CHAR: []const u8 = "  "; // Two spaces

// === Game Logic Constants ===
pub const CELL_ALIVE: u8 = 1;
pub const CELL_DEAD: u8 = 0;
pub const NEIGHBOR_SURVIVE_MIN: u8 = 2; // Minimum neighbors for survival
pub const NEIGHBOR_SURVIVE_MAX: u8 = 3; // Maximum neighbors for survival
pub const NEIGHBOR_BIRTH: u8 = 3; // Neighbors needed for birth

// === File Descriptors ===
pub const STDOUT_FD: std.posix.fd_t = 1;
pub const STDIN_FD: std.posix.fd_t = 0;

// === Parsing and Validation Constants ===
pub const DECIMAL_BASE: u8 = 10;
pub const INFINITE_GENERATIONS: u64 = 0; // Special value meaning infinite

// === Prompt Messages ===
pub const PROMPT_ROWS_COLS: []const u8 = "Enter rows and cols (e.g., 25 60) [default {d} {d}]: ";
pub const PROMPT_GENERATIONS: []const u8 = "Generations to run (0 = infinite, default={d}): ";
pub const PROMPT_DELAY: []const u8 = "Delay per generation in ms [default {d}]: ";
pub const STATUS_MESSAGE: []const u8 = "Gen: {d}  (Ctrl+C to quit)";

// === Help Text ===
pub const HELP_TEXT: []const u8 =
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
    "  Reads/writes cgol.toml at repo root. Missing/partial values prompt.\n";

// === Configuration Keys ===
pub const CONFIG_KEY_ROWS: []const u8 = "rows";
pub const CONFIG_KEY_COLS: []const u8 = "cols";
pub const CONFIG_KEY_GENERATIONS: []const u8 = "generations";
pub const CONFIG_KEY_DELAY_MS: []const u8 = "delay_ms";

// === Whitespace Characters ===
pub const WHITESPACE_CHARS: []const u8 = " \t\r\n";
pub const TRIM_CHARS: []const u8 = " \t\r";
pub const COMMENT_CHAR: u8 = '#';
pub const EQUALS_CHAR: u8 = '=';
pub const NEWLINE_CHAR: u8 = '\n';
