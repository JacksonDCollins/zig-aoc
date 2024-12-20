const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
// const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const raw_data = @embedFile("data/day16.txt");

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

    pub fn get_cost(self: @This()) u8 {
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

    pub fn followPath(self: *Map, path: []const Actions) void {
        for (path) |action| {
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
        return self.tiles[x + y * self.map_height];
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
                '#' => map.tiles[x + y * map.map_height] = Tile.Wall,
                '.' => map.tiles[x + y * map.map_height] = Tile.Empty,
                'S' => {
                    map.tiles[x + y * map.map_height] = Tile.Start;
                    map.start_x_position = x;
                    map.start_y_position = y;
                    map.current_x_position = x;
                    map.current_y_position = y;
                },
                'E' => map.tiles[x + y * map.map_height] = Tile.End,
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

    const score = try getLowestScore(map);
    print("Lowest score: {}\n", .{score});
}

const Path = std.ArrayList(Actions);
const Paths = std.ArrayList(*Path);

fn getLowestScore(map: *Map) !isize {
    var paths = Paths.init(gpa);
    defer {
        for (paths.items) |path| {
            path.deinit();
        }
        paths.deinit();
    }

    var first_path = Path.init(gpa);
    try paths.append(&first_path);

    for (0..10) |_| {
        print("Paths: {}\n", .{paths.items.len});

        // const path_count = paths.items.len;
        for (paths.items, 0..) |path, path_idx| {
            print("Path {}: ", .{path_idx});
            for (path.items) |action| {
                print("{c}, ", .{@intFromEnum(action)});
            }
            print("\n", .{});

            map.reset();

            map.followPath(path.items);

            const surrounding_tile = map.getSurroundingTiles();
            for (surrounding_tile, 0..3) |tile, i| {
                switch (i) {
                    2 => {
                        switch (tile) {
                            .Empty => try path.append(Actions.MoveForward),
                            .Wall => {
                                var old_path = paths.swapRemove(path_idx);
                                old_path.deinit();
                            },
                            else => continue,
                        }
                    },
                    0 => {
                        switch (tile) {
                            .Empty => {
                                var new_path = try path.clone();
                                try new_path.append(Actions.TurnLeft);
                                try new_path.append(Actions.MoveForward);
                                try paths.append(&new_path);
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
                                try paths.append(&new_path);
                            },
                            else => continue,
                        }
                    },
                    else => unreachable,
                }
            }
        }
    }

    print("Paths: {}\n", .{paths.items.len});
    for (paths.items, 0..) |path, i| {
        print("Path {}: ", .{i});
        for (path.items) |action| {
            switch (action) {
                .MoveForward => print("F", .{}),
                .TurnLeft => print("L", .{}),
                .TurnRight => print("R", .{}),
            }
        }
        print("\n", .{});
    }

    return 0;
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
