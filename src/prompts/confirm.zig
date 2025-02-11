const std = @import("std");
const CSI = @import("../csi.zig");
const Cursor = @import("../Cursor.zig");

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

pub fn ConfirmPrompt(comptime options: struct {
    message: []const u8,
    allow_long_answer: bool = false,
}) type {
    if (options.message.len == 0) {
        @compileError("You need to provide a question to ask");
    }

    const parsed_question = std.fmt.comptimePrint(CSI.SGR.parseString("{s} <d>(y/N) ><r> "), .{options.message});

    const y_table: []const []const u8 = divideIntoPossibilities("yes") ++ divideIntoPossibilities("true");
    const n_table: []const []const u8 = divideIntoPossibilities("no") ++ divideIntoPossibilities("false");

    return struct {
        pub fn run(allocator: std.mem.Allocator) !bool {
            const std_out = std.io.getStdOut();
            const reader_interface = std.io.getStdIn().reader();

            try std_out.lock(.none);
            defer std_out.unlock();

            const writer = std_out.writer();
            var cursor: Cursor = .{};

            try writer.writeAll(cursor.hide());
            try writer.print(parsed_question, .{});

            const possible_answer = try reader_interface.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096);
            try writer.writeAll(cursor.show());

            if (possible_answer) |answer| {
                if (options.allow_long_answer) {
                    if (answer.len > 1) {
                        for (answer) |*char| {
                            char.* = std.ascii.toLower(char.*);
                        }

                        if (contains(u8, y_table, answer)) return true;
                        if (contains(u8, n_table, answer)) return false;
                        return error.InvalidAnswer;
                    }
                } else if (answer.len != 1) return error.InvalidAnswerLength;

                return switch (answer[0]) {
                    'y', 'Y' => true,
                    'n', 'N' => false,
                    else => error.InvalidAnswer,
                };
            }

            return error.NoAnswer;
        }
    };
}
