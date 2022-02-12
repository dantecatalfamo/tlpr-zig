const std = @import("std");
const mem = std.mem;
const ascii = std.ascii;
const debug = std.debug;
const commands = @import("commands.zig");
const ExecuteMacroMode = commands.ExecuteMacroMode;
const BarcodeSystem = commands.BarcodeSystem;
const BitImageMode = commands.BitImageMode;
const raster_image = @import("raster_image.zig");
const Threshold = raster_image.Threshold;

pub const PrinterConnection = union(enum) {
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

pub const Printer = struct {
    barcode_height: u8 = 162,
    barcode_width: u8 = 3,
    buffer:  [256]u8 = undefined,
    character_height: u3 = 0,
    character_width: u3 = 0,
    clockwise_rotation: bool = false,
    connection: PrinterConnection,
    double_strike: bool = false,
    emphasis: bool = false,
    font: Font = .a,
    hri_font: Font = .a,
    hri_position: HriPosition = .not_printed,
    index: usize = 0,
    inverted: bool = false,
    justification: Justification = .left,
    last_space: usize = 0,
    left_margin: u16 = 0,
    line_spacing: LineSpacing = .default,
    motion_units_x: u8 = 0, // 180
    motion_units_y: u8 = 0, // 360
    printing_area_width: u16 = 511, // for 80mm printer. 58mm is 359
    underline: Underline = .none,
    upside_down: bool = false,
    wrap_length: u8 = 0,
    wrapping_enabled: bool = false,

    const Self = @This();
    const WriteError = Printer.WriteError;
    const Writer = std.io.Writer(*Self, WriteError, write);

    pub fn init(connection: PrinterConnection) Self {
        return .{
            .connection = connection,
        };
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    pub fn write(self: *Self, line: []const u8) !usize {
        if (!self.wrapping_enabled) {
            try self.connection.writeAll(line);
            return line.len;
        }

        for (line) |char| {
            if (char == '\n') {
                try self.connection.writeAll(self.buffer[0..self.index]);
                try self.connection.writeAll("\n");
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
                try self.connection.writeAll(self.buffer[0..self.last_space]);
                try self.connection.writeAll("\n");
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
        return self.connection.writeAll(line);
    }

    pub fn flush(self: *Self) !usize {
        try self.connection.writeAll(self.buffer[0..self.index]);
        const old_index = self.index;
        self.index = 0;
        self.last_space = 0;
        return old_index;
    }

    pub fn flushMaybeNewline(self: *Self) !void {
        if (self.index != 0 or !self.wrapping_enabled) {
            try self.writeAll("\n");
        }
    }

    pub fn setWrap(self: *Self, length: u8) !void {
        _ = try self.flush();
        if (length == 0) {
            try self.enableWrapping(false);
        } else {
            try self.enableWrapping(true);
        }
        self.wrap_length = length;
    }

    pub fn enableWrapping(self: *Self, enable: bool) !void {
        if (enable) {
            _ = try self.flush();
            self.wrapping_enabled = false;
        } else {
            self.wrapping_enabled = true;
        }
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
        self.character_height = size;
        self.character_width = size;
    }

    pub fn setCharacterSizeCustom(self: *Self, height: u3, width: u3) !void {
        try self.writeAllDirect(&commands.selectCharacterSize(height, width));
        self.character_height = height;
        self.character_width = width;
    }

    pub fn initialize(self: *Self) !void {
        try self.writeAllDirect(&commands.initialize);
        self.barcode_height = 162;
        self.barcode_width = 3;
        self.character_height = 0;
        self.character_width = 0;
        self.clockwise_rotation = false;
        self.double_strike = false;
        self.emphasis = false;
        self.font = .a;
        self.hri_font = .a;
        self.hri_position = .not_printed;
        self.inverted = false;
        self.justification = .left;
        self.left_margin = 0;
        self.line_spacing = .default;
        self.motion_units_x = 0;
        self.motion_units_y = 0;
        self.printing_area_width = 511;
        self.underline = .none;
        self.upside_down = false;
    }

    pub fn setJustification(self: *Self, justification: Justification) !void {
        const command = switch (justification) {
            .left => commands.justification.left,
            .center => commands.justification.center,
            .right => commands.justification.right,
        };
        try self.flushMaybeNewline();
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
        switch (line_spacing) {
            .default => try self.writeAllDirect(&commands.line_spacing.default),
            .custom => |val| try self.writeAllDirect(&commands.line_spacing.custom(val)),
        }
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

    pub fn setInverted(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.reverse_white_black_mode.on,
            false => commands.reverse_white_black_mode.off,
        };
        try self.writeAllDirect(&command);
        self.inverted = enable;
    }

    pub fn printImageFromFile(self: *Self, allocator: mem.Allocator, path: []const u8, threshold: Threshold) !void {
        const img = try raster_image.imageToBitRaster(allocator, path, threshold);
        defer allocator.free(img);
        try self.flushMaybeNewline();
        try self.writeAllDirect(img);
    }

    pub fn defineMacro(self: *Self) !void {
        try self.writeAllDirect(&commands.start_or_end_macro_definition);
    }

    pub fn executeMacro(self: *Self, times: u8, wait: u8, mode: ExecuteMacroMode) !void {
        try self.writeAllDirect(&commands.executeMacro(times, wait, mode));
    }

    pub fn setBarcodeHeight(self: *Self, height: u8) !void {
        try self.writeAllDirect(&commands.selectBarcodeHeight(height));
        self.barcode_height = height;
    }

    pub fn setBarcodeWidth(self: *Self, width: u8) !void {
        try self.writeAllDirect(&commands.setBarCodeWidth(width));
        self.barcode_width = width;
    }

    pub fn printBarcode(self: *Self, allocator: mem.Allocator, barcode_system: BarcodeSystem, data: []const u8) !void {
        const barcode = try commands.printBarcode(allocator, barcode_system, data);
        defer allocator.free(barcode);
        try self.flushMaybeNewline();
        try self.writeAllDirect(barcode);
    }

    pub fn setHriPosition(self: *Self, position: HriPosition) !void {
        const command = switch (position) {
            .not_printed => commands.select_hri_characters_printing_position.not_printed,
            .above_barcode => commands.select_hri_characters_printing_position.above_bar_code,
            .below_barcode => commands.select_hri_characters_printing_position.below_bar_code,
            .above_and_below_barcode => commands.select_hri_characters_printing_position.above_and_below_bar_code,
        };
        try self.writeAllDirect(&command);
        self.hri_position = position;
    }

    pub fn setHriFont(self: *Self, font: Font) !void {
        const command = switch (font) {
            .a => commands.hri_font.font_a,
            .b => commands.hri_font.font_b,
        };
        try self.writeAllDirect(&command);
        self.hri_font = font;
    }

    pub fn partialCut(self: *Self) !void {
        try self.writeAllDirect(&commands.partial_cut);
    }

    pub fn feedAndPartialCut(self: *Self, units: u8) !void {
        try self.flushMaybeNewline();
        try self.writeAllDirect(&commands.feedAndPartualCut(units));
    }

    pub fn printBitImage(self: *Self, allocator: mem.Allocator, mode: BitImageMode, image_data: []const u8) !void {
        try self.writeAllDirect(&commands.bitImageMode(allocator, mode, image_data));
    }

    pub fn enablePeripheralDevice(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.peripheral_device.enable,
            false => commands.peripheral_device.disable,
        };
        try self.writeAllDirect(&command);
    }

    pub fn enablePanelButtons(self: *Self, enable: bool) !void {
        const command = switch (enable) {
            true => commands.panel_buttons.enable,
            false => commands.panel_buttons.disable,
        };
        try self.writeAllDirect(&command);
    }

    pub fn setCharacterCodeTable(self: *Self, code_table: CharacterCodeTable) !void {
        const command = switch (code_table) {
            .usa_standard_europe, .pc437 => commands.character_code_table.pc437,
            .katakana => commands.character_code_table.katakana,
            .multilingual, .pc850 => commands.character_code_table.pc850,
            .portuguese, .pc860 => commands.character_code_table.pc860,
            .canadian_french, .pc863 => commands.character_code_table.pc863,
            .nodic, .pc865 => commands.character_code_table.pc865,
            .west_europe => commands.character_code_table.west_europe,
            .greek => commands.character_code_table.greek,
            .hebrew => commands.character_code_table.hebrew,
            .east_europe, .pc755 => commands.character_code_table.pc755,
            .iran => commands.character_code_table.iran,
            .wpc1252 => commands.character_code_table.wpc1252,
            .cyrillic2, .pc866 => commands.character_code_table.pc866,
            .latin2, .pc852 => commands.character_code_table.pc852,
            .pc858 => commands.character_code_table.pc858,
            .iranii => commands.character_code_table.iranii,
            .latvian => commands.character_code_table.latvian,
        };
        try self.writeAllDirect(&command);
    }

    pub fn setLeftMargin(self: *Self, units: u16) !void {
        try self.flushMaybeNewline();
        try self.writeAllDirect(&commands.setLeftMargin(units));
        self.left_margin = units;
    }

    pub fn setMotionUnits(self: *Self, x: u8, y: u8) !void {
        try self.flushMaybeNewline();
        try self.writeAllDirect(&commands.setMotionUnits(x, y));
        self.motion_units_x = x;
        self.motion_units_y = y;
    }

    pub fn setPrintingAreaWidth(self: *Self, units: u16) !void {
        try self.flushMaybeNewline();
        try self.writeAllDirect(&commands.setPrintingAreaWidth(units));
        self.printing_area_width = units;
    }

    pub fn setPrintPosition(self: *Self, units: u16) !void {
        try self.writeAllDirect(&commands.setPrintPosition(units));
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

pub const HriPosition = enum {
    not_printed,
    above_barcode,
    below_barcode,
    above_and_below_barcode,
};

pub const CharacterCodeTable = enum {
    usa_standard_europe,
    pc437,
    katakana,
    multilingual,
    pc850,
    portuguese,
    pc860,
    canadian_french,
    pc863,
    nodic,
    pc865,
    west_europe,
    greek,
    hebrew,
    east_europe,
    pc755,
    iran,
    wpc1252,
    cyrillic2,
    pc866,
    latin2,
    pc852,
    pc858,
    iranii,
    latvian,
};
