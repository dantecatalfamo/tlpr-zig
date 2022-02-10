const std = @import("std");
const Printer = @import("printer.zig").Printer;

pub fn wrappedPrint(allocator: std.mem.Allocator, line: []const u8, width: u8, printer: Printer) !void {
    var line_dupe = try allocator.dupe(u8, line);
    defer allocator.free(line_dupe);
    wordWrap(line_dupe, width);
    try printer.writeAll(line_dupe);
}

pub fn wordWrap(line: []u8, width: u8) void {
    var last_space: usize = 0;
    var last_newline: usize = 0;

    for (line) |char, idx| {
        const cur_line = idx - last_newline;
        if (std.ascii.isSpace(char)) {
            last_space = idx;
        }
        if (char == '\n') {
            last_newline = idx;
        }
        if (cur_line == width-2) {
            last_newline = idx;
            line[last_space] = '\n';
        }
    }
}

pub fn WrappingPrinter(printer: Printer, wrap_length: usize, max_line: usize) type {
    return struct {
        wrap_length: u8 = wrap_length,
        index: usize = 0,
        last_newline: usize = 0,
        last_space: usize = 0,
        buffer: [max_line]u8,
        printer: Printer = printer,

        const Self = @This();

        pub fn write(self: *Self, line: []const u8) !usize {
            for (line) |char, idx| {
                if (std.ascii.isSpace(char)) {
                    self.last_space = idx;
                }
                if (char == '\n') {
                    // send
                }
                // assume send
                // if (line.len > )
            }
        }
    };
}

/// Xprinter 80mm text line lengths in characters
pub const wrap_80mm = struct {
    pub const font_a = enum(u8) {
        size_1 = 48,
        size_2 = 34,
        size_3 = 16,
        size_4 = 12,
    };
    pub const font_b = enum(u8) {
        size_1 = 64,
        size_2 = 32,
        size_3 = 21,
        size_4 = 16,
    };
};
