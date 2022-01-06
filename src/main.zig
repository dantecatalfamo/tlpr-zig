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
    var read_buffer: [4086]u8 = undefined;
    const stdin = std.io.getStdIn().reader();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var arg_idx: u32 = 0;
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];

        if (mem.eql(u8, "--ip", arg)) {
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
    ;
    stderr.print("{s}\n", .{usage_text}) catch unreachable;
    os.exit(1);
}
