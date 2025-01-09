//! This is a direct port of the original Color class from tasai
//! https://github.com/Didas-git/tasai/blob/main/src/structures/math.ts

// cSpell:disable
const std = @import("std");

pub fn Math(comptime T: type) type {
    return struct {
        pub fn mid(values: []const T) T {
            var max: T = values[0];
            var min: T = values[0];
            var i: usize = 1;

            while (i < values.len) : (i += 1) {
                if (values[i] > max) max = values[i];
                if (values[i] < min) min = values[i];
            }

            return (max + min) / 2;
        }

        pub fn sum(values: []const T) T {
            if (values.len < 3) return 0;
            // Micro optimize for RGB math
            var temp: T = values[0] + values[1] + values[2];
            if (values.len <= 3) return temp;

            var i: usize = 3;
            while (i < values.len) : (i += 1) {
                temp += values[i];
            }

            return temp;
        }

        pub fn avg(values: []const T) T {
            return sum(values) / values.len;
        }

        /// linear interpolation
        pub fn lerp(t: T, a: T, b: T) T {
            return (b - a) * t + a;
        }

        /// quadratic interpolation which starts at its turning point
        pub fn qerp0(t: T, a: T, b: T) T {
            return (b - a) * t * t + a;
        }

        /// quadratic interpolation which ends at its turning point
        pub fn qerp1(t: T, a: T, b: T) T {
            return (b - a) * (2 - t) * t + a;
        }

        /// cubic interpolation using derivatives
        pub fn cubicInterpDeriv(t: T, a: T, b: T, a_prime: ?T, b_prime: ?T) T {
            const aprime: T = a_prime orelse 0;
            const bprime: T = b_prime orelse 0;
            return (2 * a - 2 * b + aprime + bprime) * t * t * t + (3 * b - 3 * a - 2 * aprime - bprime) * t * t + aprime * t + a;
        }

        /// cubic interpolation using points
        pub fn cubicInterpPt(t: T, p0: T, p1: T, p2: T, p3: T) T {
            return (-0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3) * t * t * t + (p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3) * t * t + (0.5 * p2 - 0.5 * p0) * t + p1;
        }

        /// cyclical linear interpolation using the shorter of the two immediate paths
        pub fn cyclicLerpShort(t: T, a: T, b: T, cycles: ?T) T {
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((diff - 1 - c) * t + a + 1 + c) % 1;
            } else if (diff < -0.5) {
                return ((diff + 1 + c) * t + a) % 1;
            } else if (diff > 0) {
                return ((diff + c) * t + a) % 1;
            }

            return ((diff - c) * t + a + c) % 1;
        }

        /// cyclical linear interpolation using the longer of the two immediate paths
        pub fn cyclicLerpLong(t: T, a: T, b: T, cycles: ?T) T {
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((diff + c) * t + a) % 1;
            } else if (diff < -0.5) {
                return ((diff - c) * t + a + c) % 1;
            } else if (diff > 0) {
                return ((diff - 1 - c) * t + a + 1 + c) % 1;
            }

            return ((diff + 1 + c) * t + a) % 1;
        }

        /// cyclical quadratic interpolation which starts at its turning point using the shorter of the two immediate paths
        pub fn cyclicQerp0Short(t: T, a: T, b: T, cycles: ?T) T {
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((diff - 1 - c) * t * t + a + 1 + c) % 1;
            } else if (diff < -0.5) {
                return ((diff + 1 + c) * t * t + a) % 1;
            } else if (diff > 0) {
                return ((diff + c) * t * t + a) % 1;
            }

            return ((diff - c) * t * t + a + c) % 1;
        }

        /// cyclical quadratic interpolation which starts at its turning point using the longer of the two immediate paths
        pub fn cyclicQerp0Long(t: T, a: T, b: T, cycles: ?T) T {
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((diff + c) * t * t + a) % 1;
            } else if (diff < -0.5) {
                return ((diff - c) * t * t + a + c) % 1;
            } else if (diff > 0) {
                return ((diff - 1 - c) * t * t + a + 1 + c) % 1;
            }

            return ((diff + 1 + c) * t * t + a) % 1;
        }

        /// cyclical quadratic interpolation which ends at its turning point using the shorter of the two immediate paths
        pub fn cyclicQerp1Short(t: T, a: T, b: T, cycles: ?T) T {
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((diff - 1 - c) * (2 - t) * t + a + 1 + c) % 1;
            } else if (diff < -0.5) {
                return ((diff + 1 + c) * (2 - t) * t + a) % 1;
            } else if (diff > 0) {
                return ((diff + c) * (2 - t) * t + a) % 1;
            }

            return ((diff - c) * (2 - t) * t + a + c) % 1;
        }

        /// cyclical quadratic interpolation which ends at its turning point using the longer of the two immediate paths
        pub fn cyclicQerp1Long(t: T, a: T, b: T, cycles: ?T) T {
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((diff + c) * (2 - t) * t + a) % 1;
            } else if (diff < -0.5) {
                return ((diff - c) * (2 - t) * t + a + c) % 1;
            } else if (diff > 0) {
                return ((diff - 1 - c) * (2 - t) * t + a + 1 + c) % 1;
            }

            return ((diff + 1 + c) * (2 - t) * t + a) % 1;
        }

        /// cyclical cubic interpolation using derivatives using the shorter of the two immediate paths
        pub fn cyclicCubicInterpDerivShort(t: T, a: T, b: T, a_prime: ?T, b_prime: ?T, cycles: ?T) T {
            const aprime: T = a_prime orelse 0;
            const bprime: T = b_prime orelse 0;
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((-2 * (diff - 1 - c) + aprime + bprime) * t * t * t + (3 * (diff - 1 - c) - 2 * aprime - bprime) * t * t + aprime * t + a + 1 + c) % 1;
            } else if (diff < -0.5) {
                return ((-2 * (diff + 1 + c) + aprime + bprime) * t * t * t + (3 * (diff + 1 + c) - 2 * aprime - bprime) * t * t + aprime * t + a) % 1;
            } else if (diff > 0) {
                return ((-2 * (diff + c) + aprime + bprime) * t * t * t + (3 * (diff + c) - 2 * aprime - bprime) * t * t + aprime * t + a) % 1;
            }

            return ((-2 * (diff - c) + aprime + bprime) * t * t * t + (3 * (diff - c) - 2 * aprime - bprime) * t * t + aprime * t + a + c) % 1;
        }

        /// cyclical cubic interpolation using derivatives using the longer of the two immediate paths
        pub fn cyclicCubicInterpDerivLong(t: T, a: T, b: T, a_prime: ?T, b_prime: ?T, cycles: ?T) T {
            const aprime: T = a_prime orelse 0;
            const bprime: T = b_prime orelse 0;
            const c = cycles orelse 0;
            const diff = b - a;

            if (diff > 0.5) {
                return ((-2 * (diff + c) + aprime + bprime) * t * t * t + (3 * (diff + c) - 2 * aprime - bprime) * t * t + aprime * t + a) % 1;
            } else if (diff < -0.5) {
                return ((-2 * (diff - c) + aprime + bprime) * t * t * t + (3 * (diff - c) - 2 * aprime - bprime) * t * t + aprime * t + a + c) % 1;
            } else if (diff > 0) {
                return ((-2 * (diff - 1 - c) + aprime + bprime) * t * t * t + (3 * (diff - 1 - c) - 2 * aprime - bprime) * t * t + aprime * t + a + 1 + c) % 1;
            }

            return ((-2 * (diff + 1 + c) + aprime + bprime) * t * t * t + (3 * (diff + 1 + c) - 2 * aprime - bprime) * t * t + aprime * t + a) % 1;
        }

        /// ensures the sum of an array equals 1
        pub fn normalize1D(numbers: []const T) []const T {
            const total = sum(numbers);

            for (numbers, 0..) |_, i| {
                numbers[i] /= total;
            }

            return numbers;
        }
    };
}
