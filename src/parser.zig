const std = @import("std");
const types = @import("types.zig");

const ErrorSet = error{InvalidGeoJson} || @TypeOf(std.json.Parser.parse).ReturnType.ErrorSet;
const log_tag = .zig_geojson;

pub fn parse_json(
    json: std.json.ValueTree,
    allocator: *std.mem.Allocator,
) ErrorSet![]types.Feature {
    const t = json.root.Object.get("type").?.String;
    if (std.mem.eql(u8, "Feature", t)) {
        var features = try allocator.alloc(types.Feature, 1);
        features[0] = try parse_feature(json.root, allocator);
        return features;
    }

    const features = json.root.Object.get("features").?;
    return try parse_features(features, allocator);
}

pub fn parse_string(
    json_text: []const u8,
    json_alloc: *std.mem.Allocator,
    result_alloc: *std.mem.Allocator,
) ErrorSet![]types.Feature {
    var json_parser = std.json.Parser.init(json_alloc, false);
    defer json_parser.deinit();

    var json = json_parser.parse(json_text) catch |err| {
        std.log.err(log_tag, "Unable to parse json\n", .{});
        return err;
    };
    defer json.deinit();
    return parse_json(json, result_alloc);
}

fn parse_features(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) ![]types.Feature {
    var jsonArray = value.Array;
    var features = try allocator.alloc(types.Feature, jsonArray.items.len);
    for (jsonArray.items) |item, idx| {
        features[idx] = try parse_feature(item, allocator);
    }
    return features;
}

fn parse_feature(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.Feature {
    return types.Feature{
        .geometry = try parse_geometry(value.Object.get("geometry").?, allocator),
        .properties = null,
        .identifier = null,
    };
}

fn parse_geometry(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) ErrorSet!types.Geometry {
    var t = value.Object.get("type").?.String;

    if (std.mem.eql(u8, "Point", t)) {
        return types.Geometry{ .point = try parse_point(value, allocator) };
    } else if (std.mem.eql(u8, "Polygon", t)) {
        return types.Geometry{ .polygon = try parse_polygon(value, allocator) };
    } else if (std.mem.eql(u8, "LineString", t)) {
        return types.Geometry{ .line_string = try parse_line_string(value, allocator) };
    } else if (std.mem.eql(u8, "MultiLineString", t)) {
        return types.Geometry{ .multi_line_string = try parse_multi_line_string(value, allocator) };
    } else if (std.mem.eql(u8, "MultiPolygon", t)) {
        return types.Geometry{ .multi_polygon = try parse_multi_polygon(value, allocator) };
    } else if (std.mem.eql(u8, "MultiPoint", t)) {
        return types.Geometry{ .multi_point = try parse_multi_point(value, allocator) };
    } else if (std.mem.eql(u8, "GeometryCollection", t)) {
        return types.Geometry{ .geometry_collection = try parse_geometry_collection(value, allocator) };
    }

    std.log.err(log_tag, "Missing implementation for geometry of type '{}'\n", .{t});
    return ErrorSet.InvalidGeoJson;
}

fn parse_float(
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

inline fn parse_point_raw(value: std.json.Value) !types.Point {
    var array = value.Array;
    var first = array.items[0];
    var second = array.items[1];

    return types.Point{ .x = try parse_float(first), .y = try parse_float(second) };
}

fn parse_point(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.Point {
    var coordinates = value.Object.get("coordinates").?;
    return parse_point_raw(coordinates);
}

inline fn parse_points(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) ![]types.Point {
    var array = value.Array;
    var points = try allocator.alloc(types.Point, array.items.len);
    for (array.items) |json, idx| {
        points[idx] = try parse_point_raw(json);
    }
    return points;
}

fn parse_multi_point(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.MultiPoint {
    var coordinates = value.Object.get("coordinates").?;
    return types.MultiPoint{ .points = try parse_points(coordinates, allocator) };
}

fn parse_line_string(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.LineString {
    var coordinates = value.Object.get("coordinates").?;
    return types.LineString{ .points = try parse_points(coordinates, allocator) };
}

inline fn parse_line_string_raw(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.LineString {
    return types.LineString{ .points = try parse_points(value, allocator) };
}

fn parse_multi_line_string(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.MultiLineString {
    var coordinates = value.Object.get("coordinates").?.Array;
    var lineStrings = try allocator.alloc(types.LineString, coordinates.items.len);
    for (coordinates.items) |item, idx| {
        lineStrings[idx] = try parse_line_string_raw(item, allocator);
    }
    return types.MultiLineString{ .lineStrings = lineStrings };
}

fn parse_multi_polygon(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.MultiPoligon {
    var coordinates = value.Object.get("coordinates").?.Array;
    var polygons = try allocator.alloc(types.Polygon, coordinates.items.len);
    for (coordinates.items) |item, idx| {
        polygons[idx] = try parse_polygon_raw(item, allocator);
    }
    return types.MultiPoligon{ .polygons = polygons };
}

inline fn parse_polygon_raw(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.Polygon {
    var array = value.Array;
    var rings = try allocator.alloc(types.LinearRing, array.items.len);
    for (array.items) |item, idx| {
        rings[idx] = try parse_linear_ring_raw(item, allocator);
    }
    return types.Polygon{ .rings = rings };
}

fn parse_polygon(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.Polygon {
    var coordinates = value.Object.get("coordinates").?.Array;
    var rings = try allocator.alloc(types.LinearRing, coordinates.items.len);
    for (coordinates.items) |item, idx| {
        rings[idx] = try parse_linear_ring_raw(item, allocator);
    }
    return types.Polygon{ .rings = rings };
}

inline fn parse_linear_ring_raw(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.LinearRing {
    return types.LinearRing{ .points = try parse_points(value, allocator) };
}

fn parse_geometry_collection(
    value: std.json.Value,
    allocator: *std.mem.Allocator,
) !types.GeometryCollection {
    var array = value.Object.get("geometries").?.Array;
    var geometries = try allocator.alloc(types.Geometry, array.items.len);
    for (array.items) |item, idx| {
        geometries[idx] = try parse_geometry(item, allocator);
    }
    return types.GeometryCollection{ .geometries = geometries };
}

test "simple feature" {
    var file_content = @embedFile("../test/simple_feature.json");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var features = try parse_string(file_content, std.testing.allocator, allocator);
}

test "countries.json parse test" {
    var file_content = @embedFile("../test/countries.json");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var features = try parse_string(file_content, allocator, allocator);
}

test "all_geometries.json parse test" {
    var file_content = @embedFile("../test/all_geometries.json");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var features = try parse_string(file_content, allocator, allocator);
}
