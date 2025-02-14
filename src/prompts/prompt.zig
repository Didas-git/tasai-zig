const std = @import("std");
const Terminal = @import("../terminal.zig").Terminal;

pub fn Prompt(comptime DT: type, comptime FT: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const Self = @This();

        const VTable = struct {
            initialize: *const fn (ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer) anyerror!void,
            dispatch: *const fn (ctx: *anyopaque, term: *Terminal, byte: u8) anyerror!?DT,
            format: *const fn (ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, answer: DT) anyerror!FT,
        };

        pub fn run(self: Self) !if (FT == void) DT else FT {
            var term = try Terminal.init();
            try term.enableRawMode();

            try term.stdout.lock(.none);
            defer term.stdout.unlock();

            const writer = term.stdout.writer();

            try self.vtable.initialize(self.ptr, &term, writer);

            const answer = blk: {
                while (true) {
                    var buf: [8]u8 = undefined;
                    const byte = try term.readInput(&buf);

                    if (byte == std.ascii.control_code.etx) {
                        try term.deinit();
                        std.process.abort();
                    }

                    if (try self.vtable.dispatch(self.ptr, &term, byte)) |val| {
                        break :blk val;
                    }
                    buf = undefined;
                }
            };

            try term.deinit();

            if (comptime FT == void) {
                try self.vtable.format(self.ptr, &term, writer, answer);
                return answer;
            } else {
                return try self.vtable.format(self.ptr, &term, writer, answer);
            }
        }
    };
}
