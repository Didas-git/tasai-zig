const std = @import("std");
const CSI = @import("../csi.zig");
const Cursor = @import("../Cursor.zig");
const RawTerminal = @import("../terminal.zig").RawTerminal;

pub fn SelectPrompt(comptime T: type, comptime options: struct {
    message: []const u8,
    choices: []const T,
    header: [2][]const u8 = .{ "?", "\u{2714}" },
    footer: [2][]const u8 = .{ "...", "\u{00b7}" },
    arrow: []const u8 = "\u{25b8}",
}) type {
    if (options.message.len == 0) {
        @compileError("You need to provide a question to ask");
    }

    const parsed_question_before = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s}<r>"), .{
        options.header[0],
        options.message,
        options.footer[0],
    });
    const parsed_question_after = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> {s} <d>{s}<r> "), .{
        options.header[1],
        options.message,
        options.footer[1],
    });

    return struct {
        var term: RawTerminal(true) = undefined;
        var i: usize = 0;
        pub fn run(allocator: std.mem.Allocator) !T {
            term = try RawTerminal(true).init(allocator);

            try term.stdout.lock(.none);
            defer term.stdout.unlock();

            const writer = term.stdout.writer();

            try writer.writeAll(CSI.CUH ++ parsed_question_before ++ CSI.C_CNL(1));
            try render();

            const answer = try term.readInput(T, handler);
            try term.deinit();

            try writer.writeAll(CSI.C_CPL(options.choices.len) ++ CSI.C_ED(0));
            try writer.print(CSI.SGR.parseString("{s}<f:cyan>{s}<r>\n"), .{ parsed_question_after, answer });

            return answer;
        }

        fn handler(byte: u8) !?T {
            return switch (byte) {
                std.ascii.control_code.lf, std.ascii.control_code.cr => options.choices[i],
                252 => {
                    move(-1);
                    try clearChoices();
                    try render();
                    return null;
                },
                253 => {
                    move(1);
                    try clearChoices();
                    try render();
                    return null;
                },
                254 => {
                    i = 0;
                    try clearChoices();
                    try render();
                    return null;
                },
                255 => {
                    i = options.choices.len - 1;
                    try clearChoices();
                    try render();
                    return null;
                },
                else => null,
            };
        }

        fn move(x: isize) void {
            if (i == 0 and x == -1) return;
            if (i == options.choices.len - 1 and x >= 1) return;
            i = @intCast(@as(isize, @intCast(i)) + x);
        }

        fn clearChoices() !void {
            try term.stdout.writeAll(CSI.C_CPL(options.choices.len - 1) ++ CSI.C_ED(0));
        }

        fn render() !void {
            const selected = comptime std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan>{s} <u>{s}<r><r>"), .{ options.arrow, "{s}" });
            const writer = term.stdout.writer();

            for (options.choices, 0..) |choice, x| {
                if (x == i) {
                    try writer.print(selected, .{choice});
                } else {
                    try writer.print("  {s}", .{choice});
                }

                if (x != options.choices.len - 1) {
                    try writer.writeAll(CSI.C_CNL(1));
                }
            }
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
