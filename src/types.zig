const std = @import("std");

pub const Point = struct {
    x: f64,
    y: f64,

    pub fn equals(a: @This(), b: @This()) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "Point(.x = {}, .y = {})",
            .{ self.x, self.y },
        );
    }
};

pub const MultiPoint = struct {
    points: []Point,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "MultiPoint(.points = {})",
            .{self.points},
        );
    }
};

pub const LineString = struct {
    points: []Point,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "LineString(.points = {})",
            .{self.points},
        );
    }
};

pub const MultiLineString = struct {
    lineStrings: []LineString,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "MultiLineString(.lineStrings = {})",
            .{self.lineStrings},
        );
    }
};

pub const LinearRing = struct {
    points: []Point,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "LinearRing(.points = {})",
            .{self.points},
        );
    }
};

pub const Polygon = struct {
    rings: []LinearRing,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "Polygon(.rings = {})",
            .{self.rings},
        );
    }
};

pub const MultiPoligon = struct {
    polygons: []Polygon,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "MultiPolygon(.polygons = {})",
            .{self.polygons},
        );
    }
};

pub const Box = struct {
    min: Point,
    max: Point,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "Box(.min = {}, .max = {})",
            .{ self.min, self.max },
        );
    }
};

pub const Geometry = union(enum) {
    point: Point,
    line_string: LineString,
    polygon: Polygon,
    multi_point: MultiPoint,
    multi_line_string: MultiLineString,
    multi_polygon: MultiPoligon,
    geometry_collection: GeometryCollection,
};

pub const GeometryCollection = struct {
    geometries: []Geometry,
};

pub const Value = union(enum) {
    array: []Value,
    int: i64,
    uint: u64,
    float: f64,
    string: []const u8,
    object: std.StringHashMap(Value),
};

pub const NullValue = struct {};
pub const Identifier = union(enum) {
    uint: u64,
    int: i64,
    float: f64,
    string: []const u8,
};

pub const Feature = struct {
    geometry: Geometry,
    properties: ?std.StringHashMap(Value),
    identifier: ?Identifier,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return std.fmt.format(
            out_stream,
            "Feature(.identifier = {}, .geometry = {}, .properties = {})",
            .{ self.identifier, self.geometry, self.properties },
        );
    }
};

pub const FeatureCollection = []Feature;

test "Point equals" {
    var p = Point{
        .x = 1.0,
        .y = 2.0,
    };

    std.testing.expect(p.equals(Point{ .x = 1.0, .y = 2.0 }));
}

test "Value test" {
    var v = Value{ .int = 3 };
    switch (v) {
        .int => |i| std.testing.expectEqual(i, 3),
        .uint => |i| std.testing.expectEqual(i, 3),
        .float => |i| std.testing.expectEqual(i, 3.0),
        .string => |i| std.testing.expectEqual(i, "123"),
        .object => |i| return,
        .array => |i| return,
    }
}
