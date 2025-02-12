pub usingnamespace @import("./ansi.zig");

pub const Color = @import("Color.zig");
pub const CSI = @import("./csi.zig");
pub const OSC = @import("./osc.zig");

pub fn KV(comptime T: type) type {
    return struct {
        name: []const u8,
        value: T,
    };
}
