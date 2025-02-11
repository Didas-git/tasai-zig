const std = @import("std");
const CSI = @import("./csi.zig");

const Cursor = @This();

hidden: bool,

pub fn hide(self: Cursor) []const u8 {
    self.hidden = true;
    return CSI.CUH;
}

pub fn show(self: Cursor) []const u8 {
    self.hidden = false;
    return CSI.CUS;
}

pub fn move(x: isize, y: isize) [2][]const u8 {
    const x_pos = if (x == 0) "" else if (x < 0) CSI.CUB(-x) else CSI.CUF(x);
    const y_pos = if (y == 0) "" else if (y < 0) CSI.CUU(-y) else CSI.CUD(y);
    return .{ x_pos, y_pos };
}

pub fn to(x: usize, y: ?usize) []const u8 {
    if (y) |_y| {
        return CSI.CUP(_y + 1, x + 1);
    }

    return CSI.CHA(x + 1);
}
