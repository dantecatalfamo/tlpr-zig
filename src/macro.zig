const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const fmt = std.fmt;
const Printer = @import("main.zig").Printer;
const commands = @import("commands.zig");
const raster_image = @import("raster_image.zig");

pub fn processMacroLine(allocator: mem.Allocator, line: []const u8, writer: Printer) !void {
    if (mem.eql(u8, line, "")) {
        try writer.writeAll("\n");
        return;
    }

    if (line[0] != '.') {
        try writer.writeAll(line);
        return;
    }
    var iter = mem.tokenize(u8, line[1..], " \t");
    const macro_str = iter.next() orelse return error.MissingMacro;
    const macro = meta.stringToEnum(macroKeywords, macro_str) orelse return error.InvalidMacro;

    switch(macro) {
        .@"\\\"" => {
            // Comment
            iter.index = iter.buffer.len;
        },
        .Jl => {
            // Justify left
            try writer.writeAll(&commands.justification.left);
        },
        .Jc => {
            // Justify center
            try writer.writeAll(&commands.justification.center);
        },
        .Jr => {
            // Justify right
            try writer.writeAll(&commands.justification.right);
        },
        .Pp => {
            // Print Position
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u16, arg, 10);
            try writer.writeAll(&commands.setPrintPosition(num));
        },
        .Un => {
            // Underline none
            try writer.writeAll(&commands.underline.none);
        },
        .Uo => {
            // Underline one
            try writer.writeAll(&commands.underline.one);
        },
        .Ut => {
            // Underline two
            try writer.writeAll(&commands.underline.two);
        },
        .Ls => {
            // Line spacing
            const arg = iter.next() orelse return error.MissingMacroArg;
            if (mem.eql(u8, arg, "default")) {
                try writer.writeAll(&commands.line_spacing.default);
            } else {
                const num = try fmt.parseInt(u8, arg, 10);
                try writer.writeAll(&commands.line_spacing.custom(num));
            }
        },
        .In => {
            // Initialize
            try writer.writeAll(&commands.initialize);
        },
        .Em => {
            // Emphasis
            try writer.writeAll(&commands.emphasis.on);
        },
        .Eo => {
            // Emphasis off
            try writer.writeAll(&commands.emphasis.off);
        },
        .Ds => {
            // Double Strike
            try writer.writeAll(&commands.double_strike.on);
        },
        .Do => {
            // Double strike off
            try writer.writeAll(&commands.double_strike.off);
        },
        .Pf => {
            // Print and Feed
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try writer.writeAll(&commands.printAndFeed(num));
        },
        .Fa => {
            // Select character font a
            try writer.writeAll(&commands.character_font.font_a);
        },
        .Fb => {
            // Select character font b
            try writer.writeAll(&commands.character_font.font_b);
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
            try writer.writeAll(&commands.clockwise_rotation_mode.on);
        },
        .Co => {
            // Clockwise rotation mode off
            try writer.writeAll(&commands.clockwise_rotation_mode.off);
        },
        .Pl => {
            // Print and feed lines
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try writer.writeAll(&commands.printAndFeedLines(num));
        },
        .Ud => {
            // Upside down mode
            try writer.writeAll(&commands.upside_down_mode.enable);
        },
        .Ru => {
            // Right side up mode (disable upside down)
            try writer.writeAll(&commands.upside_down_mode.disable);
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
            try writer.writeAll(&commands.selectCharacterSize(height, width));
        },
        .Rv => {
            // Reverse black and white
            try writer.writeAll(&commands.reverse_white_black_mode.on);
        },
        .Ro => {
            // Reverse black and white off
            try writer.writeAll(&commands.reverse_white_black_mode.off);
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
            try writer.writeAll("\n");
            try writer.writeAll(img);
        },
        .Hp => {
            // TODO Set HRI character position for bar codes
            return error.NotImplemented;
        },
        .Md => {
            // Start or stop define macro
            try writer.writeAll(&commands.start_or_end_macro_definition);
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
                    break :blk commands.execute_macro_mode.continuous;
                } else if (mem.eql(u8, arg_mode, "button")) {
                    break :blk commands.execute_macro_mode.on_feed_button;
                } else {
                    return error.InvalidMacroArg;
                }
            };
            try writer.writeAll(&commands.executeMacro(num_times, num_wait, mode));
        },
        .Hf => {
            // TODO HRI font
        },
        .Bh => {
            // Barcode height
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try writer.writeAll(&commands.selectBarcodeHeight(num));
        },
        .Bw => {
            // Barcode width
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try writer.writeAll(&commands.setBarCodeWidth(num));
        },
        .Bc => {
            // Barcode
            const arg_system = iter.next() orelse return error.MissingMacroArg;
            const arg_data = iter.rest();
            // empty iter
            iter.index = iter.buffer.len;
            const system = meta.stringToEnum(commands.barcode_system, arg_system) orelse return error.InvalidBarcodeSystem;

            const barcode = try commands.printBarcode(allocator, system, arg_data);
            defer allocator.free(barcode);

            try writer.writeAll("\n");
            try writer.writeAll(barcode);
        },
        .Br => {
            // Manual line break
            try writer.writeAll("\n");
        },
        .Pc => {
            // Partial cut
            try writer.writeAll("\n");
            try writer.writeAll(&commands.partial_cut);
        },
        .Fc => {
            // Feed and partial cut
            const arg = iter.next() orelse return error.MissingMacroArg;
            const num = try fmt.parseInt(u8, arg, 10);
            try writer.writeAll("\n");
            try writer.writeAll(&commands.feedAndPartualCut(num));
        },
        .H0 => {
            // No headline (regular size text)
            try writer.writeAll(&commands.selectCharacterSize(0, 0));
        },
        .H1 => {
            // Headline 1
            try writer.writeAll(&commands.selectCharacterSize(1, 1));
        },
        .H2 => {
            // Headline 2
            try writer.writeAll(&commands.selectCharacterSize(2, 2));
        },
        .H3 => {
            // Headline 3
            try writer.writeAll(&commands.selectCharacterSize(3, 3));
        }
    }

    try writer.writeAll(iter.rest());
}

pub fn wordWrap(line: []u8, width: u8) void {
    var last_space: usize = 0;
    var last_newline: usize = 0;

    for (line) |char, idx| {
        const cur_line = idx - last_newline;
        std.debug.print("thing: {d}\n", .{ cur_line });
        if (std.ascii.isSpace(char)) {
            last_space = idx;
        }
        if (cur_line == width-1) {
            std.debug.print("newline added\n", .{});
            last_newline = idx;
            line[last_space] = '\n';
        }
    }
}

const macroKeywords = enum {
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
    Ud,
    Un,
    Uo,
    Ut,
};