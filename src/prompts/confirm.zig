const std = @import("std");
const CSI = @import("../csi.zig");
const Cursor = @import("../Cursor.zig");
const RawTerminal = @import("../terminal.zig").RawTerminal;

pub fn ConfirmPrompt(comptime options: struct {
    message: []const u8,
    default_value: bool = false,
    header: [2][]const u8 = .{ "?", "\u{1f5f8}" },
    footer: [2][]const u8 = .{ "\u{25b8}", "\u{00b7}" },
}) type {
    std.debug.assert(options.message.len > 0);

    const visual_options = if (options.default_value) "(Y/n)" else "(y/N)";
    const parsed_question_before = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s} {s}<r> <f:cyan>{s}<r>"), .{
        options.header[0],
        options.message,
        visual_options,
        options.footer[0],
        if (options.default_value) "true" else "false",
    });
    const parsed_question_after = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> {s} <d>{s} {s}<r> "), .{
        options.header[1],
        options.message,
        visual_options,
        options.footer[1],
    });

    return struct {
        pub fn run(allocator: std.mem.Allocator) !bool {
            const term = try RawTerminal(true).init(allocator);

            try term.stdout.lock(.none);
            defer term.stdout.unlock();

            const writer = term.stdout.writer();

            try writer.writeAll(CSI.CUH ++ parsed_question_before);

            const answer = try term.readInput(bool, handler);
            try term.deinit();

            try writer.writeAll(CSI.C_CHA(0) ++ CSI.C_EL(2));
            try writer.print(CSI.SGR.parseString("{s}<f:green>{s}<r>\n"), .{ parsed_question_after, if (answer) "true" else "false" });

            return answer;
        }

        fn handler(byte: u8) !?bool {
            return switch (byte) {
                std.ascii.control_code.lf, std.ascii.control_code.cr => options.default_value,
                'y', 'Y' => true,
                'n', 'N' => true,
                else => null,
            };
        }
    };
}

fn contains(comptime T: type, table: []const []const T, search: []const T) bool {
    for (table) |item| {
        if (std.mem.eql(T, item, search)) return true;
    }

    return false;
}

inline fn divideIntoPossibilities(comptime word: []const u8) []const []const u8 {
    comptime {
        var buf: []const []const u8 = &.{};
        for (word, 1..) |_, i| {
            buf = buf ++ .{word[0..i]};
        }

        return buf;
    }
}
