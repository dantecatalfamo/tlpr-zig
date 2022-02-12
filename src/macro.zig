const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const fmt = std.fmt;
const prnt = @import("printer.zig");
const Printer = prnt.Printer;
const WrappingPrinter = prnt.WrappingPrinter;
const commands = @import("commands.zig");
const raster_image = @import("raster_image.zig");

pub fn processMacroLine(allocator: mem.Allocator, line: []const u8, wrapping: *WrappingPrinter) !void {
    if (mem.eql(u8, line, "")) {
        try wrapping.writeAll("\n");
        return;
    }

    if (line[0] != '.') {
        try wrapping.writeAll(line);
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
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.justification.left);
        },
        .Jc => {
            // Justify center
            // Writes newline first
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.justification.center);
        },
        .Jr => {
            // Justify right
            // Writes newline first
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.justification.right);
        },
        .Pp => {
            // Print Position
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u16, arg, 10);
            try wrapping.writeAllDirect(&commands.setPrintPosition(num));
        },
        .Un => {
            // Underline none
            try wrapping.writeAllDirect(&commands.underline.none);
        },
        .Uo => {
            // Underline one
            try wrapping.writeAllDirect(&commands.underline.one);
        },
        .Ut => {
            // Underline two
            try wrapping.writeAllDirect(&commands.underline.two);
        },
        .Ls => {
            // Line spacing
            const arg = iter.next() orelse return error.MissingMacroArg;
            if (mem.eql(u8, arg, "default")) {
                try wrapping.writeAllDirect(&commands.line_spacing.default);
            } else {
                const num = try fmt.parseInt(u8, arg, 10);
                try wrapping.writeAllDirect(&commands.line_spacing.custom(num));
            }
        },
        .In => {
            // Initialize
            try wrapping.writeAllDirect(&commands.initialize);
        },
        .Em => {
            // Emphasis
            try wrapping.writeAllDirect(&commands.emphasis.on);
        },
        .Eo => {
            // Emphasis off
            try wrapping.writeAllDirect(&commands.emphasis.off);
        },
        .Ds => {
            // Double Strike
            try wrapping.writeAllDirect(&commands.double_strike.on);
        },
        .Do => {
            // Double strike off
            try wrapping.writeAllDirect(&commands.double_strike.off);
        },
        .Pf => {
            // Print and Feed
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.printAndFeed(num));
        },
        .Fa => {
            // Select character font a
            try wrapping.writeAllDirect(&commands.character_font.font_a);
        },
        .Fb => {
            // Select character font b
            try wrapping.writeAllDirect(&commands.character_font.font_b);
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
            try wrapping.writeAllDirect(&commands.clockwise_rotation_mode.on);
        },
        .Co => {
            // Clockwise rotation mode off
            try wrapping.writeAllDirect(&commands.clockwise_rotation_mode.off);
        },
        .Pl => {
            // Print and feed lines
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.printAndFeedLines(num));
        },
        .Ud => {
            // Upside down mode
            try wrapping.writeAll(&commands.upside_down_mode.enable);
        },
        .Ru => {
            // Right side up mode (disable upside down)
            try wrapping.writeAll(&commands.upside_down_mode.disable);
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
            try wrapping.writeAllDirect(&commands.selectCharacterSize(height, width));
        },
        .Rv => {
            // Reverse black and white
            try wrapping.writeAllDirect(&commands.reverse_white_black_mode.on);
        },
        .Ro => {
            // Reverse black and white off
            try wrapping.writeAllDirect(&commands.reverse_white_black_mode.off);
        },
        .Im => {
            // Print image from path
            const arg_threshold = iter.next() orelse return error.MissingMacroArg;
            const threshold = try raster_image.parseThreshold(arg_threshold);
            const path = iter.rest();
            // Empty iter
            iter.index = iter.buffer.len;

            const img = try raster_image.imageToBitRaster(allocator, path, threshold);
            defer allocator.free(img);
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(img);
        },
        .Hp => {
            // TODO Set HRI character position for bar codes
            return error.NotImplemented;
        },
        .Md => {
            // Start or stop define macro
            try wrapping.writeAllDirect(&commands.start_or_end_macro_definition);
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
            try wrapping.writeAllDirect(&commands.executeMacro(num_times, num_wait, mode));
        },
        .Hf => {
            // TODO HRI font
        },
        .Bh => {
            // Barcode height
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try wrapping.writeAllDirect(&commands.selectBarcodeHeight(num));
        },
        .Bw => {
            // Barcode width
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try wrapping.writeAllDirect(&commands.setBarCodeWidth(num));
        },
        .Bc => {
            // Barcode
            const arg_system = iter.next() orelse return error.MissingMacroArg;
            const arg_data = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;
            const system = meta.stringToEnum(commands.BarcodeSystem, arg_system) orelse return error.InvalidBarcodeSystem;

            const barcode = try commands.printBarcode(allocator, system, arg_data);
            defer allocator.free(barcode);

            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(barcode);
        },
        .Br => {
            // Manual line break
            try wrapping.flushMaybeNewline();
        },
        .Pc => {
            // Partial cut
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.partial_cut);
        },
        .Fc => {
            // Feed and partial cut
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.feedAndPartualCut(num));
        },
        .T1 => {
            // Text size 1
            try wrapping.writeAllDirect(&commands.selectCharacterSize(0, 0));
        },
        .T2 => {
            // Text size 2
            try wrapping.writeAllDirect(&commands.selectCharacterSize(1, 1));
        },
        .T3 => {
            // Text size 3
            try wrapping.writeAllDirect(&commands.selectCharacterSize(2, 2));
        },
        .T4 => {
            // Text size 4
            try wrapping.writeAllDirect(&commands.selectCharacterSize(3, 3));
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
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.selectCharacterSize(1, 1));
            try wrapping.writeAll(arg);
            try wrapping.writeAllDirect(&commands.selectCharacterSize(0, 0));
            try wrapping.flushMaybeNewline();
        },
        .H2 => {
            // Headline 2
            const arg = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.selectCharacterSize(2, 2));
            try wrapping.writeAll(arg);
            try wrapping.writeAllDirect(&commands.selectCharacterSize(0, 0));
            try wrapping.flushMaybeNewline();
        },
        .H3 => {
            // Headline 3
            const arg = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;
            try wrapping.flushMaybeNewline();
            try wrapping.writeAllDirect(&commands.selectCharacterSize(3, 3));
            try wrapping.writeAll(arg);
            try wrapping.writeAllDirect(&commands.selectCharacterSize(0, 0));
            try wrapping.flushMaybeNewline();
        },
        .Ww => {
            // Change word wrap
            // Wrap length of 0 disables wrapping
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try wrapping.setWrap(num);
        },

    }

    try wrapping.writeAll(iter.rest());
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
    Ud,
    Un,
    Uo,
    Ut,
    Ww,
};
