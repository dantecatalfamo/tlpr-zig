const std = @import("std");
const zigimg = @import("zigimg");
const commands = @import("./commands.zig");

pub fn imageToBitRaster(allocator: std.mem.Allocator, path: []const u8, threshold: u8) ![]u8 {
    const image = try zigimg.Image.fromFilePath(allocator, path);
    defer image.deinit();

    if (image.pixels == null) {
        return error.InvalidImage;
    }

    const width = image.width;
    const height = image.height;
    const byte_width = width / 8 + @as(u8, if (width % 8 == 0) 0 else 1);
    const extra_bits = 8 - width % 8;

    // The max size differs by manual
    if (width > std.math.maxInt(u16) or height > 2040) {
        return error.ImageTooLarge;
    }

    var bytes = try allocator.alloc(u8, byte_width * height);
    defer allocator.free(bytes);

    for (bytes) |*byte| {
        byte.* = 0;
    }

    var iter = image.iterator();

    var byte: u64 = 0;
    var bit: u64 = 0;
    var output_bit: u64 = 0;

    while (iter.next()) |color| : (bit += 1) {
        if (bit != 0 and bit % width == 0) {
            output_bit += extra_bits;
        }
        const int_val = color.toIntegerColor8();
        const avg = @truncate(u8, (@as(u16, int_val.R) + int_val.G + int_val.B) / 3);
        byte = output_bit / 8;
        const shift = @truncate(u3, 7 - (output_bit % 8));
        const dark = avg < threshold;
        const bitcolor: u8 = if (dark) 1 else 0;
        bytes[byte] |= bitcolor << shift;
        output_bit += 1;
    }

    return try commands.printRasterBitImage(allocator, .normal, @truncate(u16, byte_width), @truncate(u16, height), bytes);
}
