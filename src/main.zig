const std = @import("std");
const os = std.os;
const mem = std.mem;
const commands = @import("./commands.zig");

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
    var read_buffer: [4086]u8 = undefined;
    const stdin = std.io.getStdIn().reader();

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
        }
    }


    if (ip == null) {
        usage();
    }

    const addr = try std.net.Address.resolveIp(ip.?, 9100);
    const stream = try std.net.tcpConnectToAddress(addr);
    const printer = stream.writer();

    try printer.writeAll(&commands.initialize);

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

    while (true) {
        const n = try stdin.read(read_buffer[0..]);
        if (n == 0) { break; }
        _ = try printer.write(read_buffer[0..n]);
    }

    if (cut) {
        try printer.writeAll(commands.cut);
    }
}

fn usage() noreturn {
    const stderr = std.io.getStdErr().writer();
    const usage_text =
        \\usage: tlpr --ip <ip> [options]
        \\    Thermal Line printer application.
        \\    Prints stdin through thermal printer.
        \\
        \\    -c cut paper after printing.
        \\    --justify <left|right|center>
        \\    -u underline
        \\    -uu double underline
        \\    -e emphasis
        \\    --rotate rotate 90 degrees clockwise
        \\    --upsidedown enable upside down mode
        \\    --height <1-8> select character height
        \\    --width <1-8> select character width
        \\    -r reverse black/white printing
    ;
    stderr.print("{s}\n", .{usage_text}) catch unreachable;
    os.exit(1);
}
