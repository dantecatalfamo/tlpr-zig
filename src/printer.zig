const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const debug = std.debug;

pub const Printer = union(enum) {
    file: std.fs.File.Writer,
    socket: std.net.Stream.Writer,

    const Self = @This();
    const WriteError = std.os.WriteError;
    const Writer = std.io.Writer(Self, WriteError, write);

    pub fn writer(self: Self) Writer {
        return .{ .context = self };
    }

    pub fn write(self: Self, bytes: []const u8) !usize {
        return switch (self) {
            .file => |file| try file.write(bytes),
            .socket => |sock| try sock.write(bytes)
        };
    }

    pub fn writeAll(self: Self, bytes: []const u8) !void {
        switch (self) {
            .file => |file| try file.writeAll(bytes),
            .socket => |sock| try sock.writeAll(bytes)
        }
    }
};

pub const WrappingPrinter = struct {
    wrap_length: u8 = 0,
    index: usize = 0,
    last_space: usize = 0,
    buffer:  [256]u8 = undefined,
    printer: Printer,
    wrapping_disabled: bool = true,

    const Self = @This();
    const WriteError = Printer.WriteError;
    const Writer = std.io.Writer(*Self, WriteError, write);

    pub fn init(printer: Printer) Self {
        return .{
            .printer = printer,
        };
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn write(self: *Self, line: []const u8) !usize {
        if (self.wrapping_disabled) {
            try self.printer.writeAll(line);
            return line.len;
        }

        for (line) |char| {
            if (char == '\n') {
                try self.printer.writeAll(self.buffer[0..self.index]);
                try self.printer.writeAll("\n");
                self.index = 0;
                self.last_space = 0;
                continue;
            } else if (ascii.isSpace(char)) {
                self.last_space = self.index;
            }
            self.buffer[self.index] = char;
            self.index += 1;
            if (self.index == self.wrap_length) {
                if (self.last_space == 0) {
                    self.last_space = self.index - 1;
                }
                const remaining = blk: {
                    if (ascii.isSpace(self.buffer[self.last_space]))
                        break :blk self.buffer[self.last_space+1..self.index];
                    break :blk self.buffer[self.last_space..self.index];
                };
                try self.printer.writeAll(self.buffer[0..self.last_space]);
                try self.printer.writeAll("\n");
                mem.copy(u8, self.buffer[0..], remaining);
                self.index = remaining.len;
                self.last_space = 0;
            }
        }
        return line.len;
    }

    pub fn writeAll(self: *Self, line: []const u8) !void {
        _ = try self.write(line);
    }

    pub fn writeAllDirect(self: *Self, line: []const u8) !void {
        _ = try self.flush();
        return self.printer.writeAll(line);
    }

    pub fn flush(self: *Self) !usize {
        try self.printer.writeAll(self.buffer[0..self.index]);
        const old_index = self.index;
        self.index = 0;
        self.last_space = 0;
        return old_index;
    }

    pub fn flushNewline(self: *Self) !void {
        try self.writeAll("\n");
    }

    pub fn setWrap(self: *Self, length: u8) !void {
        _ = try self.flush();
        if (length == 0) {
            try self.disableWrapping();
        } else {
            self.enableWrapping();
        }
        self.wrap_length = length;
    }

    pub fn enableWrapping(self: *Self) void {
        self.wrapping_disabled = false;
    }

    pub fn disableWrapping(self: *Self) !void {
        _ = try self.flush();
        self.wrapping_disabled = true;
    }
};

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
