const std = @import("std");
const CSI = @import("./csi.zig");

const Cursor = @This();

hidden: bool = false,

pub fn hide(self: *Cursor) []const u8 {
    self.hidden = true;
    return CSI.CUH;
}

pub fn show(self: *Cursor) []const u8 {
    self.hidden = false;
    return CSI.CUS;
}

pub fn move(x: isize, y: isize) [2][]const u8 {
    const x_buf: [16]u8 = undefined;
    const y_buf: [16]u8 = undefined;
    const x_pos = if (x == 0) "" else if (x < 0) CSI.CUB(&x_buf, -x) else CSI.CUF(&x_buf, x);
    const y_pos = if (y == 0) "" else if (y < 0) CSI.CUU(&y_buf, -y) else CSI.CUD(&y_buf, y);
    return .{ x_pos, y_pos };
}

pub fn to(x: usize, y: ?usize) []const u8 {
    const buf: [32]u8 = undefined;

    if (y) |_y| {
        return CSI.CUP(&buf, _y + 1, x + 1);
    }

    return CSI.CHA(&buf, x + 1);
}
