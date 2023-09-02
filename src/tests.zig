const std = @import("std");

const zig_geojson = @import("main.zig");
const Parser = zig_geojson.Parser;
const BBox = zig_geojson.BBox;
const Point = zig_geojson.Point;

test "simple feature" {
    const json =
        \\{
        \\  "type": "Feature",
        \\  "id": "simple feature",
        \\  "geometry": {
        \\    "type": "Point",
        \\    "coordinates": [125.6, 10.1]
        \\  } 
        \\}
    ;

    var geojson = try Parser.parse(json, std.testing.allocator);
    defer geojson.deinit();

    try std.testing.expect(geojson.content == .feature);
    const feature = geojson.feature().?;

    try std.testing.expectEqualStrings(feature.id.?.string, "simple feature");
    try std.testing.expectEqual(feature.geometry.point, Point{ 125.6, 10.1 });
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

    try std.testing.expect(geojson.feature() != null);
    const feature = geojson.feature().?;

    try std.testing.expect(feature.properties != null);
    const properties = feature.properties.?;

    try std.testing.expectEqualStrings(properties.get("stringProp").?.string, "stringValue");
    try std.testing.expectEqual(properties.get("floatProp").?.float, 1234.567);
    try std.testing.expectEqual(properties.get("integerProp").?.int, 89);

    const object = properties.get("objectProp").?.object;
    try std.testing.expectEqualStrings(object.get("innerString").?.string, "innerStringValue");

    const array = properties.get("arrayProp").?.array;
    try std.testing.expectEqualStrings(array[0].string, "stringValue");
    try std.testing.expectEqual(array[1].float, 1234.567);
    try std.testing.expectEqual(array[2].int, 89);
    try std.testing.expectEqualStrings(array[3].object.get("innerString").?.string, "innerStringValue");
}

test "geometries" {
    const json =
        \\{
        \\  "type": "Feature",
        \\  "bbox": [100.0, 0.0, 103.0, 3.0],
        \\  "id": 7331,
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

    var geojson = try Parser.parse(json, std.testing.allocator);
    defer geojson.deinit();

    const bbox = BBox{ .min = .{ 100.0, 0.0 }, .max = .{ 103.0, 3.0 } };
    try std.testing.expectEqual(geojson.bbox.?, bbox);

    const point = Point{ 100.0, 0.0 };

    const lineString = [_]Point{
        .{ 101.0, 0.0 },
        .{ 102.0, 1.0 },
    };

    const polygon = [_][5]Point{
        [_]Point{
            .{ 100.0, 0.0 },
            .{ 101.0, 0.0 },
            .{ 101.0, 1.0 },
            .{ 100.0, 1.0 },
            .{ 100.0, 0.0 },
        },
        [_]Point{
            .{ 100.8, 0.8 },
            .{ 100.8, 0.2 },
            .{ 100.2, 0.2 },
            .{ 100.2, 0.8 },
            .{ 100.8, 0.8 },
        },
    };

    const multiPoint = [_]Point{
        .{ 100.0, 0.0 },
        .{ 101.0, 1.0 },
    };

    const multiLineString = [_][2]Point{
        [_]Point{
            .{ 100.0, 0.0 },
            .{ 101.0, 1.0 },
        },
        [_]Point{
            .{ 102.0, 2.0 },
            .{ 103.0, 3.0 },
        },
    };

    const multiPolygon = [_][1][5]Point{
        [1][5]Point{
            [_]Point{
                .{ 102.0, 2.0 },
                .{ 103.0, 2.0 },
                .{ 103.0, 3.0 },
                .{ 102.0, 3.0 },
                .{ 102.0, 2.0 },
            },
        },
        [1][5]Point{
            [_]Point{
                .{ 100.0, 0.0 },
                .{ 101.0, 0.0 },
                .{ 101.0, 1.0 },
                .{ 100.0, 1.0 },
                .{ 100.0, 0.0 },
            },
        },
    };

    const id: i64 = 7331;

    const feature = geojson.feature().?;

    try std.testing.expectEqual(id, feature.id.?.int);

    for (feature.geometry.geometry_collection) |g| {
        switch (g) {
            .point => |value| try std.testing.expectEqual(point, value),
            .line_string => |value| try std.testing.expectEqualSlices(Point, &lineString, value),
            .polygon => |value| for (value, 0..) |ring, idx| try std.testing.expectEqualSlices(Point, &polygon[idx], ring),
            .multi_point => |value| try std.testing.expectEqualSlices(Point, &multiPoint, value),
            .multi_line_string => |value| for (value, 0..) |lineStr, idx| try std.testing.expectEqualSlices(Point, &multiLineString[idx], lineStr),
            .multi_polygon => |value| for (value, 0..) |poly, pidx| for (poly, 0..) |slice, idx| try std.testing.expectEqualSlices(Point, &multiPolygon[pidx][idx], slice),
            else => unreachable,
        }
    }
}
