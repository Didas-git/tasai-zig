const std = @import("std");
const SGR = @import("./sgr.zig");
const hyperlink = @import("./osc.zig").hyperlink;

pub fn main() !void {
    std.debug.print("{s}: {s}!\n", .{
        SGR.format("Test", &.{
            .{ .Attribute = .Double_Underline },
            .{ .Color = .{ .Underline = .{ .@"24bit" = .{ .r = 30, .g = 255, .b = 120 } } } },
        }, &.{
            .{ .Attribute = .Not_Underlined },
            .{ .Attribute = .Default_Underline_Color },
        }),
        SGR.format(std.fmt.comptimePrint("{s} {s}", .{
            SGR.format("Hello", &.{
                .{ .Color = .{ .Foreground = .{ .@"24bit" = .{ .r = 255, .g = 0, .b = 239 } } } },
            }, &.{
                .{ .Attribute = .Default_Foreground_Color },
            }),
            SGR.format("World", &.{
                .{ .Attribute = .Bold },
                .{ .Color = .{ .Foreground = .{ .@"8bit" = 33 } } },
            }, &.{
                .{ .Attribute = .Not_Bold_Or_Dim },
                .{ .Attribute = .Default_Foreground_Color },
            }),
        }), &.{.{ .Color = .{ .Background = .{ .Normal = .Black } } }}, &.{.{ .Attribute = .Default_Background_Color }}),
    });

    const str = SGR.Parser.parse("<du><u:30,255,120>Test<r><r>: <b:black><f:255,0,239>Hello<r> <f:33><b>World<r><r><r>!");
    std.debug.print("{s}\n", .{str});
    std.debug.print("{s}\n", .{SGR.Parser.parse("This: <b><f:red>\\<<r> should print without issues<r>")});

    std.debug.print("{s}\n", .{hyperlink("My link", "https://google.com/", null)});
    const Params = struct { id: u8 };
    std.debug.print("{s}\n", .{hyperlink("My link", "https://google.com/", Params{ .id = 1 })});
}
