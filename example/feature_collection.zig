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
            try stdout.print("{}'s geometry is a {} containing {} points\n", .{
                id,
                @tagName(feature.geometry),
                numberOfPoints(feature.geometry),
            });
        }
    }
}

fn numberOfPoints(geometry: zig_geojson.Geometry) usize {
    return switch (geometry) {
        .point => |x| 1,
        .line_string, .multi_point => |x| sum(x),
        .polygon => |x| sum(x),
        .multi_polygon => |x| sum(x),
        .multi_line_string => |x| sum(x),
        .geometry_collection => |x| sum(x),
    };
}

inline fn sum(n: anytype) usize {
    const typeInfo = @typeInfo(@TypeOf(n));
    if (typeInfo == .Pointer) {
        var acc: usize = 0;
        for (n) |i| acc += sum(i);
        return acc;
    }
    return 1;
}
