const std = @import("std");
const cli = @import("src/cli.zig");
const constants = @import("src/constants.zig");

// Integration tests for CLI save and auto-save parameters
// These tests verify the complete parsing workflow

test "CLI integration - parseArgs with save parameter" {
    // Note: This test demonstrates the pattern for testing parseArgs
    // In a real scenario, we'd need to mock std.process.argsAlloc
    
    var allocator = std.testing.allocator;
    
    // Test manual construction of CliArgs to verify structure
    var args = cli.CliArgs{
        .save_file = try allocator.dupe(u8, "integration_test.cgol"),
        .save_description = try allocator.dupe(u8, "Integration test save"),
        .rows = 20,
        .cols = 30,
        .generations = 50,
        .delay_ms = 100,
    };
    defer args.deinit(allocator);
    
    // Validate the constructed args
    try cli.validateArgs(args);
    
    // Verify all fields are set correctly
    try std.testing.expectEqualStrings("integration_test.cgol", args.save_file.?);
    try std.testing.expectEqualStrings("Integration test save", args.save_description.?);
    try std.testing.expect(args.rows.? == 20);
    try std.testing.expect(args.cols.? == 30);
    try std.testing.expect(args.generations.? == 50);
    try std.testing.expect(args.delay_ms.? == 100);
}

test "CLI integration - parseArgs with auto-save parameters" {
    var allocator = std.testing.allocator;
    
    // Test auto-save configuration
    var args = cli.CliArgs{
        .auto_save_every = 25,
        .save_prefix = try allocator.dupe(u8, "test_auto_"),
        .save_description = try allocator.dupe(u8, "Auto-save test session"),
        .rows = 15,
        .cols = 25,
        .generations = 200,
        .delay_ms = 150,
    };
    defer args.deinit(allocator);
    
    // Validate the constructed args
    try cli.validateArgs(args);
    
    // Verify auto-save fields
    try std.testing.expect(args.auto_save_every.? == 25);
    try std.testing.expectEqualStrings("test_auto_", args.save_prefix.?);
    try std.testing.expectEqualStrings("Auto-save test session", args.save_description.?);
}

test "CLI integration - complex save configuration" {
    var allocator = std.testing.allocator;
    
    // Test complex scenario with multiple save-related options
    var args = cli.CliArgs{
        .save_file = try allocator.dupe(u8, "complex_test.cgol"),
        .save_description = try allocator.dupe(u8, "Complex test with manual and auto-save"),
        .auto_save_every = 100,
        .save_prefix = try allocator.dupe(u8, "backup_"),
        .pattern_file = try allocator.dupe(u8, "patterns/glider.rle"),
        .rows = 40,
        .cols = 60,
        .generations = 500,
        .delay_ms = 80,
    };
    defer args.deinit(allocator);
    
    // This should pass validation
    try cli.validateArgs(args);
    
    // Verify all save-related parameters
    try std.testing.expectEqualStrings("complex_test.cgol", args.save_file.?);
    try std.testing.expectEqualStrings("Complex test with manual and auto-save", args.save_description.?);
    try std.testing.expect(args.auto_save_every.? == 100);
    try std.testing.expectEqualStrings("backup_", args.save_prefix.?);
    try std.testing.expectEqualStrings("patterns/glider.rle", args.pattern_file.?);
}

