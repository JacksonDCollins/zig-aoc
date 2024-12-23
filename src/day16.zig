const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
// const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const raw_data = @embedFile("data/day16.txt");

const red = "\u{001B}[31m";
const set = "\u{001B}[0m";

const Tile = enum(u8) {
    Wall = '#',
    Empty = '.',
    Start = 'S',
    End = 'E',
};

const Direction = enum(u8) {
    North = 'N',
    East = 'E',
    South = 'S',
    West = 'W',

    pub fn turn_left(self: Direction) Direction {
        return switch (self) {
            .North => .West,
            .East => .North,
            .South => .East,
            .West => .South,
        };
    }

    pub fn turn_right(self: Direction) Direction {
        return switch (self) {
            .North => .East,
            .East => .South,
            .South => .West,
            .West => .North,
        };
    }
};

const Actions = enum(u8) {
    MoveForward = 'F',
    TurnLeft = 'L',
    TurnRight = 'R',

    pub fn getCost(self: @This()) isize {
        return switch (self) {
            .MoveForward => 1,
            .TurnLeft, .TurnRight => 1000,
        };
    }
};

const Map = struct {
    tiles: []Tile,
    map_width: usize,
    map_height: usize,
    current_x_position: usize,
    current_y_position: usize,
    start_x_position: usize,
    start_y_position: usize,
    facing: Direction = Direction.East,

    pub const options = struct {
        map_width: usize,
        map_height: usize,

        const default = @This(){
            .map_width = 15,
            .map_height = 15,
        };
    };

    pub fn reset(self: *Map) void {
        self.current_x_position = self.start_x_position;
        self.current_y_position = self.start_y_position;
        self.facing = Direction.East;
    }

    pub fn followPath(self: *Map, path: []const Actions) !void {
        var visited = try gpa.alloc(bool, self.map_width * self.map_height);
        visited[self.getPositionIndex(self.current_x_position, self.current_y_position)] = true;
        defer gpa.free(visited);

        for (path) |action| {
            self.followAction(action);
            if (action == .MoveForward) {
                if (visited[self.getPositionIndex(self.current_x_position, self.current_y_position)]) {
                    return error.Visited;
                } else {
                    visited[self.getPositionIndex(self.current_x_position, self.current_y_position)] = true;
                }
            }
        }
    }

    pub fn followAction(self: *Map, action: Actions) void {
        switch (action) {
            .MoveForward => {
                switch (self.facing) {
                    .North => self.current_y_position -= 1,
                    .East => self.current_x_position += 1,
                    .South => self.current_y_position += 1,
                    .West => self.current_x_position -= 1,
                }
            },
            .TurnLeft => self.facing = self.facing.turn_left(),
            .TurnRight => self.facing = self.facing.turn_right(),
        }
    }

    pub fn printMapWithPath(self: *Map, path: []const Actions) !void {
        self.reset();
        var buffer = std.ArrayList(u8).fromOwnedSlice(gpa, try self.getMapString());
        defer buffer.deinit();

        for (path, 0..) |action, c| {
            self.followAction(action);

            if (action == .MoveForward) {
                const pos = self.getPositionIndex(self.current_x_position, self.current_y_position) + self.current_y_position;

                if (buffer.items[pos] == 'E') {
                    buffer.items[pos] = 'H';
                } else if (c == path.len - 1) {
                    // buffer.items[pos] = '1';
                    switch (self.facing) {
                        .North => buffer.items[pos] = 'W', // '^',
                        .East => buffer.items[pos] = 'X', //'>',
                        .South => buffer.items[pos] = 'Y', //'v',
                        .West => buffer.items[pos] = 'Z', //'<',
                    }
                } else {
                    switch (self.facing) {
                        .North => buffer.items[pos] = 'U',
                        .East => buffer.items[pos] = 'R',
                        .South => buffer.items[pos] = 'D',
                        .West => buffer.items[pos] = 'L',
                    }
                }
            }
        }

        while (indexOfAny(u8, buffer.items, "URDLWXYZH")) |idx| {
            try buffer.insertSlice(idx + 1, set);
            // buffer.items[idx] = '|';
            switch (buffer.items[idx]) {
                'U', 'D' => buffer.items[idx] = '|',
                'L', 'R' => buffer.items[idx] = '-',
                'W' => buffer.items[idx] = '^',
                'X' => buffer.items[idx] = '>',
                'Y' => buffer.items[idx] = 'v',
                'Z' => buffer.items[idx] = '<',
                'H' => buffer.items[idx] = 'E',
                else => unreachable,
            }
            try buffer.insertSlice(idx, red);
        }

        var line_iter = splitSca(u8, buffer.items, '\n');
        while (line_iter.next()) |line| {
            print("{s}\n", .{line});
        }
    }

    pub fn getMapString(self: *Map) ![]u8 {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();

        var x: usize = 0;
        var y: usize = 0;
        for (self.tiles) |tile| {
            try buffer.append(@intFromEnum(tile));

            x += 1;
            if (x == self.map_width) {
                try buffer.append('\n');
                x = 0;
                y += 1;
            }
        }

        return buffer.toOwnedSlice();
    }

    pub fn getPositionIndex(self: Map, x: usize, y: usize) usize {
        assert(x < self.map_width and y < self.map_height and x >= 0 and y >= 0);
        return x + y * self.map_height;
    }

    pub fn getSurroundingTiles(self: Map) [3]Tile {
        return .{
            self.getLeftTile(),
            self.getRightTile(),
            self.getForwardTile(),
        };
    }

    pub fn getTile(self: Map, x: usize, y: usize) Tile {
        assert(x < self.map_width);
        assert(y < self.map_height);
        return self.tiles[self.getPositionIndex(x, y)];
    }

    fn getFacingTile(self: Map, dir: Direction) Tile {
        return switch (dir) {
            .North => self.getTile(self.current_x_position, self.current_y_position - 1),
            .East => self.getTile(self.current_x_position + 1, self.current_y_position),
            .South => self.getTile(self.current_x_position, self.current_y_position + 1),
            .West => self.getTile(self.current_x_position - 1, self.current_y_position),
        };
    }

    pub fn getForwardTile(self: Map) Tile {
        return self.getFacingTile(self.facing);
    }

    pub fn getLeftTile(self: Map) Tile {
        return self.getFacingTile(self.facing.turn_left());
    }

    pub fn getRightTile(self: Map) Tile {
        return self.getFacingTile(self.facing.turn_right());
    }

    pub fn deinit(self: *Map, allocator: Allocator) void {
        allocator.free(self.tiles);
        allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, data: []const u8, opt: options) !*Map {
        var map = try allocator.create(Map);
        map.* = .{
            .tiles = undefined,
            .current_x_position = 0,
            .current_y_position = 0,
            .start_x_position = 0,
            .start_y_position = 0,
            .map_width = opt.map_width,
            .map_height = opt.map_height,
        };

        map.*.tiles = try allocator.alloc(Tile, map.map_width * map.map_height);

        var x: usize = 0;
        var y: usize = 0;
        for (data) |c| {
            switch (c) {
                '#' => map.tiles[map.getPositionIndex(x, y)] = Tile.Wall,
                '.' => map.tiles[map.getPositionIndex(x, y)] = Tile.Empty,
                'S' => {
                    map.tiles[map.getPositionIndex(x, y)] = Tile.Start;
                    map.start_x_position = x;
                    map.start_y_position = y;
                    map.current_x_position = x;
                    map.current_y_position = y;
                },
                'E' => map.tiles[map.getPositionIndex(x, y)] = Tile.End,
                '\n' => {
                    x = 0;
                    y += 1;
                    continue;
                },
                else => unreachable,
            }

            x += 1;
        }

        return map;
    }
};

