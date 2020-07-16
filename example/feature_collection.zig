const std = @import("std");
const zig_geojson = @import("zig_geojson");

const json_str = @embedFile("../test/countries.json");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var geojson = try zig_geojson.Parser.parse(json_str, std.heap.page_allocator);
    defer geojson.deinit();

    if (geojson.featureCollection()) |features| {
        for (features) |feature| {
            const id = if (feature.id) |id| id.string else null;
            try stdout.print("{} consists of {} points\n", .{ id, numberOfPoints(feature.geometry) });
        }
    }
}

fn numberOfPoints(n: zig_geojson.Geometry) usize {
    return switch (n) {
        .point => 1,
        .line_string, .multi_point => |x| sum1D(x),
        .polygon => |x| sum2D(x),
        .multi_polygon => |x| sum3D(x),
        .multi_line_string => |x| sum2D(x),
        .geometry_collection => |x| {
            var sum: usize = 0;
            for (x) |i| sum += numberOfPoints(i);
            return sum;
        },
    };
}

inline fn sum3D(n: [][][]zig_geojson.Point) usize {
    var sum: usize = 0;
    for (n) |i| sum += sum2D(i);
    return sum;
}

inline fn sum2D(n: [][]zig_geojson.Point) usize {
    var sum: usize = 0;
    for (n) |i| sum += sum1D(i);
    return sum;
}

inline fn sum1D(n: []zig_geojson.Point) usize {
    return n.len;
}
