const std = @import("std");

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn mul(a: Vec3, s: f32) Vec3 {
        return .{ .x = a.x * s, .y = a.y * s, .z = a.z * s };
    }

    pub fn div(a: Vec3, s: f32) Vec3 {
        return mul(a, 1.0 / s);
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length_squared(self: Vec3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn length(self: Vec3) f32 {
        return std.math.sqrt(self.length_squared());
    }

    pub fn unit_vector(self: Vec3) Vec3 {
        return self.div(self.length());
    }

    pub fn near_zero(self: Vec3) bool {
        const s = 1e-8;
        return @abs(self.x) < s and @abs(self.y) < s and @abs(self.z) < s;
    }

    pub fn mulv(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
    }
};

pub const Color = Vec3;
pub const Point3 = Vec3;
