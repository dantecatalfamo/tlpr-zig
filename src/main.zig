const std = @import("std");
const os = std.os;
const mem = std.mem;
const commands = @import("./commands.zig");
const raster_image = @import("./raster_image.zig");
const Threshold = raster_image.Threshold;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

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
    var read_buffer: [4086]u8 = undefined;
    var output_stdout = false;

    var printer: Printer = undefined;

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

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
            if (mem.indexOf(u8, threshold_input, "-") != null) {
                var split = mem.split(u8, threshold_input, "-");
                const min_input = split.next().?;
                const max_input = split.next().?;
                const min = try std.fmt.parseInt(u8, min_input, 10);
                const max = try std.fmt.parseInt(u8, max_input, 10);
                if (min >= max) {
                    usage();
                }
                image_threshold = .{
                    .range = .{
                        .min = min,
                        .max = max,
                    },
                };
            } else {
                image_threshold = .{
                    .value = try std.fmt.parseInt(u8, threshold_input, 10)
                };
            }

            arg_idx += 1;
        } else if (mem.eql(u8, "--stdout", arg)) {
            output_stdout = true;
        }
    }


    if (ip == null and output_stdout == false) {
        usage();
    }

    if (output_stdout) {
        printer = Printer{ .file = stdout };
    } else {
        printer = blk: {
            const addr = try std.net.Address.resolveIp(ip.?, 9100);
            const stream = try std.net.tcpConnectToAddress(addr);
            break :blk Printer{ .socket = stream.writer() };
        };
    }

    if (!no_initialize) {
        try printer.writeAll(&commands.initialize);
    }

    if (justify) |justification| {
        if (mem.eql(u8, justification, "left")) {
            try printer.writeAll(&commands.justification.left);
        } else if (mem.eql(u8, justification, "center")) {
            try printer.writeAll(&commands.justification.center);
        } else if (mem.eql(u8, justification, "right")) {
            try printer.writeAll(&commands.justification.right);
        } else {
            usage();
        }
    }

    if (underline) |ul| {
        if (ul == 1) {
            try printer.writeAll(&commands.underline.one);
        } else if (ul == 2) {
            try printer.writeAll(&commands.underline.two);
        }
    }

    if (emphasis) {
        try printer.writeAll(&commands.emphasis.on);
    }

    if (rotate) {
        try printer.writeAll(&commands.clockwise_rotation_mode.on);
    }

    if (upside_down) {
        try printer.writeAll(&commands.upside_down_mode.enable);
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
        try printer.writeAll(&commands.selectCharacterSize(h, w));
    }

    if (reverse_black_white) {
        try printer.writeAll(&commands.reverse_white_black_mode.on);
    }

    if (image_path) |path| {
        const image = try raster_image.imageToBitRaster(allocator, path, image_threshold);
        defer allocator.free(image);
        try printer.writeAll(image);
    }

    while (true) {
        const n = try stdin.read(read_buffer[0..]);
        if (n == 0) { break; }
        _ = try printer.writeAll(read_buffer[0..n]);
    }

    if (cut) {
        try printer.writeAll(&commands.feedAndPartualCut(0));
    }
}

const Printer = union(enum) {
    file: std.fs.File.Writer,
    socket: std.net.Stream.Writer,

    const Self = @This();

    pub fn writeAll(self: Self, bytes: []const u8) !void {
        switch(self) {
            .file => |file| try file.writeAll(bytes),
            .socket => |sock| try sock.writeAll(bytes)
        }
    }
};

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
        \\    --height <1-8> select character height
        \\    --image <path> print an image
        \\    --ip the IP address of the printer
        \\    --justify <left|right|center>
        \\    --rotate rotate 90 degrees clockwise
        \\    --stdout write commands to standard out instead of sending over a socket
        \\    --threshold <value> image b/w threshold, 0-255 (default 150).
        \\    --threshold <min-max> image b/w threshold, randomized between min-max per pixel
        \\    --upsidedown enable upside down mode
        \\    --width <1-8> select character width
    ;
    stderr.print("{s}\n", .{usage_text}) catch unreachable;
    os.exit(1);
}