pub fn main() !void {
    defer {
        _ = util.gpa_impl.deinit();
    }
    const opt = comptime c: {
        @setEvalBranchQuota(4096 * 8);

        var iter = splitSca(u8, raw_data, '\n');
        const first_line = iter.first();
        const width = first_line.len;
        const height = h: {
            var i: usize = 1;
            while (iter.next()) |_| {
                i += 1;
            }
            break :h i;
        };

        break :c Map.options{ .map_width = width, .map_height = height };
    };

    var map = map: {
        break :map try Map.init(gpa, raw_data, opt);
    };
    defer map.deinit(gpa);

    // print("{}\n", .{map.getPositionIndex(1, 1)});
    const shortest = try getLowestScore(map, 100);
    defer shortest.deinit();
    try map.printMapWithPath(shortest.data.items);
    print("Lowest score: {}\n", .{shortest.calculateCost()});
}

const Path = struct {
    data: std.ArrayList(Actions),
    ended: bool = false,

    pub fn calculateCost(self: *Path) isize {
        var cost: isize = 0;
        for (self.data.items) |action| {
            cost += @intCast(action.getCost());
        }
        return cost;
    }

    pub fn clone(self: *Path) !*Path {
        const new_path = try self.data.allocator.create(Path);
        new_path.* = .{
            .data = try self.data.clone(),
        };
        return new_path;
    }

    pub fn append(self: *Path, action: Actions) !void {
        try self.data.append(action);
    }

    pub fn init(
        allocator: Allocator,
    ) !*Path {
        const path = try allocator.create(Path);
        path.* = .{
            .data = std.ArrayList(Actions).init(allocator),
        };
        return path;
    }

    pub fn deinit(self: *Path) void {
        var alloc = self.data.allocator;
        self.data.deinit();
        alloc.destroy(self);
    }
};
const Paths = std.ArrayList(*Path);

