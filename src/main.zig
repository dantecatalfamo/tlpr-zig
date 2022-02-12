const std = @import("std");
const os = std.os;
const mem = std.mem;
const commands = @import("./commands.zig");
const raster_image = @import("./raster_image.zig");
const macro = @import("macro.zig");
const Threshold = raster_image.Threshold;
const prnt = @import("printer.zig");
const Printer = prnt.Printer;
const PrinterConnection = prnt.PrinterConnection;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var alt_font = false;
    var ip: ?[]u8 = null;
    var cut = false;
    var justify: ?[]u8 = null;
    var underline: ?u2 = null;
    var emphasis = false;
    var rotate = false;
    var upside_down = false;
    var char_height: ?u4 = null;
    var char_width: ?u4 = null;
    var reverse_black_white = false;
    var no_initialize = false;
    var image_path: ?[]u8 = null;
    var image_threshold: Threshold = .{ .value = 150 };
    var read_buffer: [8192]u8 = undefined;
    var output_stdout = false;
    var macro_mode = false;
    var word_wrap: ?u8 = null;

    var connection: PrinterConnection = undefined;
    var printer: Printer = undefined;

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var arg_idx: u32 = 0;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        if (mem.eql(u8, "--help", arg)) {
            usage();
        } else if (mem.eql(u8, "--ip", arg)) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            ip = args[arg_idx + 1];
            arg_idx += 1;
        } else if (mem.eql(u8, "-c", arg)) {
            cut = true;
        } else if (mem.eql(u8, "--justify", arg)) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            justify = args[arg_idx + 1];
            arg_idx += 1;
        } else if (mem.startsWith(u8, arg, "-u")) {
            if (arg.len == "-u".len) {
                underline = 1;
            } else if (mem.eql(u8, "-uu", arg)) {
                underline = 2;
            } else {
                usage();
            }
        } else if (mem.eql(u8, "-e", arg)) {
            emphasis = true;
        } else if (mem.eql(u8, "--rotate", arg)) {
            rotate = true;
        } else if (mem.eql(u8, "--upsidedown", arg)) {
            upside_down = true;
        }
        else if (mem.eql(u8, "--height", arg)) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            char_height = try std.fmt.parseInt(u4, args[arg_idx + 1], 10);
            arg_idx += 1;
        } else if (mem.eql(u8, "--width", arg)) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            char_width = try std.fmt.parseInt(u4, args[arg_idx + 1], 10);
            arg_idx += 1;
        } else if (mem.eql(u8, "-r", arg)) {
            reverse_black_white = true;
        } else if (mem.eql(u8, "-n", arg)) {
            no_initialize = true;
        } else if (mem.eql(u8, "--image", arg)) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            image_path = args[arg_idx + 1];
            arg_idx += 1;
        } else if (mem.eql(u8, "--threshold", arg)) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            const threshold_input = args[arg_idx + 1];
            image_threshold = try raster_image.parseThreshold(threshold_input);

            arg_idx += 1;
        } else if (mem.eql(u8, "--stdout", arg)) {
            output_stdout = true;
        } else if (mem.eql(u8, "--alt", arg)) {
            alt_font = true;
        } else if (mem.eql(u8, arg, "--macro")) {
            macro_mode = true;
        } else if (mem.eql(u8, arg, "--wrap")) {
            if (arg_idx + 1 == args.len) {
                usage();
            }
            word_wrap = try std.fmt.parseInt(u8, args[arg_idx + 1], 10);
            arg_idx += 1;
        }
    }


    if (ip == null and output_stdout == false) {
        usage();
    }

    if (output_stdout) {
        connection = PrinterConnection{ .file = stdout };
    } else {
        connection = blk: {
            const addr = try std.net.Address.resolveIp(ip.?, 9100);
            const stream = try std.net.tcpConnectToAddress(addr);
            break :blk PrinterConnection{ .socket = stream.writer() };
        };
    }

    printer = Printer.init(connection);

    if (word_wrap) |wrap_len| {
      try printer.setWrap(wrap_len);
    }

    if (!no_initialize) {
        try connection.writeAll(&commands.initialize);
    }

    if (justify) |justification| {
        if (mem.eql(u8, justification, "left")) {
            try connection.writeAll(&commands.justification.left);
        } else if (mem.eql(u8, justification, "center")) {
            try connection.writeAll(&commands.justification.center);
        } else if (mem.eql(u8, justification, "right")) {
            try connection.writeAll(&commands.justification.right);
        } else {
            usage();
        }
    }

    if (underline) |ul| {
        if (ul == 1) {
            try connection.writeAll(&commands.underline.one);
        } else if (ul == 2) {
            try connection.writeAll(&commands.underline.two);
        }
    }

    if (emphasis) {
        try connection.writeAll(&commands.emphasis.on);
    }

    if (rotate) {
        try connection.writeAll(&commands.clockwise_rotation_mode.on);
    }

    if (upside_down) {
        try connection.writeAll(&commands.upside_down_mode.enable);
    }

    if (char_height != null or char_width != null) {
        if (char_height) |height| {
            if (height > 8 or height < 1) {
                usage();
            }
        }

        if (char_width) |width| {
            if (width > 8 or width < 1) {
                usage();
            }
        }

        const h = @truncate(u3, (char_height orelse 1) - 1);
        const w = @truncate(u3, (char_width orelse 1) - 1);
        try connection.writeAll(&commands.selectCharacterSize(h, w));
    }

    if (reverse_black_white) {
        try connection.writeAll(&commands.reverse_white_black_mode.on);
    }

    if (alt_font) {
        try connection.writeAll(&commands.character_font.font_b);
    }

    if (image_path) |path| {
        const image = try raster_image.imageToBitRaster(allocator, path, image_threshold);
        defer allocator.free(image);
        try connection.writeAll(image);
    }

    if (macro_mode) {
        var line_number: usize = 0;
        while (true) {
            line_number += 1;
            const line = try stdin.readUntilDelimiterOrEof(read_buffer[0..], '\n');
            if (line) |valid_line| {
                macro.processMacroLine(allocator, valid_line, &printer) catch |err| {
                    try stderr.print("Macro error on line {d}: {s}\n", .{ line_number, @errorName(err) });
                    return err;
                };
            } else {
                try connection.writeAll("\n");
                break;
            }
        }
    } else {
        while (true) {
            const line = try stdin.readUntilDelimiterOrEof(read_buffer[0..], '\n');
            if (line) |valid_line| {
                try printer.writeAll(valid_line);
                try printer.writeAll("\n");
            } else {
                break;
            }
        }
    }

    if (cut) {
        try connection.writeAll(&commands.feedAndPartualCut(0));
    }
}

fn usage() noreturn {
    const stderr = std.io.getStdErr().writer();
    const usage_text =
        \\usage: tlpr --ip <ip> [options]
        \\       tlpr --stdout  [options]
        \\    Thermal Line Printer application.
        \\    Prints stdin through thermal printer.
        \\
        \\    -c cut paper after printing.
        \\    -e emphasis
        \\    -n don't initialize the printer when connecting
        \\    -r reverse black/white printing
        \\    -u underline
        \\    -uu double underline
        \\    --alt use alternate font
        \\    --height <1-8> select character height
        \\    --image <path> print an image
        \\    --ip the IP address of the printer
        \\    --justify <left|right|center>
        \\    --macro use roff-like macro language
        \\    --rotate rotate 90 degrees clockwise
        \\    --stdout write commands to standard out instead of sending over a socket
        \\    --threshold <value> image b/w threshold, 0-255 (default 150).
        \\    --threshold <min-max> image b/w threshold, randomized between min-max per pixel
        \\    --upsidedown enable upside down mode
        \\    --width <1-8> select character width
        \\    --wrap <num> wrap lines at <num> characters
    ;
    stderr.print("{s}\n", .{ usage_text }) catch unreachable;
    os.exit(1);
}
