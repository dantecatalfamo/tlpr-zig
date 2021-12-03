const std = @import("std");
const os = std.os;
const mem = std.mem;

const cut_cmd = "\n\n\n\n\u{001D}V\u{0001}";

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = &gpa.allocator;
    var ip: ?[]u8 = null;
    var cut = false;
    var read_buffer: [4086]u8 = undefined;
    const stdin = std.io.getStdIn().reader();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args) |arg, idx| {
        if (mem.eql(u8, "--ip", arg)) {
            if (idx + 1 == args.len) {
                usage();
            }
            ip = args[idx + 1];
        }
        if (mem.eql(u8, "-c", arg)) {
            cut = true;
        }
    }

    if (ip == null) {
        usage();
    }

    const addr = try std.net.Address.resolveIp(ip.?, 9100);
    const stream = try std.net.tcpConnectToAddress(addr);
    const writer = stream.writer();

    while (true) {
        const n = try stdin.read(read_buffer[0..]);
        if (n == 0) { break; }
        _ = try writer.write(read_buffer[0..n]);
    }

    if (cut) {
        try writer.print(cut_cmd, .{});
    }
}

fn usage() noreturn {
    const stderr = std.io.getStdErr().writer();
    const usage_text =
        \\ usage: tlpr --ip <ip> [-c]
        \\ Thermal Line printer application.
        \\ Prints stdin through thermal printer.
        \\
        \\ -c cut paper after printing.
    ;
    stderr.print("{s}\n", .{usage_text}) catch unreachable;
    os.exit(1);
}
