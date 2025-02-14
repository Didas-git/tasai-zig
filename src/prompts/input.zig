const std = @import("std");
const CSI = @import("../csi.zig");
const Prompt = @import("./prompt.zig").Prompt;
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

    const ReturnType = if (comptime options.list) []T else T;

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
        const Self = @This();

        allocator: std.mem.Allocator,
        array: std.ArrayList(u8),

        pub fn run(allocator: std.mem.Allocator) !ReturnType {
            const arr = std.ArrayList(u8).init(allocator);
            defer arr.deinit();

            var self: Self = .{
                .allocator = allocator,
                .array = arr,
            };
            var p = prompt(&self);
            return try p.run();
        }

        fn prompt(self: *Self) Prompt([]const u8, ReturnType) {
            return .{
                .ptr = self,
                .vtable = &.{
                    .initialize = initialize,
                    .dispatch = dispatch,
                    .format = format,
                },
            };
        }

        fn initialize(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer) !void {
            _ = ctx;
            _ = term;

            try writer.writeAll((if (comptime options.hide_cursor) CSI.CUH else "") ++ ask);
        }

        fn dispatch(ctx: *anyopaque, term: *Terminal, byte: u8) !?[]const u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));

            if (byte == std.ascii.control_code.del or byte == 177) {
                if (self.array.popOrNull()) |_| {
                    try term.stdout.writeAll(CSI.C_CUB(1) ++ CSI.EL0);
                }

                return null;
            }

            if (byte == std.ascii.control_code.lf or byte == std.ascii.control_code.cr) {
                if (comptime !options.accept_empty) {
                    if (self.array.items.len <= 0) return null;
                }
                return try self.array.toOwnedSlice();
            }

            if (comptime T != []const u8) {
                switch (comptime @typeInfo(T)) {
                    .Int => {
                        switch (byte) {
                            '0'...'9' => {
                                if (comptime !options.invisible) try term.stdout.writeAll(&.{byte});
                                try self.array.append(byte);
                                return null;
                            },
                            else => return null,
                        }
                    },
                    .Float => {
                        switch (byte) {
                            '.', '0'...'9' => {
                                if (comptime !options.invisible) try term.stdout.writeAll(&.{byte});
                                try self.array.append(byte);
                                return null;
                            },
                            else => return null,
                        }
                    },
                    else => unreachable,
                }
            } else if (std.ascii.isAlphanumeric(byte) or byte == ' ' or byte == options.list_separator) {
                if (comptime !options.invisible) {
                    if (comptime options.password) try term.stdout.writeAll(&.{options.password_placeholder}) else try term.stdout.writeAll(&.{byte});
                }
                try self.array.append(byte);
                return null;
            }

            return null;
        }

        fn format(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, answer: []const u8) !ReturnType {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL2);

            if (comptime options.password) {
                for (answer) |_| {
                    try self.array.append(options.password_placeholder);
                }

                try writer.print(CSI.SGR.parseString(CSI.SGR.comptimeGet(.Not_Bold_Or_Dim) ++ "{s}<f:cyan>{s}<r>\n"), .{ done, try self.array.toOwnedSlice() });
            } else if (comptime options.list) {
                var final = std.ArrayList([]const u8).init(self.allocator);
                defer final.deinit();

                var iterator = std.mem.split(u8, answer, &.{options.list_separator});
                while (iterator.next()) |part| {
                    const real_part = std.mem.trim(u8, part, " ");
                    if (real_part.len == 0) continue;
                    try final.append(real_part);
                }

                for (answer) |char| {
                    if (char == options.list_separator) {
                        try self.array.appendSlice(CSI.SGR.comptimeGet(.Default_Foreground_Color));
                        try self.array.append(char);
                        try self.array.appendSlice(CSI.SGR.comptimeGet(.Foreground_Cyan));
                    } else {
                        try self.array.append(char);
                    }
                }

                try self.array.appendSlice(CSI.SGR.comptimeGet(.Default_Foreground_Color));

                try writer.print("{s}" ++ CSI.SGR.comptimeGet(.Foreground_Cyan) ++ "{s}\n", .{ done, try self.array.toOwnedSlice() });
                return try final.toOwnedSlice();
            } else if (comptime T != []const u8) {
                // TODO: Validate if the answer fits
                // into the given integer/float size
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
    };
}
