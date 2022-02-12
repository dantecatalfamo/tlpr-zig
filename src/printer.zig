const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const debug = std.debug;
const commands = @import("commands.zig");
const raster_image = @import("raster_image.zig");
const Threshold = raster_image.Threshold;

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
    font: Font = .a,
    character_size: u3 = 0,
    justification: Justification = .left,
    underline: Underline = .none,
    line_spacing: LineSpacing = .default,
    emphasis: bool = false,
    double_strike: bool = false,
    clockwise_rotation: bool = false,
    upside_down: bool = false,
    inverted: bool = false,

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

    pub fn flushMaybeNewline(self: *Self) !void {
        if (self.index != 0 or self.wrapping_disabled) {
            try self.writeAll("\n");
        }
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

    pub fn setFont(self: *Self, font: Font) !void {
        const command = switch (font) {
            .a => commands.character_font.font_a,
            .b => commands.character_font.font_b,
        };
        try self.writeAllDirect(&command);
        self.font = font;
    }

    pub fn setCharacterSize(self: *Self, size: u3) !void {
        try self.writeAllDirect(&commands.selectCharacterSize(size, size));
        self.character_size = size;
    }

    pub fn initialize(self: *Self) !void {
        try self.writeAllDirect(&commands.initialize);
        self.font = .a;
        self.character_size = 0;
        self.justification = .left;
        self.underline = .none;
        self.line_spacing = .default;
        self.emphasis = false;
        self.double_strike = false;
        self.clockwise_rotation = false;
        self.upside_down = false;
        self.inverted = false;
    }

    pub fn setJustification(self: *Self, justification: Justification) !void {
        try self.flushMaybeNewline();
        const command = switch (justification) {
            .left => commands.justification.left,
            .center => commands.justification.center,
            .right => commands.justification.right,
        };
        try self.writeAllDirect(&command);
        self.justification = justification;
    }

    pub fn setUnderline(self: *Self, underline: Underline) !void {
        const command = switch (underline) {
            .none => commands.underline.none,
            .single => commands.underline.one,
            .double => commands.underline.two,
        };
        try self.writeAllDirect(&command);
        self.underline = underline;
    }

    pub fn setLineSpacing(self: *Self, line_spacing: LineSpacing) !void {
        const command = switch (spacing) {
            .default => commands.line_spacing.default,
            .custom => commands.line_spacing.custom(spacing),
        };
        try self.writeAllDirect(&command);
        self.line_spacing = line_spacing;
    }

    pub fn setEmphasis(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.emphasis.on,
            false => commands.emphasis.off,
        };
        try self.writeAllDirect(&command);
        self.emphasis = enable;
    }

    pub fn setDoubleStrike(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.double_strike.on,
            false => commands.double_strike.off,
        };
        try self.writeAllDirect(&command);
        self.double_strike = enable;
    }

    pub fn printAndFeed(self: *Self, units: u8) !void {
        try self.flushMaybeNewline();
        try self.writeAllDirect(&commands.printAndFeed(units));
    }

    pub fn printAndFeedLines(self: *Self, lines: u8) !void {
        try self.flushMaybeNewline();
        try self.writeAllDirect(&commands.printAndFeedLines(lines));
    }

    pub fn setClockwiseRotation(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.clockwise_rotation_mode.on,
            false => commands.clockwise_rotation_mode.off,
        };
        try self.writeAllDirect(&command);
        self.clockwise_rotation = enable;
    }

    pub fn setUpsideDown(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.upside_down_mode.enable,
            false => commands.upside_down_mode.disable,
        };
        try self.writeAllDirect(&command);
        self.upside_down = enable;
    }

    pub fn invert(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.reverse_white_black_mode.on,
            false => commands.reverse_white_black_mode.off,
        };
        try self.writeAllDirect(&command);
        self.inverted = enable;
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

pub const Font = enum {
    a,
    b,
};

pub const Justification = enum {
    left,
    right,
    center,
};

pub const Underline = enum {
    none,
    single,
    double,
};

pub const LineSpacing = union(enum) {
    default,
    custom: u8,
};