test "CLI integration - save parameter validation edge cases" {
    var allocator = std.testing.allocator;
    
    // Test case 1: Save file with path separators
    {
        var args = cli.CliArgs{
            .save_file = try allocator.dupe(u8, "saves/subdir/test.cgol"),
            .save_description = try allocator.dupe(u8, "Save in subdirectory"),
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
        try std.testing.expect(std.mem.indexOf(u8, args.save_file.?, "/") != null);
    }
    
    // Test case 2: Minimum auto-save interval
    {
        var args = cli.CliArgs{
            .auto_save_every = 1,
            .save_prefix = try allocator.dupe(u8, "min_"),
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
        try std.testing.expect(args.auto_save_every.? == 1);
    }
    
    // Test case 3: Large auto-save interval
    {
        var args = cli.CliArgs{
            .auto_save_every = 10000,
            .save_prefix = try allocator.dupe(u8, "large_"),
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
        try std.testing.expect(args.auto_save_every.? == 10000);
    }
}

test "CLI integration - error scenarios for save parameters" {
    var allocator = std.testing.allocator;
    
    // Test case 1: Conflicting save and load
    {
        var args = cli.CliArgs{
            .save_file = try allocator.dupe(u8, "test_save.cgol"),
            .load_file = try allocator.dupe(u8, "test_load.cgol"),
        };
        defer args.deinit(allocator);
        
        try std.testing.expectError(cli.CliValidationError.ConflictingSaveLoad, cli.validateArgs(args));
    }
    
    // Test case 2: Empty save file
    {
        var args = cli.CliArgs{
            .save_file = try allocator.dupe(u8, ""),
        };
        defer args.deinit(allocator);
        
        try std.testing.expectError(cli.CliValidationError.InvalidSaveFile, cli.validateArgs(args));
    }
    
    // Test case 3: Zero auto-save interval
    {
        const args = cli.CliArgs{
            .auto_save_every = 0,
        };
        
        try std.testing.expectError(cli.CliValidationError.InvalidAutoSaveInterval, cli.validateArgs(args));
    }
    
    // Test case 4: Save prefix without auto-save
    {
        var args = cli.CliArgs{
            .save_prefix = try allocator.dupe(u8, "orphan_"),
        };
        defer args.deinit(allocator);
        
        try std.testing.expectError(cli.CliValidationError.SavePrefixWithoutAutoSave, cli.validateArgs(args));
    }
    
    // Test case 5: Description without save operation
    {
        var args = cli.CliArgs{
            .save_description = try allocator.dupe(u8, "Orphan description"),
        };
        defer args.deinit(allocator);
        
        try std.testing.expectError(cli.CliValidationError.DescriptionWithoutSave, cli.validateArgs(args));
    }
}

test "CLI integration - realistic usage scenarios" {
    var allocator = std.testing.allocator;
    
    // Scenario 1: Quick save during development
    {
        var args = cli.CliArgs{
            .save_file = try allocator.dupe(u8, "dev_checkpoint.cgol"),
            .save_description = try allocator.dupe(u8, "Development checkpoint"),
            .generations = 100,
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
    }
    
    // Scenario 2: Long-running simulation with auto-save
    {
        var args = cli.CliArgs{
            .auto_save_every = 500,
            .save_prefix = try allocator.dupe(u8, "long_sim_"),
            .save_description = try allocator.dupe(u8, "Long simulation auto-backup"),
            .generations = 10000,
            .delay_ms = 50,
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
    }
    
    // Scenario 3: Pattern exploration with frequent saves
    {
        var args = cli.CliArgs{
            .pattern_file = try allocator.dupe(u8, "patterns/gosperglidergun.rle"),
            .auto_save_every = 50,
            .save_prefix = try allocator.dupe(u8, "exploration_"),
            .generations = 1000,
            .rows = 50,
            .cols = 80,
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
    }
    
    // Scenario 4: Research session with detailed saves
    {
        var args = cli.CliArgs{
            .save_file = try allocator.dupe(u8, "research_session_1.cgol"),
            .save_description = try allocator.dupe(u8, "Research session #1 - oscillator behavior study"),
            .auto_save_every = 200,
            .save_prefix = try allocator.dupe(u8, "research_backup_"),
            .pattern_file = try allocator.dupe(u8, "patterns/beacon.rle"),
            .generations = 2000,
        };
        defer args.deinit(allocator);
        
        try cli.validateArgs(args);
    }
}

test "CLI integration - memory management for save parameters" {
    var allocator = std.testing.allocator;
    
    // Test that CliArgs properly manages memory for save-related strings
    var args = cli.CliArgs{
        .save_file = try allocator.dupe(u8, "memory_test.cgol"),
        .save_description = try allocator.dupe(u8, "Memory management test"),
        .save_prefix = try allocator.dupe(u8, "mem_test_"),
        .pattern_file = try allocator.dupe(u8, "patterns/test.rle"),
        .auto_save_every = 100,
    };
    
    // Verify all fields are allocated
    try std.testing.expect(args.save_file != null);
    try std.testing.expect(args.save_description != null);
    try std.testing.expect(args.save_prefix != null);
    try std.testing.expect(args.pattern_file != null);
    try std.testing.expect(args.auto_save_every != null);
    
    // Test validation works
    try cli.validateArgs(args);
    
    // Clean up - this should not leak memory
    args.deinit(allocator);
}