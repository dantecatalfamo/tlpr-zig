const std = @import("std");
const mem = std.mem;
const zigimg = @import("zigimg");
const commands = @import("./commands.zig");

pub fn imageToBitRaster(allocator: std.mem.Allocator, path: []const u8, threshold: Threshold) ![]u8 {
    const image = try zigimg.Image.fromFilePath(allocator, path);
    defer image.deinit();

    var rng = std.rand.DefaultPrng.init(0).random();

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

    var input_bit: u64 = 0;
    var output_bit: u64 = 0;

    while (iter.next()) |color| : (input_bit += 1) {
        if (extra_bits != 8 and input_bit != 0 and input_bit % width == 0) {
            output_bit += extra_bits;
        }
        const th: u8 = blk: {
            if (threshold == .value) {
                break :blk threshold.value;
            }
            const max = threshold.range.max;
            const min = threshold.range.min;
            const diff = max - min;
            const rand = rng.int(u8);
            break :blk (rand % diff) + min;
        };
        const int_val = color.toIntegerColor8();
        const avg = @truncate(u8, (@as(u16, int_val.R) + int_val.G + int_val.B) / 3);
        const dark = avg < th;
        const bitcolor: u8 = if (dark) 1 else 0;
        const byte = output_bit / 8;
        const shift = @truncate(u3, 7 - (output_bit % 8));
        bytes[byte] |= bitcolor << shift;
        output_bit += 1;
    }

    return try commands.printRasterBitImage(allocator, .normal, @truncate(u16, byte_width), @truncate(u16, height), bytes);
}

pub fn parseThreshold(input: []const u8) !Threshold {
    if (mem.indexOf(u8, input, "-") != null) {
        var split = mem.split(u8, input, "-");
        const min_input = split.next().?;
        const max_input = split.next().?;
        const min = try std.fmt.parseInt(u8, min_input, 10);
        const max = try std.fmt.parseInt(u8, max_input, 10);
        if (min >= max) {
            return error.InvalidRange;
        }
        image_threshold = .{
            .range = .{
                .min = min,
                .max = max,
            },
        };
    } else {
        image_threshold = .{
            .value = try std.fmt.parseInt(u8, input, 10)
        };
    }
}

pub const Threshold = union(enum) {
    value: u8,
    range: struct {
        min: u8,
        max: u8,
    },
};
