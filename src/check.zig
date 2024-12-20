const _ = @import("util.zig");
const d1 = @import("day01.zig");
const d2 = @import("day02.zig");
const d3 = @import("day03.zig");
const d4 = @import("day04.zig");
const d5 = @import("day05.zig");
const d6 = @import("day06.zig");
const d7 = @import("day07.zig");
const d8 = @import("day08.zig");
const d9 = @import("day09.zig");
const d10 = @import("day10.zig");
const d11 = @import("day11.zig");
const d12 = @import("day12.zig");
const d13 = @import("day13.zig");
const d14 = @import("day14.zig");
const d15 = @import("day15.zig");
const d16 = @import("day16.zig");
const d17 = @import("day17.zig");
const d18 = @import("day18.zig");
const d19 = @import("day19.zig");
const d20 = @import("day20.zig");
const d21 = @import("day21.zig");
const d22 = @import("day22.zig");
const d23 = @import("day23.zig");
const d24 = @import("day24.zig");
const d25 = @import("day25.zig");
const std = @import("std");
pub fn main() !void {
    inline for (0..25) |i| {
        const day = i + 1;

        const t = @field(@This(), "d" ++ std.fmt.comptimePrint("{d}", .{day}));

        try t.main();
    }
}
