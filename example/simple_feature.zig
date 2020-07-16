const std = @import("std");
const zig_geojson = @import("zig_geojson");

const json_str = @embedFile("../test/simple_feature.json");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var geojson = try zig_geojson.Parser.parse(json_str, std.heap.page_allocator);
    defer geojson.deinit();

    const feature = geojson.feature().?;
    const point = feature.geometry.point;
    try stdout.print("Feature point has x = {d}, y = {d}\n", .{ point.x, point.y });

    if (feature.properties) |properties| {
        for (properties.items()) |entry| {
            try stdout.print("Enumerating properties: '{}' = '{}'\n", .{ entry.key, entry.value.string });
        }

        const name_value = properties.get("name");
        if (name_value) |value|
            try stdout.print("Direct access properties: 'name' = '{}'\n", .{value.string});
    }
}
