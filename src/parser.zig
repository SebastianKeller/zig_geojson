const std = @import("std");
const types = @import("types.zig");

const ErrorSet = error{InvalidGeoJson} || @TypeOf(std.json.Parser.parse).ReturnType.ErrorSet;
const log_tag = .zig_geojson;

pub const Parser = struct {
    pub fn parse(
        json_text: []const u8,
        allocator: *std.mem.Allocator,
    ) ErrorSet!types.GeoJson {
        var json_parser = std.json.Parser.init(allocator, false);
        defer json_parser.deinit();

        var json = json_parser.parse(json_text) catch |err| {
            std.log.err(log_tag, "Unable to parse json\n", .{});
            return err;
        };
        defer json.deinit();

        return parseJson(json, allocator);
    }

    pub fn parseJson(
        json: std.json.ValueTree,
        child_allocator: *std.mem.Allocator,
    ) ErrorSet!types.GeoJson {
        var arena = std.heap.ArenaAllocator.init(child_allocator);
        var allocator = &arena.allocator;

        const t = json.root.Object.get("type").?.String;
        if (std.mem.eql(u8, "Feature", t)) {
            return types.GeoJson{
                .content = .{ .feature = try parseFeature(json.root, allocator) },
                .arena = arena,
            };
        }

        if (std.mem.eql(u8, "FeatureCollection", t)) {
            const features = json.root.Object.get("features").?;
            return types.GeoJson{
                .content = .{ .featureCollection = try parseFeatures(features, allocator) },
                .arena = arena,
            };
        }

        // this json is a geometry only
        return types.GeoJson{
            .content = .{ .geometry = try parseGeometry(json.root, allocator) },
            .arena = arena,
        };
    }

    fn parseFeatures(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ![]types.Feature {
        var json_array = value.Array;
        var features = try allocator.alloc(types.Feature, json_array.items.len);
        for (json_array.items) |item, idx| {
            features[idx] = try parseFeature(item, allocator);
        }
        return features;
    }

    fn parseFeature(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.Feature {
        return types.Feature{
            .geometry = try parseGeometry(value.Object.get("geometry").?, allocator),
            .properties = null,
            .identifier = null,
        };
    }

    fn parseGeometry(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ErrorSet!types.Geometry {
        var t = value.Object.get("type").?.String;

        if (std.mem.eql(u8, "Point", t)) {
            return types.Geometry{ .point = try parsePoint(value, allocator) };
        } else if (std.mem.eql(u8, "Polygon", t)) {
            return types.Geometry{ .polygon = try parsePolygon(value, allocator) };
        } else if (std.mem.eql(u8, "LineString", t)) {
            return types.Geometry{ .line_string = try parseLineString(value, allocator) };
        } else if (std.mem.eql(u8, "MultiLineString", t)) {
            return types.Geometry{ .multi_line_string = try parseMultiLineString(value, allocator) };
        } else if (std.mem.eql(u8, "MultiPolygon", t)) {
            return types.Geometry{ .multi_polygon = try parseMultiPolygon(value, allocator) };
        } else if (std.mem.eql(u8, "MultiPoint", t)) {
            return types.Geometry{ .multi_point = try parseMultiPoint(value, allocator) };
        } else if (std.mem.eql(u8, "GeometryCollection", t)) {
            return types.Geometry{ .geometry_collection = try parseGeometryCollection(value, allocator) };
        }

        std.log.err(log_tag, "Missing implementation for geometry of type '{}'\n", .{t});
        return ErrorSet.InvalidGeoJson;
    }

    fn parseMultiPoint(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.MultiPoint {
        const coordinates = value.Object.get("coordinates").?;
        return types.MultiPoint{ .points = try parsePoints(coordinates, allocator) };
    }

    fn parseLineString(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.LineString {
        var coordinates = value.Object.get("coordinates").?;
        return types.LineString{ .points = try parsePoints(coordinates, allocator) };
    }

    inline fn parseLineStringRaw(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.LineString {
        return types.LineString{ .points = try parsePoints(value, allocator) };
    }

    fn parseMultiLineString(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.MultiLineString {
        var coordinates = value.Object.get("coordinates").?.Array;
        var lineStrings = try allocator.alloc(types.LineString, coordinates.items.len);
        for (coordinates.items) |item, idx| {
            lineStrings[idx] = try parseLineStringRaw(item, allocator);
        }
        return types.MultiLineString{ .lineStrings = lineStrings };
    }

    fn parseMultiPolygon(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.MultiPoligon {
        var coordinates = value.Object.get("coordinates").?.Array;
        var polygons = try allocator.alloc(types.Polygon, coordinates.items.len);
        for (coordinates.items) |item, idx| {
            polygons[idx] = try parsePolygonRaw(item, allocator);
        }
        return types.MultiPoligon{ .polygons = polygons };
    }

    inline fn parsePolygonRaw(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.Polygon {
        var array = value.Array;
        var rings = try allocator.alloc(types.LinearRing, array.items.len);
        for (array.items) |item, idx| {
            rings[idx] = try parseLinearRingRaw(item, allocator);
        }
        return types.Polygon{ .rings = rings };
    }

    fn parsePolygon(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.Polygon {
        var coordinates = value.Object.get("coordinates").?.Array;
        var rings = try allocator.alloc(types.LinearRing, coordinates.items.len);
        for (coordinates.items) |item, idx| {
            rings[idx] = try parseLinearRingRaw(item, allocator);
        }
        return types.Polygon{ .rings = rings };
    }

    inline fn parseLinearRingRaw(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.LinearRing {
        return types.LinearRing{ .points = try parsePoints(value, allocator) };
    }

    fn parseGeometryCollection(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.GeometryCollection {
        var array = value.Object.get("geometries").?.Array;
        var geometries = try allocator.alloc(types.Geometry, array.items.len);
        for (array.items) |item, idx| {
            geometries[idx] = try parseGeometry(item, allocator);
        }
        return types.GeometryCollection{ .geometries = geometries };
    }

    fn parsePoint(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !types.Point {
        var coordinates = value.Object.get("coordinates").?;
        return parsePointRaw(coordinates);
    }

    inline fn parsePoints(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ![]types.Point {
        var array = value.Array;
        var points = try allocator.alloc(types.Point, array.items.len);
        for (array.items) |json, idx| {
            points[idx] = try parsePointRaw(json);
        }
        return points;
    }

    inline fn parsePointRaw(value: std.json.Value) !types.Point {
        var array = value.Array;
        var first = array.items[0];
        var second = array.items[1];

        return types.Point{ .x = try parseFloat(first), .y = try parseFloat(second) };
    }

    fn parseFloat(
        value: std.json.Value,
    ) ErrorSet!f64 {
        return switch (value) {
            .Integer => @intToFloat(f64, value.Integer),
            .Float => value.Float,
            else => {
                std.log.err(log_tag, "Invalid geojson. Expected Integer or Float, actual {}\n", .{value});
                return ErrorSet.InvalidGeoJson;
            },
        };
    }

};

test "simple feature" {
    var file_content = @embedFile("../test/simple_feature.json");
    var geojson = try Parser.parse(file_content, std.heap.page_allocator);
    geojson.deinit();
}

test "countries.json parse test" {
    var file_content = @embedFile("../test/countries.json");
    var geojson = try Parser.parse(file_content, std.heap.page_allocator);
    geojson.deinit();
}

test "all_geometries.json parse test" {
    var file_content = @embedFile("../test/all_geometries.json");
    var geojson = try Parser.parse(file_content, std.heap.page_allocator);
    geojson.deinit();
}

test "leaks" {
    var file_content = @embedFile("../test/all_geometries.json");
    var geojson = try Parser.parse(file_content, std.testing.allocator);
    geojson.deinit();
}