fn getLowestScore(map: *Map, iterations: usize) !*Path {
    var paths = Paths.init(gpa);
    defer {
        for (paths.items) |path| {
            path.deinit();
        }
        paths.deinit();
    }

    const first_path = try Path.init(gpa);
    try paths.append(first_path);
    var shortest: isize = std.math.maxInt(isize);
    var shortest_path: *Path = try first_path.clone();

    for (0..iterations) |idx| {
        if (paths.items.len == 0) {
            break;
        }
        // _ = idx;
        print("Loop: {}, Paths: {}, Best: {}\n", .{ idx, paths.items.len, shortest });

        // try map.printMapWithPath(shortest_path.data.items);

        var path_idx: usize = 0;
        // for (paths.items, 0..) |path, path_idx| {
        d: while (path_idx < paths.items.len) {
            const path = paths.items[path_idx];

            map.reset();

            map.followPath(path.data.items) catch |err| {
                switch (err) {
                    error.Visited => {
                        var op = paths.orderedRemove(path_idx);
                        op.deinit();
                        continue :d;
                    },
                    else => return err,
                }
            };

            const surrounding_tile = map.getSurroundingTiles();
            for (surrounding_tile, 0..3) |tile, i| {
                switch (i) {
                    2 => {
                        switch (tile) {
                            .End => {
                                try path.append(.MoveForward);
                                // path.ended = true;
                                const cost = path.calculateCost();
                                if (cost < shortest) {
                                    shortest = cost;
                                    shortest_path.deinit();
                                    shortest_path = try path.clone();
                                }
                                var op = paths.orderedRemove(path_idx);
                                op.deinit();
                                continue :d;
                            },
                            .Wall, .Start => {
                                var op = paths.orderedRemove(path_idx);
                                op.deinit();
                                continue :d;
                            },
                            .Empty => {
                                try path.append(.MoveForward);
                                // var new_path = try path.clone(@intCast(paths.items.len));
                                // try new_path.append(Actions.MoveForward);
                                // try paths.append(new_path);
                            },
                        }
                    },
                    0 => {
                        switch (tile) {
                            .Empty => {
                                var new_path = try path.clone();
                                try new_path.append(Actions.TurnLeft);
                                try new_path.append(Actions.MoveForward);
                                try paths.append(new_path);
                            },
                            else => continue,
                        }
                    },
                    1 => {
                        switch (tile) {
                            .Empty => {
                                var new_path = try path.clone();
                                try new_path.append(Actions.TurnRight);
                                try new_path.append(Actions.MoveForward);
                                try paths.append(new_path);
                            },
                            else => continue,
                        }
                    },
                    else => unreachable,
                }
            }
            path_idx += 1;
        }
    }

    return shortest_path;
}

// Useful stdlib functions
const tokenizeAny = std.mem.tokenizeAny;
const tokenizeSeq = std.mem.tokenizeSequence;
const tokenizeSca = std.mem.tokenizeScalar;
const splitAny = std.mem.splitAny;
const splitSeq = std.mem.splitSequence;
const splitSca = std.mem.splitScalar;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
