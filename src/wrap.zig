const std = @import("std");

pub fn wordWrap(line: []u8, width: u8) void {
    var last_space: usize = 0;
    var last_newline: usize = 0;

    for (line) |char, idx| {
        const cur_line = idx - last_newline;
        if (std.ascii.isSpace(char)) {
            last_space = idx;
        }
        if (char == '\n') {
            last_newline = idx;
        }
        if (cur_line == width-2) {
            last_newline = idx;
            line[last_space] = '\n';
        }
    }
}

test "word wrap" {
    var allocator = std.testing.allocator;
    const text = "hello this is a very long bunch of text I think this should serve as a good test, hopefully I'm able to catch some bugs using this since\nit's very long also hello\nthis is a nice day don't you think? Very cool and good, goodbye!";
    var txt = try allocator.dupe(u8, text);
    defer allocator.free(txt);
    wordWrap(txt, 30);
    std.debug.print("{s}\n", .{txt});
}
