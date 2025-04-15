const std = @import("std");
const CSI = @import("../csi.zig");
const Terminal = @import("../Terminal.zig");
const Prompt = @import("../prompt.zig").Prompt;

const assert = std.debug.assert;

inline fn typeToString(comptime T: type) []const u8 {
    comptime {
        return switch (@typeInfo(T)) {
            .int => |int| std.fmt.comptimePrint("{s}{d}", .{ switch (int.signedness) {
                .unsigned => "u",
                .signed => "i",
            }, int.bits }),
            .float => |flt| std.fmt.comptimePrint("f{d}", .{flt.bits}),
            else => "default",
        };
    }
}

pub fn InputPrompt(comptime T: type, comptime options: struct {
    header: [3][]const u8 = .{ "?", "\u{1f5f8}", "\u{2715}" },
    footer: [2][]const u8 = .{ "\u{25b8}", "\u{00b7}" },
    accept_empty: bool = false,
    hide_cursor: bool = false,
    invisible: bool = false,
    password: bool = false,
    password_placeholder: u8 = '*',
    list: bool = false,
    list_separator: u8 = ',',
}) type {
    assert(T == []const u8 or switch (@typeInfo(T)) {
        .int, .float => true,
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

    const asking_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> "), .{options.header[0]});
    const done_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> "), .{options.header[1]});

    const asking_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s}<r> "), .{options.footer[0]});
    const done_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s}<r> "), .{options.footer[1]});

    const error_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:red><b>{s}<r><r>"), .{options.header[2]});
    const err_part_2 = std.fmt.comptimePrint(CSI.SGR.parseString("<d>(Invalid input for type: {s})<r>"), .{typeToString(T)});

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        array: std.ArrayList(u8),
        message: []const u8,

        var did_error: if (T == []const u8) void else bool = if (T == []const u8) {} else false;

        pub fn init(allocator: std.mem.Allocator, message: []const u8) Self {
            const arr = std.ArrayList(u8).init(allocator);

            return .{
                .allocator = allocator,
                .array = arr,
                .message = message,
            };
        }

        pub fn deinit(self: *Self) void {
            self.arr.deinit();
        }

        pub fn prompt(self: Self) Prompt([]const u8, ReturnType) {
            return .{
                .ptr = @ptrCast(@constCast(&self)),
                .vtable = &.{
                    .initialize = initialize,
                    .dispatch = dispatch,
                    .format = format,
                },
            };
        }

        fn initialize(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer) !void {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            try writer.writeAll((if (comptime options.hide_cursor) CSI.CUH else ""));
            try writer.writeAll(asking_header);
            try writer.writeAll(self.message);
            try writer.writeAll(asking_footer);
        }

        // Only use for `int` and `float` checking
        fn validateInput(input: []const u8) bool {
            switch (comptime @typeInfo(T)) {
                .int => {
                    _ = std.fmt.parseInt(T, input, 10) catch {
                        return false;
                    };
                    return true;
                },
                .float => {
                    _ = std.fmt.parseFloat(T, input) catch {
                        return false;
                    };
                    return true;
                },
                else => unreachable,
            }
        }

        fn dispatch(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, byte: u8) !?[]const u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));

            // Possible change:
            // Always reset the terminal with special case for passwords instead
            // however this requires some reworking of this function that im not willing to do rn
            if (comptime T != []const u8) {
                if (did_error) {
                    did_error = false;
                    try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL2 ++ asking_header);
                    try writer.writeAll(self.message);
                    try writer.print(asking_footer ++ "{s}", .{self.array.items});
                }
            }

            if (byte == std.ascii.control_code.del or byte == 177) {
                if (self.array.pop()) |_| {
                    try term.stdout.writeAll(CSI.C_CUB(1) ++ CSI.EL0);
                }

                return null;
            }

            if (byte == std.ascii.control_code.lf or byte == std.ascii.control_code.cr) {
                if (comptime !options.accept_empty) {
                    if (self.array.items.len <= 0) return null;
                }

                if (comptime T != []const u8) {
                    if (!validateInput(self.array.items)) {
                        did_error = true;
                        try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL2 ++ error_header);
                        try writer.writeAll(self.message);
                        try writer.print(asking_footer ++ "{s} " ++ err_part_2, .{self.array.items});
                        return null;
                    }
                }
                return try self.array.toOwnedSlice();
            }

            if (comptime T != []const u8) {
                switch (comptime @typeInfo(T)) {
                    .int => {
                        switch (byte) {
                            '0'...'9' => {
                                if (comptime !options.invisible) try term.stdout.writeAll(&.{byte});
                                try self.array.append(byte);
                                return null;
                            },
                            else => return null,
                        }
                    },
                    .float => {
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

        fn printDone(self: *Self, writer: std.fs.File.Writer) !void {
            try writer.writeAll(done_header);
            try writer.writeAll(self.message);
            try writer.writeAll(done_footer);
        }

        fn format(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, answer: []const u8) !ReturnType {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL2);

            if (comptime options.password) {
                for (answer) |_| {
                    try self.array.append(options.password_placeholder);
                }
                try printDone(self, writer);
                try writer.print(CSI.SGR.parseString(CSI.SGR.Attribute.not_bold_or_dim.str() ++ "<f:cyan>{s}<r>\n"), .{try self.array.toOwnedSlice()});
            } else if (comptime options.list) {
                var final = std.ArrayList([]const u8).init(self.allocator);
                defer final.deinit();

                var iterator = std.mem.splitScalar(u8, answer, options.list_separator);
                while (iterator.next()) |part| {
                    const real_part = std.mem.trim(u8, part, " ");
                    if (real_part.len == 0) continue;
                    try final.append(real_part);
                }

                for (answer) |char| {
                    if (char == options.list_separator) {
                        try self.array.appendSlice(CSI.SGR.Attribute.default_foreground_color.str());
                        try self.array.append(char);
                        try self.array.appendSlice(CSI.SGR.Attribute.foreground_cyan.str());
                    } else {
                        try self.array.append(char);
                    }
                }

                try self.array.appendSlice(CSI.SGR.Attribute.default_foreground_color.str());

                try printDone(self, writer);
                try writer.print(CSI.SGR.Attribute.foreground_cyan.str() ++ "{s}\n", .{try self.array.toOwnedSlice()});
                return try final.toOwnedSlice();
            } else if (comptime T != []const u8) {
                const num = switch (comptime @typeInfo(T)) {
                    .int => try std.fmt.parseInt(T, answer, 10),
                    .float => try std.fmt.parseFloat(T, answer),
                    else => unreachable,
                };

                if (comptime options.invisible) {
                    try printDone(self, writer);
                    try writer.writeByte('\n');
                } else {
                    try printDone(self, writer);
                    try writer.print(CSI.SGR.parseString("<f:cyan>{d}<r>\n"), .{num});
                }

                return num;
            } else if (comptime options.invisible) {
                try printDone(self, writer);
                try writer.writeByte('\n');
            } else {
                try printDone(self, writer);
                try writer.print(CSI.SGR.parseString("<f:green>{s}<r>\n"), .{answer});
            }

            return answer;
        }
    };
}
