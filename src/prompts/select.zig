const std = @import("std");
const CSI = @import("../csi.zig");
const RawTerminal = @import("../terminal.zig").RawTerminal;

fn isKV(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Struct => |s| {
            if (s.is_tuple) return false;
            if (s.fields.len != 2) return false;
            if (!std.mem.eql(u8, "name", s.fields[0].name)) return false;
            if (!std.mem.eql(u8, "value", s.fields[1].name)) return false;
            return true;
        },
        else => return false,
    }
}

pub fn SelectPrompt(comptime T: type, comptime options: struct {
    message: []const u8,
    choices: []const T,
    limit: u8 = 10,
    header: [2][]const u8 = .{ "?", "\u{1f5f8}" },
    footer: [2][]const u8 = .{ "...", "\u{00b7}" },
    arrow: []const u8 = "\u{25b8}",
}) type {
    std.debug.assert(options.message.len > 0);
    std.debug.assert(options.choices.len > 0);
    std.debug.assert(options.limit > 1);
    std.debug.assert(T == []const u8 or isKV(T));

    const ask = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s}<r>"), .{
        options.header[0],
        options.message,
        options.footer[0],
    });
    const done = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> {s} <d>{s}<r> "), .{
        options.header[1],
        options.message,
        options.footer[1],
    });

    const V = @Vector(2, usize);
    const ReturnType = if (isKV(T)) @typeInfo(T).Struct.fields[1].type else T;

    return struct {
        var term: RawTerminal(true) = undefined;
        var i: usize = 0;
        var current_block: V = .{ 0, if (options.choices.len <= options.limit) options.choices.len else options.limit };

        pub fn run(allocator: std.mem.Allocator) !ReturnType {
            term = try RawTerminal(true).init(allocator);

            try term.stdout.lock(.none);
            defer term.stdout.unlock();

            const writer = term.stdout.writer();

            try writer.writeAll(CSI.CUH ++ ask ++ CSI.C_CNL(1));
            try render();

            const answer = try term.readInput(T, handler);
            try term.deinit();

            const to_clear = if (comptime options.choices.len < options.limit) options.choices.len + 1 else options.limit;
            try writer.writeAll(CSI.C_CPL(to_clear) ++ CSI.C_ED(0));
            if (comptime isKV(T)) {
                try writer.print(CSI.SGR.parseString("{s}<f:cyan>{s}<r>\n"), .{ done, answer.name });
                return answer.value;
            } else {
                try writer.print(CSI.SGR.parseString("{s}<f:cyan>{s}<r>\n"), .{ done, answer });
                return answer;
            }
        }

        fn handler(byte: u8) !?T {
            return switch (byte) {
                std.ascii.control_code.lf, std.ascii.control_code.cr => options.choices[i],
                252 => {
                    try move(-1);
                    return null;
                },
                253 => {
                    try move(1);
                    return null;
                },
                254 => {
                    i = options.choices.len - 1;
                    try clearChoices();
                    try render();
                    return null;
                },
                255 => {
                    i = 0;
                    try clearChoices();
                    try render();
                    return null;
                },
                else => null,
            };
        }

        fn move(x: isize) !void {
            if (i == 0 and x == -1) return;
            if (i == options.choices.len - 1 and x >= 1) return;
            i = @intCast(@as(isize, @intCast(i)) + x);

            if (i < current_block[0]) {
                current_block = current_block - @as(V, @splat(1));
            } else if (i + 1 > current_block[1]) current_block = current_block + @as(V, @splat(1));

            try clearChoices();
            try render();
        }

        fn clearChoices() !void {
            const to_clear = if (comptime options.choices.len < options.limit) options.choices.len else options.limit - 1;
            try term.stdout.writeAll(CSI.C_CPL(to_clear) ++ CSI.C_ED(0));
        }

        fn render() !void {
            const selected = comptime std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan>{s} <u>{s}<r><r>"), .{ options.arrow, "{s}" });
            const writer = term.stdout.writer();

            const block_start, const block_end = current_block;

            for (options.choices[block_start..block_end], block_start..) |choice, x| {
                const c = if (comptime isKV(T)) choice.name else choice;
                if (x == i) {
                    try writer.print(selected, .{c});
                } else {
                    try writer.print("  {s}", .{c});
                }

                if (x != options.limit - 1 + block_start) {
                    try writer.writeAll(CSI.C_CNL(1));
                }
            }
        }
    };
}
