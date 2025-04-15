const std = @import("std");
const CSI = @import("../csi.zig");
const Terminal = @import("../Terminal.zig");
const Prompt = @import("../prompt.zig").Prompt(bool, void);

pub fn ConfirmPrompt(comptime options: struct {
    default_value: bool = false,
    toggle: bool = false,
    toggle_names: [2][]const u8 = .{ "No", "Yes" },
    header: [2][]const u8 = .{ "?", "\u{1f5f8}" },
    footer: [2][]const u8 = .{ "\u{25b8}", "\u{00b7}" },
}) type {
    const visual_options = if (options.default_value) "(Y/n)" else "(y/N)";

    const asking_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> "), .{options.header[0]});
    const done_header = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> "), .{options.header[1]});
    const asking_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s} {s}<r> <f:cyan>{s}<r>"), .{
        visual_options,
        options.footer[0],
        if (options.default_value) "true" else "false",
    });
    const done_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s} {s}<r> "), .{
        visual_options,
        options.footer[1],
    });

    const toggle_footer = std.fmt.comptimePrint(CSI.SGR.parseString(" <d>{s}<r> "), .{
        options.footer[1],
    });

    const toggle_no = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><u>{s}<r><r> / {s}"), .{ options.toggle_names[0], options.toggle_names[1] });
    const toggle_yes = std.fmt.comptimePrint(CSI.SGR.parseString("{s} / <f:cyan><u>{s}<r><r>"), .{ options.toggle_names[0], options.toggle_names[1] });

    return struct {
        const Self = @This();

        message: []const u8,

        var current: if (options.toggle) bool else void = if (options.toggle) false else {};

        pub fn prompt(comptime self: Self) Prompt {
            return .{
                .ptr = @ptrCast(@constCast(&self)),
                .vtable = &.{
                    .initialize = initialize,
                    .dispatch = dispatch,
                    .format = format,
                },
            };
        }

        fn printAskingToggle(self: *Self, writer: std.fs.File.Writer) !void {
            try writer.writeAll(asking_header);
            try writer.writeAll(self.message);
            try writer.writeAll(toggle_footer);
        }

        fn initialize(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer) !void {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            if (comptime options.toggle) {
                try writer.writeAll(CSI.CUH);
                try printAskingToggle(self, writer);
                try writer.writeAll(toggle_no);
            } else {
                try writer.writeAll(CSI.CUH ++ asking_header);
                try writer.writeAll(self.message);
                try writer.writeAll(asking_footer);
            }
        }

        fn dispatch(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, byte: u8) !?bool {
            _ = term;
            const self: *Self = @ptrCast(@alignCast(ctx));

            if (comptime options.toggle) {
                return switch (byte) {
                    std.ascii.control_code.lf, std.ascii.control_code.cr => current,
                    254 => {
                        if (!current) {
                            try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL0);
                            try printAskingToggle(self, writer);
                            try writer.writeAll(toggle_yes);
                            current = true;
                        }
                        return null;
                    },
                    255 => {
                        if (current) {
                            try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL0);
                            try printAskingToggle(self, writer);
                            try writer.writeAll(toggle_no);
                            current = false;
                        }
                        return null;
                    },
                    else => null,
                };
            } else {
                return switch (byte) {
                    std.ascii.control_code.lf, std.ascii.control_code.cr => options.default_value,

                    'y', 'Y' => true,
                    'n', 'N' => false,
                    else => null,
                };
            }
        }

        fn format(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, answer: bool) !void {
            _ = term;

            const self: *Self = @ptrCast(@alignCast(ctx));

            try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL2);

            if (comptime options.toggle) {
                try writer.writeAll(done_header);
                try writer.writeAll(self.message);
                try writer.writeAll(toggle_footer);
                try writer.print("{s}\n", .{if (current) toggle_yes else toggle_no});
            } else {
                try writer.writeAll(done_header);
                try writer.writeAll(self.message);
                try writer.writeAll(done_footer);
                try writer.print(CSI.SGR.parseString("<f:green>{any}<r>\n"), .{answer});
            }
        }
    };
}
