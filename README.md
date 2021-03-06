# zig_geojson

A library for parsing [GeoJSON](http://geojson.org) in zig.

## Example
```zig
const json =
    \\{
    \\   "type": "FeatureCollection",
    \\   "features": [{
    \\       "type": "Feature",
    \\       "geometry": {
    \\           "type": "Point",
    \\           "coordinates": [102.0, 0.5]
    \\       },
    \\       "properties": {
    \\           "prop0": "value0"
    \\       }
    \\   }, {
    \\       "type": "Feature",
    \\       "geometry": {
    \\           "type": "LineString",
    \\           "coordinates": [
    \\               [102.0, 0.0],
    \\               [103.0, 1.0],
    \\               [104.0, 0.0],
    \\               [105.0, 1.0]
    \\           ]
    \\       },
    \\       "properties": {
    \\           "prop0": "value0",
    \\           "prop1": 0.0
    \\       }
    \\   }, {
    \\       "type": "Feature",
    \\       "geometry": {
    \\           "type": "Polygon",
    \\           "coordinates": [
    \\               [
    \\                   [100.0, 0.0],
    \\                   [101.0, 0.0],
    \\                   [101.0, 1.0],
    \\                   [100.0, 1.0],
    \\                   [100.0, 0.0]
    \\               ]
    \\           ]
    \\       },
    \\       "properties": {
    \\           "prop0": "value0",
    \\           "prop1": {
    \\               "this": "that"
    \\           }
    \\       }
    \\   }]
    \\}
;

var geojson = Parser.parse(json, std.testing.allocator) catch |err| {
    std.debug.warn("Could not parse geojson! {}", .{err});
    return;
};
defer geojson.deinit();

// switch on the content if you don't already know the type
switch (geojson.content) {
    .feature => |feature| std.debug.warn("It's a Feature!\n", .{}),
    .feature_collection => |features| std.debug.warn("It's a FeatureCollection!\n", .{}),
    .geometry => |geometry| std.debug.warn("It's a Geometry!\n", .{}),
}

// there are helper methods `featureCollection()`, `feature()`, and `geometry()`, returning optionals
if (geojson.featureCollection()) |collection| {
    std.debug.warn("FeatureCollection contains {} features\n", .{collection.len});

    for (collection) |feature, idx| {
        std.debug.warn("{}: It's a {s} => ", .{ idx, @tagName(feature.geometry) });
        switch (feature.geometry) {
            .point => |value| std.debug.warn("[{d}, {d}]\n", .{ value[0], value[1] }),
            .multi_point => |value| std.debug.warn("containing {} points\n", .{value.len}),
            .line_string => |value| std.debug.warn("containing {} points\n", .{value.len}),
            .multi_line_string => |value| std.debug.warn("containing {} lineStrings\n", .{value.len}),
            .polygon => |value| std.debug.warn("containing {} rings\n", .{value.len}),
            .multi_polygon => |value| std.debug.warn("containing {} polygons\n", .{value.len}),
            .geometry_collection => |value| std.debug.warn("containing {} geometries\n", .{value.len}),
            .@"null" => continue,
        }
    }

    // accessing properties (safe)
    const feature = collection[0];
    if (feature.properties) |properties| {
        if (properties.get("prop0")) |value| {
            std.debug.warn("Property: 'prop0' => {}\n", .{value});
        }
    }

    // or unsafe
    const value = collection[1].properties.?.get("prop1").?;
    std.debug.warn("Property: 'prop1' => {}\n", .{value});
}
```

```
It's a FeatureCollection!
FeatureCollection contains 3 features
0: It's a point => [102, 0.5]
1: It's a line_string => containing 4 points
2: It's a polygon => containing 1 rings
Property: 'prop0' => PropertyValue{ .string = value0 }
Property: 'prop1' => PropertyValue{ .float = 0.0e+00 }
```


## License
[MIT](https://choosealicense.com/licenses/mit/)
