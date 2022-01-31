const std = @import("std");
const mem = std.mem;
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
    const macro = iter.next() orelse return error.MissingMacro;

    // TODO use stringToEnum

    if (mem.eql(u8, macro, "Jl")) {
        // Justify left
        try writer.writeAll(&commands.justification.left);
    } else if (mem.eql(u8, macro, "Jc")) {
        // Justify center
        try writer.writeAll(&commands.justification.center);
    } else if (mem.eql(u8, macro, "Jr")) {
        // Justify right
        try writer.writeAll(&commands.justification.right);
    } else if (mem.eql(u8, macro, "Pp")) {
        // Print Position
        const arg = iter.next() orelse return error.MissingMacroArg;
        const num = try fmt.parseInt(u16, arg, 10);
        try writer.writeAll(&commands.setPrintPosition(num));
    } else if (mem.eql(u8, macro, "Un")) {
        // Underline none
        try writer.writeAll(&commands.underline.none);
    } else if (mem.eql(u8, macro, "Uo")) {
        // Underline one
        try writer.writeAll(&commands.underline.one);
    } else if (mem.eql(u8, macro, "Ut")) {
        // Underline two
        try writer.writeAll(&commands.underline.two);
    } else if (mem.eql(u8, macro, "Ls")) {
        // Line spacing
        const arg = iter.next() orelse return error.MissingMacroArg;
        if (mem.eql(u8, arg, "default")) {
            try writer.writeAll(&commands.line_spacing.default);
        } else {
            const num = try fmt.parseInt(u8, arg, 10);
            try writer.writeAll(&commands.line_spacing.custom(num));
        }
    } else if (mem.eql(u8, macro, "In")) {
        // Initialize
        try writer.writeAll(&commands.initialize);
    } else if (mem.eql(u8, macro, "Em")) {
        // Emphasis
        try writer.writeAll(&commands.emphasis.on);
    } else if (mem.eql(u8, macro, "Eo")) {
        // Emphasis off
        try writer.writeAll(&commands.emphasis.off);
    } else if (mem.eql(u8, macro, "Ds")) {
        // Double Strike
        try writer.writeAll(&commands.double_strike.on);
    } else if (mem.eql(u8, macro, "Do")) {
        // Double strike off
        try writer.writeAll(&commands.double_strike.off);
    } else if (mem.eql(u8, macro, "Pf")) {
        // Print and Feed
        const arg = iter.next() orelse return error.MissingMacroArg;
        const num = try fmt.parseInt(u8, arg, 10);
        try writer.writeAll(&commands.printAndFeed(num));
    } else if (mem.eql(u8, macro, "Fa")) {
        // Select character font a
        try writer.writeAll(&commands.character_font.font_a);
    } else if (mem.eql(u8, macro, "Fb")) {
        // Select character font b
        try writer.writeAll(&commands.character_font.font_b);
    } else if (mem.eql(u8, macro, "Sc")) {
        // TODO Select character set
        return error.NotImplemented;
    } else if (mem.eql(u8, macro, "Pd")) {
        // TODO Page mode print direction
        return error.NotImplemented;
    } else if (mem.eql(u8, macro, "Cr")) {
        // Clockwise rotation mode
        try writer.writeAll(&commands.clockwise_rotation_mode.on);
    } else if (mem.eql(u8, macro, "Co")) {
        // Clockwise rotation mode off
        try writer.writeAll(&commands.clockwise_rotation_mode.off);
    } else if (mem.eql(u8, macro, "Pl")) {
        // Print and feed lines
        const arg = iter.next() orelse return error.MissingMacroArg;
        const num = try fmt.parseInt(u8, arg, 10);
        try writer.writeAll(&commands.printAndFeedLines(num));
    } else if (mem.eql(u8, macro, "Ud")) {
        // Upside down mode
        try writer.writeAll(&commands.upside_down_mode.enable);
    } else if (mem.eql(u8, macro, "Ru")) {
        // Right side up mode (disable upside down)
        try writer.writeAll(&commands.upside_down_mode.disable);
    } else if (mem.eql(u8, macro, "Cs")) {
        // Character size
        const arg_height = iter.next() orelse return error.MissingMacroArg;
        const arg_width = iter.next() orelse return error.MissingMacroArg;
        const height = try fmt.parseInt(u3, arg_height, 10);
        const width = try fmt.parseInt(u3, arg_width, 10);
        try writer.writeAll(&commands.selectCharacterSize(height, width));
    } else if (mem.eql(u8, macro, "Md")) {
        // Start or stop define macro
        try writer.writeAll(&commands.start_or_end_macro_definition);
    } else if (mem.eql(u8, macro, "Rv")) {
        // Reverse black and white
        try writer.writeAll(&commands.reverse_white_black_mode.on);
    } else if (mem.eql(u8, macro, "Ro")) {
        // Reverse black and white off
        try writer.writeAll(&commands.reverse_white_black_mode.off);
    } else if (mem.eql(u8, macro, "Im")) {
        // Print image from path
        const arg_threshold = iter.next() orelse return error.MissingMacroArg;
        const threshold = try raster_image.parseThreshold(arg_threshold);
        const path = iter.rest();
        // Empty iter
        iter.index = iter.buffer.len;

        const img = try raster_image.imageToBitRaster(allocator, path, threshold);
        defer allocator.free(img);
        try writer.writeAll(img);
    } else if (mem.eql(u8, macro, "Hp")) {
        // TODO Set HRI character position for bar codes
        return error.NotImplemented;
    } else if (mem.eql(u8, macro, "Me")) {
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
    } else if (mem.eql(u8, macro, "Hf")) {
        // TODO HRI font
    } else if (mem.eql(u8, macro, "Bh")) {
        // Barcode height
        const arg = iter.next() orelse return error.MissingMacroArg;
        const num = try fmt.parseInt(u8, arg, 10);
        try writer.writeAll(&commands.selectBarcodeHeight(num));
    } else if (mem.eql(u8, macro, "Bw")) {
        // Barcode width
        const arg = iter.next() orelse return error.MissingMacroArg;
        const num = try fmt.parseInt(u8, arg, 10);
        try writer.writeAll(&commands.setBarCodeWidth(num));
    } else if (mem.eql(u8, macro, "Bc")) {
        // Barcode
        const arg_system = iter.next() orelse return error.MissingMacroArg;
        const arg_data = iter.rest();
        // empty iter
        iter.index = iter.buffer.len;
        const system = std.meta.stringToEnum(commands.barcode_system, arg_system) orelse return error.InvalidBarcodeSystem;

        const barcode = try commands.printBarcode(allocator, system, arg_data);
        defer allocator.free(barcode);
        try writer.writeAll(barcode);
    } else if (mem.eql(u8, macro, "Br")) {
        // Manual line break
        try writer.writeAll("\n");
    } else if (mem.eql(u8, macro, "Pc")) {
        // Partial cut
        try writer.writeAll(&commands.partial_cut);
    } else if (mem.eql(u8, macro, "Fc")) {
        // Feed and partial cut
        const arg = iter.next() orelse return error.MissingMacroArg;
        const num = try fmt.parseInt(u8, arg, 10);
        try writer.writeAll(&commands.feedAndPartualCut(num));
    }

    try writer.writeAll(iter.rest());
}
