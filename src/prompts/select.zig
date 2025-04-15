const std = @import("std");
const CSI = @import("../csi.zig");
const Terminal = @import("../Terminal.zig");
const Prompt = @import("../prompt.zig").Prompt;

fn isKV(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            if (s.is_tuple) return false;
            if (s.fields.len != 2) return false;
            if (!std.mem.eql(u8, "name", s.fields[0].name)) return false;
            if (!std.mem.eql(u8, "value", s.fields[1].name)) return false;
            return true;
        },
        else => return false,
    }
}

pub fn SelectPrompt(
    comptime T: type,
    comptime options: struct {
        limit: u8 = 10,
        header: [2][]const u8 = .{ "?", "\u{1f5f8}" },
        footer: [2][]const u8 = .{ "...", "\u{00b7}" },
        arrow: []const u8 = "\u{25b8}",
        multiple: bool = false,
        allow_empty: bool = false,
        multiple_marker: []const u8 = "\u{1f5f8}",
    },
) type {
    std.debug.assert(options.limit > 1);
    std.debug.assert(T == []const u8 or isKV(T));

    const asking_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> "), .{options.header[0]});
    const done_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> "), .{options.header[1]});

    const asking_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s}<r> "), .{options.footer[0]});
    const done_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s}<r> "), .{options.footer[1]});

    const answer_template = CSI.SGR.parseString("<f:cyan>{s}<r>\n");

    const V = @Vector(2, usize);
    const _ReturnType = if (comptime isKV(T)) @typeInfo(T).@"struct".fields[1].type else T;
    const ReturnType = if (comptime options.multiple) []_ReturnType else _ReturnType;

    return struct {
        const Self = @This();

        allocator: if (options.multiple) std.mem.Allocator else void,
        selected_choices: if (options.multiple) std.AutoHashMap(usize, void) else void = if (options.multiple) undefined else {},
        message: []const u8,
        choices: []const T,
        current_block: V,
        limit: usize,
        pos: usize = 0,

        pub const init = if (options.multiple) initWithAllocator else initWithoutAllocator;

        fn initWithoutAllocator(message: []const u8, choices: []const T) Self {
            return .{
                .allocator = {},
                .selected_choices = {},
                .message = message,
                .choices = choices,
                .current_block = .{ 0, if (choices.len <= options.limit) choices.len else options.limit },
                .limit = if (choices.len < options.limit) choices.len else options.limit - 1,
            };
        }

        fn initWithAllocator(allocator: std.mem.Allocator, message: []const u8, choices: []const T) Self {
            const hash_map = std.AutoHashMap(usize, void).init(allocator);

            return .{
                .allocator = allocator,
                .selected_choices = hash_map,
                .message = message,
                .choices = choices,
                .current_block = .{ 0, if (choices.len <= options.limit) choices.len else options.limit },
                .limit = if (choices.len < options.limit) choices.len else options.limit - 1,
            };
        }

        pub fn prompt(self: *Self) Prompt(if (options.multiple) bool else T, ReturnType) {
            return .{
                .ptr = self,
                .vtable = &.{
                    .initialize = initialize,
                    .dispatch = if (comptime options.multiple) dispatchMultiple else dispatchSingle,
                    .format = format,
                },
            };
        }

        fn initialize(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer) !void {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            try writer.writeAll(CSI.CUH ++ asking_header);
            try writer.writeAll(self.message);
            try writer.writeAll(asking_footer ++ CSI.C_CNL(1));

            if (comptime options.multiple) {
                try self.renderMultiple(writer);
            } else {
                try self.renderChoices(writer);
            }
        }

        fn dispatchMultiple(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, byte: u8) !?bool {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            return switch (byte) {
                std.ascii.control_code.lf, std.ascii.control_code.cr => {
                    if (comptime !options.allow_empty) {
                        if (self.selected_choices.count() <= 0) return null;
                    }

                    return true;
                },
                ' ' => {
                    if (!self.selected_choices.remove(self.pos)) {
                        try self.selected_choices.put(self.pos, {});
                    }
                    try self.clearChoices(writer);
                    try self.renderMultiple(writer);

                    return null;
                },
                252 => {
                    try self.move(-1);
                    try self.clearChoices(writer);
                    try self.renderMultiple(writer);
                    return null;
                },
                253 => {
                    try self.move(1);
                    try self.clearChoices(writer);
                    try self.renderMultiple(writer);
                    return null;
                },
                254 => {
                    self.pos = self.choices.len - 1;
                    self.current_block = .{ self.choices.len - (if (self.choices.len <= options.limit) self.choices.len else options.limit), self.choices.len };
                    try self.clearChoices(writer);
                    try self.renderMultiple(writer);
                    return null;
                },
                255 => {
                    self.pos = 0;
                    self.current_block = .{ 0, if (self.choices.len <= options.limit) self.choices.len else options.limit };
                    try self.clearChoices(writer);
                    try self.renderMultiple(writer);
                    return null;
                },
                else => null,
            };
        }

        fn dispatchSingle(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, byte: u8) !?T {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            return switch (byte) {
                std.ascii.control_code.lf, std.ascii.control_code.cr => self.choices[self.pos],
                252 => {
                    try self.move(-1);
                    try self.clearChoices(writer);
                    try self.renderChoices(writer);
                    return null;
                },
                253 => {
                    try self.move(1);
                    try self.clearChoices(writer);
                    try self.renderChoices(writer);
                    return null;
                },
                254 => {
                    self.pos = self.choices.len - 1;
                    self.current_block = .{ self.choices.len - (if (self.choices.len <= options.limit) self.choices.len else options.limit), self.choices.len };
                    try self.clearChoices(writer);
                    try self.renderChoices(writer);
                    return null;
                },
                255 => {
                    self.pos = 0;
                    self.current_block = .{ 0, if (self.choices.len <= options.limit) self.choices.len else options.limit };
                    try self.clearChoices(writer);
                    try self.renderChoices(writer);
                    return null;
                },
                else => null,
            };
        }

        fn printDone(self: *Self, writer: std.fs.File.Writer) !void {
            try writer.writeAll(done_header);
            try writer.writeAll(self.message);
            try writer.writeAll(done_footer);
        }

        fn format(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, answer: if (options.multiple) bool else T) !ReturnType {
            const self: *Self = @ptrCast(@alignCast(ctx));

            _ = term;

            const to_clear = if (self.choices.len < options.limit) self.choices.len + 1 else options.limit;
            var buf: [16]u8 = undefined;
            try writer.writeAll(CSI.CPL(&buf, to_clear));
            try writer.writeAll(CSI.ED0);

            if (comptime options.multiple) {
                var array_to_print = std.ArrayList([]const u8).init(self.allocator);
                var array_to_return = std.ArrayList(_ReturnType).init(self.allocator);
                defer array_to_print.deinit();
                defer array_to_return.deinit();
                defer self.selected_choices.deinit();

                for (self.choices, 0..) |choice, x| {
                    if (self.selected_choices.contains(x)) {
                        try array_to_print.append(if (comptime isKV(T)) choice.name else choice);
                        try array_to_return.append(if (comptime isKV(T)) choice.value else choice);
                    }
                }

                try printDone(self, writer);
                try writer.print(answer_template, .{try array_to_print.toOwnedSlice()});
                return try array_to_return.toOwnedSlice();
            } else if (comptime isKV(T)) {
                try printDone(self, writer);
                try writer.print(answer_template, .{answer.name});
                return answer.value;
            } else {
                try printDone(self, writer);
                try writer.print(answer_template, .{answer});
                return answer;
            }
        }

        fn move(self: *Self, x: isize) !void {
            if (self.pos == 0 and x == -1) return;
            if (self.pos == self.choices.len - 1 and x >= 1) return;
            self.pos = @intCast(@as(isize, @intCast(self.pos)) + x);

            if (self.pos < self.current_block[0]) {
                self.current_block = self.current_block - @as(V, @splat(1));
            } else if (self.pos + 1 > self.current_block[1]) self.current_block = self.current_block + @as(V, @splat(1));
        }

        fn clearChoices(self: *Self, writer: std.fs.File.Writer) !void {
            var buf: [16]u8 = undefined;
            try writer.writeAll(CSI.CPL(&buf, self.limit));
            try writer.writeAll(CSI.ED0);
        }

        fn renderChoices(self: *Self, writer: std.fs.File.Writer) !void {
            const selected = comptime std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan>{s} <u>{s}<r><r>"), .{ options.arrow, "{s}" });

            const block_start, const block_end = self.current_block;

            for (self.choices[block_start..block_end], block_start..) |choice, x| {
                const c = if (comptime isKV(T)) choice.name else choice;
                if (x == self.pos) {
                    try writer.print(selected, .{c});
                } else {
                    try writer.print("  {s}", .{c});
                }

                if (x != (self.limit + block_start)) {
                    try writer.writeAll(CSI.C_CNL(1));
                }
            }
        }

        fn renderMultiple(self: *Self, writer: std.fs.File.Writer) !void {
            const green_marker = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green>{s}<r>"), .{options.multiple_marker});
            const dim_marker = std.fmt.comptimePrint(CSI.SGR.parseString("<d>{s}<r>"), .{options.multiple_marker});
            const selected = CSI.SGR.parseString("{s} <f:cyan><u>{s}<r><r>");

            const block_start, const block_end = self.current_block;

            for (self.choices[block_start..block_end], block_start..) |choice, x| {
                const c = if (comptime isKV(T)) choice.name else choice;
                const marker = if (self.selected_choices.contains(x)) green_marker else dim_marker;

                if (x == self.pos) {
                    try writer.print(selected, .{ marker, c });
                } else {
                    try writer.print("{s} {s}", .{ marker, c });
                }

                if (x != options.limit - 1 + block_start) {
                    try writer.writeAll(CSI.C_CNL(1));
                }
            }
        }
    };
}
