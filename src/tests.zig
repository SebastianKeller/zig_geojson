const std = @import("std");
usingnamespace @import("main.zig");

test "simple feature" {
    const json =
        \\{
        \\  "type": "Feature",
        \\  "geometry": {
        \\    "type": "Point",
        \\    "coordinates": [125.6, 10.1]
        \\  }
        \\}
    ;

    var geojson = try Parser.parse(json, std.testing.allocator);
    defer geojson.deinit();

    std.testing.expect(geojson.content == .feature);
    const feature = geojson.feature().?;

    std.testing.expectEqual(feature.geometry.point, .{ .x = 125.6, .y = 10.1 });
}

test "properties" {
    const json =
        \\{
        \\  "type": "Feature",
        \\  "geometry": null,
        \\  "properties": {
        \\    "stringProp": "stringValue",
        \\    "floatProp": 1234.567,
        \\    "integerProp": 89,
        \\    "objectProp": {
        \\      "innerString": "innerStringValue"
        \\    },
        \\    "arrayProp": [
        \\      "stringValue",
        \\      1234.567,
        \\      89,
        \\      {
        \\        "innerString": "innerStringValue"
        \\      }
        \\    ]
        \\  }
        \\}
    ;

    var geojson = try Parser.parse(json, std.testing.allocator);
    defer geojson.deinit();

    std.testing.expect(geojson.feature() != null);
    const feature = geojson.feature().?;

    std.testing.expect(feature.properties != null);
    const properties = feature.properties.?;

    std.testing.expectEqualStrings(properties.get("stringProp").?.string, "stringValue");
    std.testing.expectEqual(properties.get("floatProp").?.float, 1234.567);
    std.testing.expectEqual(properties.get("integerProp").?.int, 89);

    const object = properties.get("objectProp").?.object;
    std.testing.expectEqualStrings(object.get("innerString").?.string, "innerStringValue");

    const array = properties.get("arrayProp").?.array;
    std.testing.expectEqualStrings(array[0].string, "stringValue");
    std.testing.expectEqual(array[1].float, 1234.567);
    std.testing.expectEqual(array[2].int, 89);
    std.testing.expectEqualStrings(array[3].object.get("innerString").?.string, "innerStringValue");
}

test "geometries" {
    const json =
        \\{
        \\  "type": "Feature",
        \\  "geometry": {
        \\    "type": "GeometryCollection",
        \\    "geometries": [
        \\      {
        \\        "type": "Point",
        \\        "coordinates": [100.0, 0.0]
        \\      },
        \\      {
        \\        "type": "LineString",
        \\        "coordinates": [
        \\          [101.0, 0.0],
        \\          [102.0, 1.0]
        \\        ]
        \\      },
        \\      {
        \\        "type": "Polygon",
        \\        "coordinates": [
        \\          [
        \\            [100.0, 0.0],
        \\            [101.0, 0.0],
        \\            [101.0, 1.0],
        \\            [100.0, 1.0],
        \\            [100.0, 0.0]
        \\          ],
        \\          [
        \\            [100.8, 0.8],
        \\            [100.8, 0.2],
        \\            [100.2, 0.2],
        \\            [100.2, 0.8],
        \\            [100.8, 0.8]
        \\          ]
        \\        ]
        \\      },
        \\      {
        \\        "type": "MultiPoint",
        \\        "coordinates": [
        \\          [100.0, 0.0],
        \\          [101.0, 1.0]
        \\        ]
        \\      },
        \\      {
        \\        "type": "MultiLineString",
        \\        "coordinates": [
        \\          [
        \\            [100.0, 0.0],
        \\            [101.0, 1.0]
        \\          ],
        \\          [
        \\            [102.0, 2.0],
        \\            [103.0, 3.0]
        \\          ]
        \\        ]
        \\      },
        \\      {
        \\        "type": "MultiPolygon",
        \\        "coordinates": [
        \\          [
        \\            [
        \\              [102.0, 2.0],
        \\              [103.0, 2.0],
        \\              [103.0, 3.0],
        \\              [102.0, 3.0],
        \\              [102.0, 2.0]
        \\            ]
        \\          ],
        \\          [
        \\            [
        \\              [100.0, 0.0],
        \\              [101.0, 0.0],
        \\              [101.0, 1.0],
        \\              [100.0, 1.0],
        \\              [100.0, 0.0]
        \\            ]
        \\          ]
        \\        ]
        \\      }
        \\    ]
        \\  }
        \\}
    ;

    var geojson = try Parser.parse(json, std.heap.page_allocator);
    defer geojson.deinit();

    const point = Point{ .x = 100.0, .y = 0.0 };

    const lineString = [_]Point{
        .{ .x = 101.0, .y = 0.0 },
        .{ .x = 102.0, .y = 1.0 },
    };

    const polygon = [_][5]Point{
        [_]Point{
            .{ .x = 100.0, .y = 0.0 },
            .{ .x = 101.0, .y = 0.0 },
            .{ .x = 101.0, .y = 1.0 },
            .{ .x = 100.0, .y = 1.0 },
            .{ .x = 100.0, .y = 0.0 },
        },
        [_]Point{
            .{ .x = 100.8, .y = 0.8 },
            .{ .x = 100.8, .y = 0.2 },
            .{ .x = 100.2, .y = 0.2 },
            .{ .x = 100.2, .y = 0.8 },
            .{ .x = 100.8, .y = 0.8 },
        },
    };

    const multiPoint = [_]Point{
        .{ .x = 100.0, .y = 0.0 },
        .{ .x = 101.0, .y = 1.0 },
    };

    const multiLineString = [_][2]Point{
        [_]Point{
            .{ .x = 100.0, .y = 0.0 },
            .{ .x = 101.0, .y = 1.0 },
        },
        [_]Point{
            .{ .x = 102.0, .y = 2.0 },
            .{ .x = 103.0, .y = 3.0 },
        },
    };

    const multiPolygon = [_][1][5]Point{
        [1][5]Point{
            [_]Point{
                .{ .x = 102.0, .y = 2.0 },
                .{ .x = 103.0, .y = 2.0 },
                .{ .x = 103.0, .y = 3.0 },
                .{ .x = 102.0, .y = 3.0 },
                .{ .x = 102.0, .y = 2.0 },
            },
        },
        [1][5]Point{
            [_]Point{
                .{ .x = 100.0, .y = 0.0 },
                .{ .x = 101.0, .y = 0.0 },
                .{ .x = 101.0, .y = 1.0 },
                .{ .x = 100.0, .y = 1.0 },
                .{ .x = 100.0, .y = 0.0 },
            },
        },
    };

    for (geojson.feature().?.geometry.geometry_collection) |g| {
        switch (g) {
            .point => |value| std.testing.expectEqual(value, point),
            .line_string => |value| std.testing.expectEqualSlices(Point, value, &lineString),
            .polygon => |value| for (value) |ring, idx| std.testing.expectEqualSlices(Point, ring, &polygon[idx]),
            .multi_point => |value| std.testing.expectEqualSlices(Point, value, &multiPoint),
            .multi_line_string => |value| for (value) |lineStr, idx| std.testing.expectEqualSlices(Point, lineStr, &multiLineString[idx]),
            .multi_polygon => |value| for (value) |poly, pidx| for (poly) |slice, idx| std.testing.expectEqualSlices(Point, slice, &multiPolygon[pidx][idx]),
            else => unreachable,
        }
    }
}
