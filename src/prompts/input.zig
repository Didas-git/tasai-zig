const std = @import("std");
const CSI = @import("../csi.zig");
const Terminal = @import("../terminal.zig").Terminal;

const assert = std.debug.assert;

pub fn InputPrompt(comptime T: type, comptime options: struct {
    message: []const u8,
    header: [2][]const u8 = .{ "?", "\u{1f5f8}" },
    footer: [2][]const u8 = .{ "\u{25b8}", "\u{00b7}" },
    accept_empty: bool = false,
    hide_cursor: bool = false,
    invisible: bool = false,
    password: bool = false,
    password_placeholder: u8 = '*',
    list: bool = false,
    list_separator: u8 = ',',
}) type {
    assert(options.message.len > 0);
    assert(T == []const u8 or switch (@typeInfo(T)) {
        .Int, .Float => true,
        else => false,
    });

    if (options.invisible) {
        assert(!options.password);
    }

    if (options.password) {
        assert(T == []const u8);
    }

    if (options.list) {
        assert(!options.password and !options.invisible and T == []const u8);
    }

    const ask = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s}<r> " ++ if (options.password) CSI.SGR.comptimeGet(.Dim) else ""), .{
        options.header[0],
        options.message,
        options.footer[0],
    });
    const done = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> {s} <d>{s}<r> "), .{
        options.header[1],
        options.message,
        options.footer[1],
    });

    return struct {
        var term: Terminal = undefined;
        var arr: std.ArrayList(u8) = undefined;

        pub fn run(allocator: std.mem.Allocator) !if (options.list) []T else T {
            term = try Terminal.init();
            try term.enableRawMode();
            arr = std.ArrayList(u8).init(allocator);
            defer arr.deinit();

            try term.stdout.lock(.none);
            defer term.stdout.unlock();

            const writer = term.stdout.writer();

            try writer.writeAll((if (comptime options.hide_cursor) CSI.CUH else "") ++ ask);

            const answer = try term.readInput([]const u8, handler);
            try term.deinit();

            try writer.writeAll(CSI.C_CHA(0) ++ CSI.C_EL(2));
            if (comptime options.password) {
                for (answer) |_| {
                    try arr.append(options.password_placeholder);
                }

                try writer.print(CSI.SGR.parseString(CSI.SGR.comptimeGet(.Not_Bold_Or_Dim) ++ "{s}<f:cyan>{s}<r>\n"), .{ done, try arr.toOwnedSlice() });
            } else if (comptime options.list) {
                var final = std.ArrayList([]const u8).init(allocator);
                defer final.deinit();

                var iterator = std.mem.split(u8, answer, &.{options.list_separator});
                while (iterator.next()) |part| {
                    try final.append(std.mem.trim(u8, part, " "));
                }

                for (answer) |char| {
                    if (char == options.list_separator) {
                        try arr.appendSlice(CSI.SGR.comptimeGet(.Default_Foreground_Color));
                        try arr.append(char);
                        try arr.appendSlice(CSI.SGR.comptimeGet(.Foreground_Cyan));
                    } else {
                        try arr.append(char);
                    }
                }

                try arr.appendSlice(CSI.SGR.comptimeGet(.Default_Foreground_Color));

                try writer.print("{s}" ++ CSI.SGR.comptimeGet(.Foreground_Cyan) ++ "{s}\n", .{ done, try arr.toOwnedSlice() });
                return try final.toOwnedSlice();
            } else if (comptime T != []const u8) {
                const num = switch (comptime @typeInfo(T)) {
                    .Int => try std.fmt.parseInt(T, answer, 10),
                    .Float => try std.fmt.parseFloat(T, answer),
                    else => unreachable,
                };

                if (comptime options.invisible) {
                    try writer.writeAll(done ++ "\n");
                } else {
                    try writer.print(CSI.SGR.parseString("{s}<f:cyan>{d}<r>\n"), .{ done, num });
                }

                return num;
            } else if (comptime options.invisible) {
                try writer.writeAll(done ++ "\n");
            } else {
                try writer.print(CSI.SGR.parseString("{s}<f:green>{s}<r>\n"), .{ done, answer });
            }

            return answer;
        }

        fn handler(byte: u8) !?[]const u8 {
            if (byte == std.ascii.control_code.etx) {
                try term.deinit();
                std.process.abort();
            }

            if (byte == std.ascii.control_code.del or byte == 177) {
                if (arr.popOrNull()) |_| {
                    try term.stdout.writeAll(CSI.C_CUB(1) ++ CSI.C_EL(0));
                }

                return null;
            }

            if (byte == std.ascii.control_code.lf or byte == std.ascii.control_code.cr) {
                if (comptime !options.accept_empty) {
                    if (arr.items.len <= 0) return null;
                }
                return try arr.toOwnedSlice();
            }

            if (comptime T != []const u8) {
                switch (comptime @typeInfo(T)) {
                    .Int => {
                        switch (byte) {
                            '0'...'9' => {
                                if (comptime !options.invisible) try term.stdout.writeAll(&.{byte});
                                try arr.append(byte);
                                return null;
                            },
                            else => return null,
                        }
                    },
                    .Float => {
                        switch (byte) {
                            '.', '0'...'9' => {
                                if (comptime !options.invisible) try term.stdout.writeAll(&.{byte});
                                try arr.append(byte);
                                return null;
                            },
                            else => return null,
                        }
                    },
                    else => unreachable,
                }
            } else if (std.ascii.isAlphanumeric(byte)) {
                if (comptime !options.invisible) {
                    if (comptime options.password) try term.stdout.writeAll(&.{options.password_placeholder}) else try term.stdout.writeAll(&.{byte});
                }
                try arr.append(byte);
                return null;
            }

            return null;
        }
    };
}
