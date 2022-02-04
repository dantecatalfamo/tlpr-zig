const std = @import("std");

pub const Printer = union(enum) {
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
