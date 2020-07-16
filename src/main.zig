const std = @import("std");

const ErrorSet = error{InvalidGeoJson} || @TypeOf(std.json.Parser.parse).ReturnType.ErrorSet;
const log_tag = .zig_geojson;

pub const Parser = struct {
    pub fn parse(
        json_text: []const u8,
        allocator: *std.mem.Allocator,
    ) ErrorSet!GeoJson {
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
    ) ErrorSet!GeoJson {
        const root = json.root;

        var arena = std.heap.ArenaAllocator.init(child_allocator);
        const allocator = &arena.allocator;

        const bbox = if (root.Object.get("bbox")) |value|
            try parseBoundingBox(value, allocator)
        else
            null;

        if (root.Object.get("type")) |contentType| {
            const t = contentType.String;
            if (std.mem.eql(u8, "Feature", t)) {
                return GeoJson{
                    .content = .{ .feature = try parseFeature(root, allocator) },
                    .bbox = bbox,
                    .arena = arena,
                };
            }

            if (std.mem.eql(u8, "FeatureCollection", t)) {
                const features = root.Object.get("features").?;
                return GeoJson{
                    .content = .{ .feature_collection = try parseFeatures(features, allocator) },
                    .bbox = bbox,
                    .arena = arena,
                };
            }

            // this json is a geometry only
            return GeoJson{
                .content = .{ .geometry = try parseGeometry(root, allocator) },
                .bbox = bbox,
                .arena = arena,
            };
        }

        return GeoJson{
            .content = .empty,
            .bbox = bbox,
            .arena = arena,
        };
    }

    fn parseBoundingBox(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !BBox {
        const json_array = value.Array;
        return BBox{
            .min = Point{
                .x = try parseFloat(json_array.items[0]),
                .y = try parseFloat(json_array.items[1]),
            },
            .max = Point{
                .x = try parseFloat(json_array.items[2]),
                .y = try parseFloat(json_array.items[3]),
            },
        };
    }

    fn parseFeatures(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ![]Feature {
        const json_array = value.Array;
        const features = try allocator.alloc(Feature, json_array.items.len);
        for (json_array.items) |item, idx| {
            features[idx] = try parseFeature(item, allocator);
        }
        return features;
    }

    fn parseFeature(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !Feature {
        return Feature{
            .geometry = try parseGeometry(value.Object.get("geometry").?, allocator),
            .properties = try parseProperties(value.Object.get("properties"), allocator),
            .id = try parseIdentifier(value.Object.get("id"), allocator),
        };
    }

    fn parseIdentifier(
        value: ?std.json.Value,
        allocator: *std.mem.Allocator,
    ) !?Identifier {
        if (value) |v| {
            return switch (v) {
                .String => |s| Identifier{ .string = try std.mem.dupe(allocator, u8, s) },
                .Integer => |i| Identifier{ .int = i },
                .Float => |f| Identifier{ .float = f },
                else => null,
            };
        }

        return null;
    }

    fn parseProperties(
        value: ?std.json.Value,
        allocator: *std.mem.Allocator,
    ) !?std.StringHashMap(PropertyValue) {
        if (value == null) {
            return null;
        } else {
            const pValue = try parsePropertiesValue(value.?, allocator);
            return pValue.object;
        }
    }

    fn parsePropertiesValue(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ErrorSet!PropertyValue {
        switch (value) {
            .Null => return PropertyValue.@"null",
            .Bool => |b| return PropertyValue{ .bool = b },
            .Integer => |i| return PropertyValue{ .int = i },
            .Float => |f| return PropertyValue{ .float = f },
            .String => |s| return PropertyValue{ .string = try std.mem.dupe(allocator, u8, s) },
            .Array => |arr| {
                const array = try allocator.alloc(PropertyValue, arr.items.len);
                for (arr.items) |item, idx| {
                    const pValue = try parsePropertiesValue(item, allocator);
                    array[idx] = pValue;
                }
                return PropertyValue{ .array = array };
            },
            .Object => |o| {
                var hashmap = std.StringHashMap(PropertyValue).init(allocator);
                for (o.items()) |kv| {
                    const pValue = try parsePropertiesValue(kv.value, allocator);
                    try hashmap.put(kv.key, pValue);
                }
                return PropertyValue{ .object = hashmap };
            },
        }
    }

    fn parseGeometry(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ErrorSet!Geometry {
        const t = value.Object.get("type").?.String;

        if (std.mem.eql(u8, "Point", t)) {
            return Geometry{ .point = try parsePoint(value, allocator) };
        } else if (std.mem.eql(u8, "Polygon", t)) {
            return Geometry{ .polygon = try parsePolygon(value, allocator) };
        } else if (std.mem.eql(u8, "LineString", t)) {
            return Geometry{ .line_string = try parseLineString(value, allocator) };
        } else if (std.mem.eql(u8, "MultiLineString", t)) {
            return Geometry{ .multi_line_string = try parseMultiLineString(value, allocator) };
        } else if (std.mem.eql(u8, "MultiPolygon", t)) {
            return Geometry{ .multi_polygon = try parseMultiPolygon(value, allocator) };
        } else if (std.mem.eql(u8, "MultiPoint", t)) {
            return Geometry{ .multi_point = try parseMultiPoint(value, allocator) };
        } else if (std.mem.eql(u8, "GeometryCollection", t)) {
            return Geometry{ .geometry_collection = try parseGeometryCollection(value, allocator) };
        }

        std.log.err(log_tag, "Missing implementation for geometry of type '{}'\n", .{t});
        return ErrorSet.InvalidGeoJson;
    }

    fn parsePoint(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !Point {
        const coordinates = value.Object.get("coordinates").?;
        return parsePointRaw(coordinates);
    }

    fn parseMultiPoint(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !MultiPoint {
        const coordinates = value.Object.get("coordinates").?;
        return try parsePoints(coordinates, allocator);
    }

    fn parsePolygon(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !Polygon {
        const coordinates = value.Object.get("coordinates").?.Array;
        const rings = try allocator.alloc([]Point, coordinates.items.len);
        for (coordinates.items) |item, idx| {
            rings[idx] = try parsePoints(item, allocator);
        }
        return rings;
    }

    fn parseMultiPolygon(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !MultiPolygon {
        const coordinates = value.Object.get("coordinates").?.Array;
        const polygons = try allocator.alloc(Polygon, coordinates.items.len);
        for (coordinates.items) |item, idx| {
            polygons[idx] = try parsePolygonRaw(item, allocator);
        }
        return polygons;
    }

    fn parseLineString(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !LineString {
        const coordinates = value.Object.get("coordinates").?;
        return try parsePoints(coordinates, allocator);
    }

    fn parseMultiLineString(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !MultiLineString {
        const coordinates = value.Object.get("coordinates").?.Array;
        const lineStrings = try allocator.alloc([]Point, coordinates.items.len);
        for (coordinates.items) |item, idx| {
            lineStrings[idx] = try parsePoints(item, allocator);
        }
        return lineStrings;
    }

    fn parseGeometryCollection(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !GeometryCollection {
        const array = value.Object.get("geometries").?.Array;
        const geometries = try allocator.alloc(Geometry, array.items.len);
        for (array.items) |item, idx| {
            geometries[idx] = try parseGeometry(item, allocator);
        }
        return geometries;
    }

    inline fn parsePolygonRaw(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) !Polygon {
        const array = value.Array;
        const rings = try allocator.alloc([]Point, array.items.len);
        for (array.items) |item, idx| {
            rings[idx] = try parsePoints(item, allocator);
        }
        return rings;
    }

    inline fn parsePoints(
        value: std.json.Value,
        allocator: *std.mem.Allocator,
    ) ![]Point {
        const array = value.Array;
        const points = try allocator.alloc(Point, array.items.len);
        for (array.items) |json, idx| {
            points[idx] = try parsePointRaw(json);
        }
        return points;
    }

    inline fn parsePointRaw(value: std.json.Value) !Point {
        const array = value.Array;
        const first = array.items[0];
        const second = array.items[1];

        return Point{ .x = try parseFloat(first), .y = try parseFloat(second) };
    }

    inline fn parseFloat(
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

pub const GeoJson = struct {
    arena: std.heap.ArenaAllocator,
    bbox: ?BBox,
    content: union(enum) {
        empty: void,
        feature: Feature,
        feature_collection: FeatureCollection,
        geometry: Geometry,
    },

    pub fn feature(self: @This()) ?Feature {
        if (self.content == .feature) {
            return self.content.feature;
        }
        return null;
    }

    pub fn featureCollection(self: @This()) ?FeatureCollection {
        if (self.content == .feature_collection) {
            return self.content.feature_collection;
        }
        return null;
    }

    pub fn geometry(self: @This()) ?Geometry {
        if (self.content == .geometry) {
            return self.content.geometry;
        }
        return null;
    }

    pub fn deinit(self: *GeoJson) void {
        self.arena.deinit();
    }
};

pub const Feature = struct {
    geometry: Geometry,
    properties: ?std.StringHashMap(PropertyValue),
    id: ?Identifier,
};

pub const FeatureCollection = []Feature;

pub const BBox = struct {
    min: Point,
    max: Point,
};

pub const Geometry = union(enum) {
    point: Point,
    line_string: []Point,
    polygon: Polygon,
    multi_point: MultiPoint,
    multi_line_string: MultiLineString,
    multi_polygon: MultiPolygon,
    geometry_collection: GeometryCollection,
};

pub const Point = struct { x: f64, y: f64 };
pub const MultiPoint = []Point;
pub const LineString = []Point;
pub const MultiLineString = []LineString;
pub const Polygon = [][]Point;
pub const MultiPolygon = []Polygon;
pub const GeometryCollection = []Geometry;

pub const PropertyValue = union(enum) {
    array: []PropertyValue,
    @"null": void,
    bool: bool,
    int: i64,
    float: f64,
    string: []const u8,
    object: std.StringHashMap(PropertyValue),
};

pub const Identifier = union(enum) {
    int: i64,
    float: f64,
    string: []const u8,
};
