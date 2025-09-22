const std = @import("std");
const constants = @import("constants.zig");

/// Simple input reader for terminal
pub const InputReader = struct {
    stdin: std.fs.File,
    input_buffer: [constants.INPUT_BUFFER_SIZE]u8 = undefined,
    buffer_pos: usize = 0,
    buffer_end: usize = 0,

    pub fn init() InputReader {
        return InputReader{
            .stdin = std.fs.File{ .handle = constants.STDIN_FD },
        };
    }

    /// Read a line from stdin
    pub fn readLine(self: *InputReader, alloc: std.mem.Allocator) !?[]u8 {
        var line: [constants.INPUT_LINE_MAX_SIZE]u8 = undefined;
        var line_pos: usize = 0;

        while (line_pos < line.len - 1) {
            // Refill buffer if empty
            if (self.buffer_pos >= self.buffer_end) {
                self.buffer_end = try self.stdin.read(self.input_buffer[0..]);
                self.buffer_pos = 0;
                if (self.buffer_end == 0) {
                    if (line_pos == 0) return null;
                    break;
                }
            }

            const char = self.input_buffer[self.buffer_pos];
            self.buffer_pos += 1;

            if (char == '\n') break;
            line[line_pos] = char;
            line_pos += 1;
        }

        return try alloc.dupe(u8, std.mem.trim(u8, line[0..line_pos], constants.WHITESPACE_CHARS));
    }
};
