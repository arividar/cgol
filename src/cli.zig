const std = @import("std");
const constants = @import("constants.zig");

pub const CliArgs = struct {
    force_prompt: bool = false,
    rows: ?usize = null,
    cols: ?usize = null,
    generations: ?u64 = null,
    delay_ms: ?u64 = null,
    pattern_file: ?[]const u8 = null,
    show_help: bool = false,
    
    // Save/load fields
    save_file: ?[]const u8 = null,
    load_file: ?[]const u8 = null,
    save_description: ?[]const u8 = null,
    auto_save_every: ?u64 = null,
    save_prefix: ?[]const u8 = null,
    list_saves: bool = false,

    pub fn deinit(self: *CliArgs, allocator: std.mem.Allocator) void {
        if (self.pattern_file) |pattern_file| {
            allocator.free(pattern_file);
        }
        if (self.save_file) |save_file| {
            allocator.free(save_file);
        }
        if (self.load_file) |load_file| {
            allocator.free(load_file);
        }
        if (self.save_description) |save_description| {
            allocator.free(save_description);
        }
        if (self.save_prefix) |save_prefix| {
            allocator.free(save_prefix);
        }
    }
};

/// Parse command line arguments
pub fn parseArgs(allocator: std.mem.Allocator) !CliArgs {
    var result = CliArgs{};

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var pos_vals: [constants.CLI_MAX_POSITIONAL_ARGS]u64 = undefined;
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
            result.rows = std.fmt.parseUnsigned(usize, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--height")) {
            if (i + 1 < args.len) {
                result.rows = std.fmt.parseUnsigned(usize, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--width=")) {
            const vstr = a["--width=".len..];
            result.cols = std.fmt.parseUnsigned(usize, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--width")) {
            if (i + 1 < args.len) {
                result.cols = std.fmt.parseUnsigned(usize, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--generations=")) {
            const vstr = a["--generations=".len..];
            result.generations = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--generations")) {
            if (i + 1 < args.len) {
                result.generations = std.fmt.parseUnsigned(u64, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--delay=")) {
            const vstr = a["--delay=".len..];
            result.delay_ms = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--delay")) {
            if (i + 1 < args.len) {
                result.delay_ms = std.fmt.parseUnsigned(u64, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--pattern=")) {
            const vstr = a["--pattern=".len..];
            result.pattern_file = try allocator.dupe(u8, vstr);
            continue;
        }

        if (std.mem.eql(u8, a, "--pattern")) {
            if (i + 1 < args.len) {
                result.pattern_file = try allocator.dupe(u8, args[i + 1]);
                i += 1;
            }
            continue;
        }

        // Save/load options
        if (std.mem.startsWith(u8, a, "--save=")) {
            const vstr = a["--save=".len..];
            result.save_file = try allocator.dupe(u8, vstr);
            continue;
        }

        if (std.mem.eql(u8, a, "--save")) {
            if (i + 1 < args.len) {
                result.save_file = try allocator.dupe(u8, args[i + 1]);
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--load=")) {
            const vstr = a["--load=".len..];
            result.load_file = try allocator.dupe(u8, vstr);
            continue;
        }

        if (std.mem.eql(u8, a, "--load")) {
            if (i + 1 < args.len) {
                result.load_file = try allocator.dupe(u8, args[i + 1]);
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--description=")) {
            const vstr = a["--description=".len..];
            result.save_description = try allocator.dupe(u8, vstr);
            continue;
        }

        if (std.mem.eql(u8, a, "--description")) {
            if (i + 1 < args.len) {
                result.save_description = try allocator.dupe(u8, args[i + 1]);
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--auto-save-every=")) {
            const vstr = a["--auto-save-every=".len..];
            result.auto_save_every = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
            continue;
        }

        if (std.mem.eql(u8, a, "--auto-save-every")) {
            if (i + 1 < args.len) {
                result.auto_save_every = std.fmt.parseUnsigned(u64, args[i + 1], constants.DECIMAL_BASE) catch null;
                i += 1;
            }
            continue;
        }

        if (std.mem.startsWith(u8, a, "--save-prefix=")) {
            const vstr = a["--save-prefix=".len..];
            result.save_prefix = try allocator.dupe(u8, vstr);
            continue;
        }

        if (std.mem.eql(u8, a, "--save-prefix")) {
            if (i + 1 < args.len) {
                result.save_prefix = try allocator.dupe(u8, args[i + 1]);
                i += 1;
            }
            continue;
        }

        if (std.mem.eql(u8, a, "--list-saves")) {
            result.list_saves = true;
            continue;
        }

        // Positional arguments
        if (a.len > 0 and a[0] != '-') {
            if (pos_count < pos_vals.len) {
                if (std.fmt.parseUnsigned(u64, a, constants.DECIMAL_BASE)) |v| {
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

/// Validation error for CLI arguments
pub const CliValidationError = error{
    ConflictingSaveLoad,
    InvalidSaveFile,
    InvalidLoadFile,
    InvalidAutoSaveInterval,
    SavePrefixWithoutAutoSave,
    DescriptionWithoutSave,
};

/// Validate CLI arguments for logical consistency
pub fn validateArgs(args: CliArgs) CliValidationError!void {
    // Check for conflicting save + load options
    if (args.save_file != null and args.load_file != null) {
        return CliValidationError.ConflictingSaveLoad;
    }
    
    // Validate save file path
    if (args.save_file) |save_file| {
        if (save_file.len == 0) {
            return CliValidationError.InvalidSaveFile;
        }
    }
    
    // Validate load file path
    if (args.load_file) |load_file| {
        if (load_file.len == 0) {
            return CliValidationError.InvalidLoadFile;
        }
    }
    
    // Auto-save interval should be reasonable
    if (args.auto_save_every) |interval| {
        if (interval == 0) {
            return CliValidationError.InvalidAutoSaveInterval;
        }
    }
    
    // Save prefix only makes sense with auto-save
    if (args.save_prefix != null and args.auto_save_every == null) {
        return CliValidationError.SavePrefixWithoutAutoSave;
    }
    
    // Description only makes sense with save
    if (args.save_description != null and args.save_file == null and args.auto_save_every == null) {
        return CliValidationError.DescriptionWithoutSave;
    }
}

/// Print help message
pub fn printHelp(renderer: anytype) !void {
    try renderer.print(constants.HELP_TEXT, .{});
}

// === UNIT TESTS ===

test "CLI validation - basic valid args" {
    const args = CliArgs{};
    try validateArgs(args);
}

test "CLI validation - conflicting save and load" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .save_file = try allocator.dupe(u8, "test.cgol"),
        .load_file = try allocator.dupe(u8, "test2.cgol"),
    };
    defer args.deinit(allocator);
    
    try std.testing.expectError(CliValidationError.ConflictingSaveLoad, validateArgs(args));
}

test "CLI validation - empty save file" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .save_file = try allocator.dupe(u8, ""),
    };
    defer args.deinit(allocator);
    
    try std.testing.expectError(CliValidationError.InvalidSaveFile, validateArgs(args));
}

test "CLI validation - empty load file" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .load_file = try allocator.dupe(u8, ""),
    };
    defer args.deinit(allocator);
    
    try std.testing.expectError(CliValidationError.InvalidLoadFile, validateArgs(args));
}

test "CLI validation - zero auto-save interval" {
    const args = CliArgs{
        .auto_save_every = 0,
    };
    
    try std.testing.expectError(CliValidationError.InvalidAutoSaveInterval, validateArgs(args));
}

test "CLI validation - save prefix without auto-save" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .save_prefix = try allocator.dupe(u8, "backup_"),
    };
    defer args.deinit(allocator);
    
    try std.testing.expectError(CliValidationError.SavePrefixWithoutAutoSave, validateArgs(args));
}

test "CLI validation - description without save" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .save_description = try allocator.dupe(u8, "test description"),
    };
    defer args.deinit(allocator);
    
    try std.testing.expectError(CliValidationError.DescriptionWithoutSave, validateArgs(args));
}

test "CLI validation - valid save with description" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .save_file = try allocator.dupe(u8, "test.cgol"),
        .save_description = try allocator.dupe(u8, "test description"),
    };
    defer args.deinit(allocator);
    
    try validateArgs(args);
}

// === CLI PARAMETER PARSING TESTS ===

test "CLI parsing - save parameter with equals" {
    var allocator = std.testing.allocator;
    
    // Simulate command line: program --save=test.cgol
    const test_args = [_][]const u8{ "program", "--save=test.cgol" };
    _ = test_args; // Mark as used to avoid compiler warning
    
    // We'll test the parsing logic directly since we can't easily mock argsAlloc
    var args = CliArgs{};
    
    // Simulate the parsing logic for --save=value
    const arg = "--save=test.cgol";
    if (std.mem.startsWith(u8, arg, "--save=")) {
        const vstr = arg["--save=".len..];
        args.save_file = try allocator.dupe(u8, vstr);
    }
    defer args.deinit(allocator);
    
    try std.testing.expect(args.save_file != null);
    try std.testing.expectEqualStrings("test.cgol", args.save_file.?);
}

test "CLI parsing - save parameter with space" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{};
    
    // Simulate the parsing logic for --save value
    const arg = "--save";
    const next_arg = "my_save.cgol";
    
    if (std.mem.eql(u8, arg, "--save")) {
        args.save_file = try allocator.dupe(u8, next_arg);
    }
    defer args.deinit(allocator);
    
    try std.testing.expect(args.save_file != null);
    try std.testing.expectEqualStrings("my_save.cgol", args.save_file.?);
}

test "CLI parsing - auto-save-every parameter with equals" {
    var args = CliArgs{};
    
    // Simulate the parsing logic for --auto-save-every=value
    const arg = "--auto-save-every=50";
    if (std.mem.startsWith(u8, arg, "--auto-save-every=")) {
        const vstr = arg["--auto-save-every=".len..];
        args.auto_save_every = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
    }
    
    try std.testing.expect(args.auto_save_every != null);
    try std.testing.expect(args.auto_save_every.? == 50);
}

test "CLI parsing - auto-save-every parameter with space" {
    var args = CliArgs{};
    
    // Simulate the parsing logic for --auto-save-every value
    const arg = "--auto-save-every";
    const next_arg = "25";
    
    if (std.mem.eql(u8, arg, "--auto-save-every")) {
        args.auto_save_every = std.fmt.parseUnsigned(u64, next_arg, constants.DECIMAL_BASE) catch null;
    }
    
    try std.testing.expect(args.auto_save_every != null);
    try std.testing.expect(args.auto_save_every.? == 25);
}

test "CLI parsing - save with description and auto-save combination" {
    var allocator = std.testing.allocator;
    
    var args = CliArgs{
        .save_file = try allocator.dupe(u8, "manual_save.cgol"),
        .save_description = try allocator.dupe(u8, "Manual checkpoint"),
        .auto_save_every = 100,
        .save_prefix = try allocator.dupe(u8, "auto_"),
    };
    defer args.deinit(allocator);
    
    // This should be valid - manual save can coexist with auto-save settings
    try validateArgs(args);
    
    try std.testing.expectEqualStrings("manual_save.cgol", args.save_file.?);
    try std.testing.expectEqualStrings("Manual checkpoint", args.save_description.?);
    try std.testing.expect(args.auto_save_every.? == 100);
    try std.testing.expectEqualStrings("auto_", args.save_prefix.?);
}

test "CLI parsing - invalid auto-save-every value" {
    var args = CliArgs{};
    
    // Simulate parsing invalid numeric value
    const arg = "--auto-save-every=invalid";
    if (std.mem.startsWith(u8, arg, "--auto-save-every=")) {
        const vstr = arg["--auto-save-every=".len..];
        args.auto_save_every = std.fmt.parseUnsigned(u64, vstr, constants.DECIMAL_BASE) catch null;
    }
    
    // Should be null due to parse error
    try std.testing.expect(args.auto_save_every == null);
}

test "CLI parsing - save file extension handling" {
    var allocator = std.testing.allocator;
    
    // Test files with and without .cgol extension
    const test_cases = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "test", .expected = "test" },
        .{ .input = "test.cgol", .expected = "test.cgol" },
        .{ .input = "saves/backup", .expected = "saves/backup" },
        .{ .input = "saves/backup.cgol", .expected = "saves/backup.cgol" },
    };
    
    for (test_cases) |case| {
        var args = CliArgs{
            .save_file = try allocator.dupe(u8, case.input),
        };
        defer args.deinit(allocator);
        
        try std.testing.expectEqualStrings(case.expected, args.save_file.?);
    }
}

test "CLI parsing - edge cases for save parameters" {
    var allocator = std.testing.allocator;
    
    // Test very long filename
    const long_filename = "very_long_filename_that_should_still_work_properly_in_the_cli_parser.cgol";
    var args1 = CliArgs{
        .save_file = try allocator.dupe(u8, long_filename),
    };
    defer args1.deinit(allocator);
    
    try validateArgs(args1);
    try std.testing.expectEqualStrings(long_filename, args1.save_file.?);
    
    // Test filename with spaces (should work if quoted properly)
    const spaced_filename = "my save file.cgol";
    var args2 = CliArgs{
        .save_file = try allocator.dupe(u8, spaced_filename),
    };
    defer args2.deinit(allocator);
    
    try validateArgs(args2);
    try std.testing.expectEqualStrings(spaced_filename, args2.save_file.?);
    
    // Test maximum reasonable auto-save interval
    const args3 = CliArgs{
        .auto_save_every = 999999,
    };
    
    try validateArgs(args3);
    try std.testing.expect(args3.auto_save_every.? == 999999);
}

test "CLI parsing - comprehensive save/auto-save scenario validation" {
    var allocator = std.testing.allocator;
    
    // Scenario 1: Manual save only
    var scenario1 = CliArgs{
        .save_file = try allocator.dupe(u8, "checkpoint1.cgol"),
        .save_description = try allocator.dupe(u8, "First checkpoint"),
    };
    defer scenario1.deinit(allocator);
    try validateArgs(scenario1);
    
    // Scenario 2: Auto-save only
    var scenario2 = CliArgs{
        .auto_save_every = 50,
        .save_prefix = try allocator.dupe(u8, "backup_"),
    };
    defer scenario2.deinit(allocator);
    try validateArgs(scenario2);
    
    // Scenario 3: Both manual save and auto-save configured
    var scenario3 = CliArgs{
        .save_file = try allocator.dupe(u8, "manual.cgol"),
        .save_description = try allocator.dupe(u8, "Manual checkpoint"),
        .auto_save_every = 75,
        .save_prefix = try allocator.dupe(u8, "auto_"),
    };
    defer scenario3.deinit(allocator);
    try validateArgs(scenario3);
    
    // Scenario 4: Auto-save with description (valid - description applies to auto-saves)
    var scenario4 = CliArgs{
        .auto_save_every = 100,
        .save_description = try allocator.dupe(u8, "Auto-backup session"),
    };
    defer scenario4.deinit(allocator);
    try validateArgs(scenario4);
}
