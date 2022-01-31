# zig_geojson

A library for parsing [GeoJSON](http://geojson.org) in zig.

## Example
```zig
pub fn main() void {
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
        std.log.err("Could not parse geojson! {}", .{err});
        return;
    };
    defer geojson.deinit();

    // switch on the content if you don't already know the type
    switch (geojson.content) {
        .feature => std.log.debug("It's a Feature!", .{}),
        .feature_collection => std.log.debug("It's a FeatureCollection!", .{}),
        .geometry => std.log.debug("It's a Geometry!", .{}),
    }

    // there are helper methods `featureCollection()`, `feature()`, and `geometry()`, returning optionals
    if (geojson.featureCollection()) |collection| {
        std.log.debug("FeatureCollection contains {} features", .{collection.len});

        for (collection) |feature, idx| {
            switch (feature.geometry) {
                .point => |value| std.log.debug("{}: It's a Point! {d:.1}", .{ idx, value }),
                .multi_point => |value| std.log.debug("{}: It's a MultiPoint! {d:.1}", .{idx, value}),
                .line_string => |value| std.log.debug("{}: It's a LineString! {d:.1}", .{idx, value}),
                .multi_line_string => |value| std.log.debug("{}: It's a MultiLineString! {d:.1}", .{idx, value}),
                .polygon => |value| std.log.debug("{}: It's a Polygon! {d:.1}", .{idx, value}),
                .multi_polygon => |value| std.log.debug("{}: It's a MultiPolygon! {d:.1}", .{idx, value}),
                .geometry_collection => |value| std.log.debug("{}: It's a GeometryCollection! {d:.1}", .{idx, value}),
                .@"null" => continue,
            }
        }

        // accessing properties (safe)
        const feature = collection[0];
        if (feature.properties) |properties| {
            if (properties.get("prop0")) |value| {
                std.log.debug("Property: 'prop0' => {}", .{value});
            }
        }

        // or unsafe
        const value = collection[1].properties.?.get("prop1").?;
        std.log.debug("Property: 'prop1' => {}", .{value});
    }
}
```

```
debug: It's a FeatureCollection!
debug: FeatureCollection contains 3 features
debug: 0: It's a Point! { 102.0, 0.5 }
debug: 1: It's a LineString! { { 102.0, 0.0 }, { 103.0, 1.0 }, { 104.0, 0.0 }, { 105.0, 1.0 } }
debug: 2: It's a Polygon! { { { 100.0, 0.0 }, { 101.0, 0.0 }, { 101.0, 1.0 }, { 100.0, 1.0 }, { 100.0, 0.0 } } }
debug: Property: 'prop0' => PropertyValue{ .string = { 118, 97, 108, 117, 101, 48 } }
debug: Property: 'prop1' => PropertyValue{ .float = 0.0e+00 }
```


## License
[MIT](https://choosealicense.com/licenses/mit/)
