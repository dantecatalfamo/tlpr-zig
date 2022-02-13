const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const fmt = std.fmt;
const prnt = @import("printer.zig");
const Printer = prnt.Printer;
const LineSpacing = prnt.LineSpacing;
const commands = @import("commands.zig");
const raster_image = @import("raster_image.zig");

pub fn processMacroLine(allocator: mem.Allocator, line: []const u8, printer: *Printer) !void {
    if (mem.eql(u8, line, "")) {
        try printer.writeAll("\n");
        return;
    }

    if (line[0] != '.') {
        try printer.writeAllMaybePrependSpace(line);
        return;
    }

    var iter = mem.tokenize(u8, line[1..], " \t");
    const macro_str = iter.next() orelse return error.MissingMacro;
    const macro = meta.stringToEnum(macro_keywords, macro_str) orelse return error.InvalidMacro;

    switch(macro) {
        .@"\\\"" => {
            // Comment
            iter.index = iter.buffer.len;
        },
        .Jl => {
            // Justify left
            // Writes newline first
            try printer.setJustification(.left);
        },
        .Jc => {
            // Justify center
            // Writes newline first
            try printer.setJustification(.center);
        },
        .Jr => {
            // Justify right
            // Writes newline first
            try printer.setJustification(.right);
        },
        .Pp => {
            // Print Position
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u16, arg, 10);
            try printer.setPrintPosition(num);
        },
        .Un => {
            // Underline none
            try printer.setUnderline(.none);
        },
        .Uo => {
            // Underline one
            try printer.setUnderline(.single);
        },
        .Ut => {
            // Underline two
            try printer.setUnderline(.double);
        },
        .Ls => {
            // Line spacing
            const arg = iter.next() orelse return error.MissingMacroArg;
            if (mem.eql(u8, arg, "default")) {
                try printer.setLineSpacing(.default);
            } else {
                const num = try fmt.parseInt(u8, arg, 10);
                try printer.setLineSpacing(LineSpacing{ .custom = num });
            }
        },
        .In => {
            // Initialize
            try printer.initialize();
        },
        .Em => {
            // Emphasis
            try printer.setEmphasis(true);
        },
        .Eo => {
            // Emphasis off
            try printer.setEmphasis(false);
        },
        .Ds => {
            // Double Strike
            try printer.setDoubleStrike(true);
        },
        .Do => {
            // Double strike off
            try printer.setDoubleStrike(false);
        },
        .Pf => {
            // Print and Feed
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try printer.printAndFeed(num);
        },
        .Fa => {
            // Select character font a
            try printer.setFont(.a);
        },
        .Fb => {
            // Select character font b
            try printer.setFont(.b);
        },
        .Sc => {
            // TODO Select character set
            return error.NotImplemented;
        },
        .Pd => {
            // TODO Page mode print direction
            return error.NotImplemented;
        },
        .Cr => {
            // Clockwise rotation mode
            try printer.setClockwiseRotation(true);
        },
        .Co => {
            // Clockwise rotation mode off
            try printer.setClockwiseRotation(false);
        },
        .Pl => {
            // Print and feed lines
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try printer.printAndFeedLines(num);
        },
        .Ud => {
            // Upside down mode
            try printer.setUpsideDown(true);
        },
        .Ru => {
            // Right side up mode (disable upside down)
            try printer.setUpsideDown(false);
        },
        .Cs => {
            // Character size
            const arg_height = iter.next() orelse return error.MissingMacroArg;
            const arg_width = iter.next() orelse return error.MissingMacroArg;
            const height_u4 = try fmt.parseInt(u4, arg_height, 10);
            const width_u4 = try fmt.parseInt(u4, arg_width, 10);
            if (height_u4 > 8 or width_u4 > 8) {
                return error.InvalidCharacterSize;
            }
            const height = @truncate(u3, height_u4 - 1);
            const width = @truncate(u3, width_u4 - 1);
            try printer.setCharacterSizeCustom(height, width);
        },
        .Rv => {
            // Reverse black and white
            try printer.setInverted(true);
        },
        .Ro => {
            // Reverse black and white off
            try printer.setInverted(false);
        },
        .Im => {
            // Print image from path
            const arg_threshold = iter.next() orelse return error.MissingMacroArg;
            const threshold = try raster_image.parseThreshold(arg_threshold);
            const path = iter.rest();
            // Empty iter
            iter.index = iter.buffer.len;

            try printer.printImageFromFile(allocator, path, threshold);
        },
        .Hp => {
            // TODO Set HRI character position for bar codes
            return error.NotImplemented;
        },
        .Md => {
            // Start or stop define macro
            try printer.defineMacro();
        },
        .Me => {
            // Execute macro
            const arg_times = iter.next() orelse return error.MissingMacroArg;
            const arg_wait = iter.next() orelse return error.MissingMacroArg;
            const arg_mode = iter.next() orelse return error.MissingMacroArg;
            const num_times = try fmt.parseInt(u8, arg_times, 10);
            const num_wait = try fmt.parseInt(u8, arg_wait, 10);
            const mode = blk: {
                if (mem.eql(u8, arg_mode, "cont")) {
                    break :blk commands.ExecuteMacroMode.continuous;
                } else if (mem.eql(u8, arg_mode, "button")) {
                    break :blk commands.ExecuteMacroMode.on_feed_button;
                } else {
                    return error.InvalidMacroArg;
                }
            };
            try printer.executeMacro(num_times, num_wait, mode);
        },
        .Hf => {
            // TODO HRI font
        },
        .Bh => {
            // Barcode height
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try printer.setBarcodeHeight(num);
        },
        .Bw => {
            // Barcode width
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try printer.setBarcodeWidth(num);
        },
        .Bc => {
            // Barcode
            const arg_system = iter.next() orelse return error.MissingMacroArg;
            const arg_data = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;
            const system = meta.stringToEnum(commands.BarcodeSystem, arg_system) orelse return error.InvalidBarcodeSystem;

            try printer.printBarcode(allocator, system, arg_data);
        },
        .Br => {
            // Manual line break
            try printer.writeAll("\n");
        },
        .Pc => {
            // Partial cut
            try printer.partialCut();
        },
        .Fc => {
            // Feed and partial cut
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try printer.feedAndPartialCut(num);
        },
        .T1 => {
            // Text size 1
            try printer.setCharacterSize(0);
        },
        .T2 => {
            // Text size 2
            try printer.setCharacterSize(1);
        },
        .T3 => {
            // Text size 3
            try printer.setCharacterSize(2);
        },
        .T4 => {
            // Text size 4
            try printer.setCharacterSize(3);
        },
        .Tr => {
            // Text reset
            try printer.resetInlineFormatting();
        },
        .H1 => {
            // Headline 1
            // Headline 1 = Text size 2 ++ arg ++ Text size 1 ++ newline
            // Headlines print the rest of the line at headline size
            // and then return to default size automatically and
            // append a newline
            const arg = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;

            const prev_size = printer.character_width;
            try printer.flushMaybeNewline();
            try printer.setCharacterSize(1);
            try printer.writeAll(arg);
            try printer.setCharacterSize(prev_size);
            try printer.flushMaybeNewline();
        },
        .H2 => {
            // Headline 2
            const arg = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;

            const prev_size = printer.character_width;
            try printer.flushMaybeNewline();
            try printer.setCharacterSize(2);
            try printer.writeAll(arg);
            try printer.setCharacterSize(prev_size);
            try printer.flushMaybeNewline();
        },
        .H3 => {
            // Headline 3
            const arg = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;

            const prev_size = printer.character_width;
            try printer.flushMaybeNewline();
            try printer.setCharacterSize(3);
            try printer.writeAll(arg);
            try printer.setCharacterSize(prev_size);
            try printer.flushMaybeNewline();
        },
        .Ww => {
            // Change word wrap
            // Wrap length of 0 disables printer
            const arg = iter.next() orelse return error.MissingMacroArg;
            if (mem.eql(u8, arg, "auto")) {
                try printer.setWrapAuto(true);
            } else if (mem.eql(u8, arg, "noauto")) {
                try printer.setWrapAuto(false);
            } else if (mem.eql(u8, arg, "enable")) {
                try printer.enableWrapping(true);
            } else if (mem.eql(u8, arg, "disable")) {
                try printer.enableWrapping(false);
            } else {
                const num = try fmt.parseInt(u8, arg, 10);
                try printer.setWrap(num);
            }
        },

    }

    try printer.writeAllMaybePrependSpace(iter.rest());
}

const macro_keywords = enum {
    @"\\\"",
    Bc,
    Bh,
    Br,
    Bw,
    Co,
    Cr,
    Cs,
    Do,
    Ds,
    Em,
    Eo,
    Fa,
    Fb,
    Fc,
    Hf,
    Hp,
    H1,
    H2,
    H3,
    Im,
    In,
    Jc,
    Jl,
    Jr,
    Ls,
    Md,
    Me,
    Pc,
    Pd,
    Pf,
    Pl,
    Pp,
    Ro,
    Ru,
    Rv,
    Sc,
    T1,
    T2,
    T3,
    T4,
    Tr,
    Ud,
    Un,
    Uo,
    Ut,
    Ww,
};
