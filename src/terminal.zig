const std = @import("std");
const CSI = @import("./csi.zig");
const Cursor = @import("./Cursor.zig");

pub fn RawTerminal(comptime handle_control_codes: bool) type {
    return struct {
        alloc: std.mem.Allocator,
        tty: std.fs.File,
        termios: std.posix.termios,
        stdout: std.fs.File = std.io.getStdOut(),
        stdin: std.fs.File = std.io.getStdIn(),

        pub fn init(allocator: std.mem.Allocator) !RawTerminal(handle_control_codes) {
            const file = try std.fs.openFileAbsolute("/dev/tty", .{
                .mode = .read_write,
                .allow_ctty = true,
            });

            var termios = try std.posix.tcgetattr(file.handle);
            const original_termios = termios;

            // https://github.com/xyaman/mibu/blob/b001662c929e2719ee24be585a3120640f946337/src/term.zig#L19
            // cspell:disable
            termios.iflag.BRKINT = false;
            termios.iflag.ICRNL = false;
            termios.iflag.INPCK = false;
            termios.iflag.ISTRIP = false;
            termios.iflag.IXON = false;

            termios.oflag.OPOST = false;

            termios.lflag.ECHO = false;
            termios.lflag.ICANON = false;
            termios.lflag.IEXTEN = false;
            termios.lflag.ISIG = false;

            termios.cflag.CSIZE = .CS8;
            // cspell:enable

            termios.cc[@intFromEnum(std.posix.V.MIN)] = 1;
            termios.cc[@intFromEnum(std.posix.V.TIME)] = 0;

            try std.posix.tcsetattr(file.handle, .NOW, termios);

            return .{
                .tty = file,
                .alloc = allocator,
                .termios = original_termios,
            };
        }

        pub fn deinit(self: RawTerminal(handle_control_codes)) !void {
            try self.stdout.writeAll(CSI.CUS);
            try std.posix.tcsetattr(self.tty.handle, .NOW, self.termios);
        }

        /// The handler has 4 bytes as special cases:
        /// 252 - Arrow Up (ESC A | ESC[A | ESC O A)
        /// 253 - Arrow Down (ESC B | ESC[B | ESC O B)
        /// 254 - Arrow Right (ESC C | ESC[C | ESC O C)
        /// 255 - Arrow Left (ESC D | ESC[D | ESC O D)
        pub fn readInput(self: RawTerminal(handle_control_codes), comptime T: type, handler: fn (byte: u8) anyerror!?T) !T {
            var poller = std.io.poll(self.alloc, enum { stdin }, .{ .stdin = self.stdin });
            defer poller.deinit();

            var buf: [8]u8 = undefined;
            while (true) {
                const isReady = try poller.poll();
                if (!isReady) return error.FailedToPoll;
                const bytes = poller.fifo(.stdin).read(&buf);

                if (bytes > 1) {
                    if (buf[0] == std.ascii.control_code.esc) {
                        const byte = switch (buf[1]) {
                            'A' => @as(u8, 252),
                            'B' => @as(u8, 253),
                            'C' => @as(u8, 254),
                            'D' => @as(u8, 255),
                            '[', 'O' => switch (buf[2]) {
                                'A' => @as(u8, 252),
                                'B' => @as(u8, 253),
                                'C' => @as(u8, 254),
                                'D' => @as(u8, 255),
                                else => return error.UnsupportedEscapeCode,
                            },
                            else => return error.UnsupportedEscapeCode,
                        };

                        if (try handler(byte)) |val| {
                            return val;
                        }
                    } else {
                        return error.UnsupportedValue;
                    }
                } else if (handle_control_codes) {
                    switch (buf[0]) {
                        std.ascii.control_code.etx => {
                            try self.deinit();
                            std.process.abort();
                        },
                        else => {
                            if (try handler(buf[0])) |val| {
                                return val;
                            }
                        },
                    }
                } else {
                    if (try handler(buf[0])) |val| {
                        return val;
                    }
                }

                buf = undefined;
            }
        }
    };
}
