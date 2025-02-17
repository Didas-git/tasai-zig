const std = @import("std");

pub usingnamespace @import("./ansi.zig");

pub const Prompt = @import("./prompt.zig").Prompt;
pub const Terminal = @import("./Terminal.zig");
pub const Color = @import("./Color.zig");
pub const CSI = @import("./csi.zig");
pub const OSC = @import("./osc.zig");

pub fn KV(comptime T: type) type {
    return struct {
        name: []const u8,
        value: T,
    };
}

pub const prompt = struct {
    pub const Input = @import("./prompts/input.zig").InputPrompt;
    pub const Select = @import("./prompts/select.zig").SelectPrompt;
    pub const Confirm = @import("./prompts/confirm.zig").ConfirmPrompt;
};

test "imports" {
    std.testing.refAllDecls(@This());
}
