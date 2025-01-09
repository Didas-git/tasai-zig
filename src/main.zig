const std = @import("std");
const SGR = @import("./sgr.zig");
const hyperlink = @import("./osc.zig").hyperlink;

pub fn main() !void {
    // std.debug.print("{s}: {s}!\n", .{
    //     SGR.verboseFormat("Test", &.{
    //         .{ .attribute = .Double_Underline },
    //         .{ .color = .{ .underline = .{ .@"24bit" = .{ .r = 30, .g = 255, .b = 120 } } } },
    //     }, &.{
    //         .{ .attribute = .Not_Underlined },
    //         .{ .attribute = .Default_Underline_Color },
    //     }),
    //     SGR.verboseFormat(std.fmt.comptimePrint("{s} {s}", .{
    //         SGR.verboseFormat("Hello", &.{
    //             .{ .color = .{ .foreground = .{ .@"24bit" = .{ .r = 255, .g = 0, .b = 239 } } } },
    //         }, &.{
    //             .{ .attribute = .Default_Foreground_Color },
    //         }),
    //         SGR.verboseFormat("World", &.{
    //             .{ .attribute = .Bold },
    //             .{ .color = .{ .foreground = .{ .@"8bit" = 33 } } },
    //         }, &.{
    //             .{ .attribute = .Not_Bold_Or_Dim },
    //             .{ .attribute = .Default_Foreground_Color },
    //         }),
    //     }), &.{.{ .color = .{ .background = .{ .normal = .Black } } }}, &.{.{ .attribute = .Default_Background_Color }}),
    // });

    // const str = SGR.parseString("<du><u:30,255,120>Test<r><r>: <b:black><f:#ff00ef>Hello<r> <f:33><b>World<r><r><r>!");
    // std.debug.print("{s}\n", .{str});
    // std.debug.print("{s}\n", .{SGR.parseString("This: <b><f:red>\\<<r> should print without issues<r>")});

    // std.debug.print("{s}\n", .{hyperlink("My link", "https://google.com/", null)});
    // const Params = struct { id: u8 };
    // std.debug.print("{s}\n", .{hyperlink("My link", "https://google.com/", Params{ .id = 1 })});
    std.debug.print("{s}\n", .{SGR.parseString("<b:hsi:0,0,0><f:hsv:0,255,255>Hello<r> <f:hsl:0.1,1,0.5>World<r><r>")});
}
