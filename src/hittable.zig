const std = @import("std");
const ray = @import("ray.zig");
const vec3 = @import("vec3.zig");

const Ray = ray.Ray;
const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;

pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    mat: ?*const anyopaque = null,

    pub fn set_face_normal(self: *HitRecord, r: Ray, outward_normal: Vec3) void {
        self.front_face = r.direction.dot(outward_normal) < 0;
        self.normal = if (self.front_face) outward_normal else outward_normal.mul(-1);
    }
};

pub const Hittable = struct {
    hit_fn: *const fn (self: *const anyopaque, r: Ray, t_min: f32, t_max: f32, rec: *HitRecord) bool,
    data: *const anyopaque,

    pub fn hit(self: Hittable, r: Ray, t_min: f32, t_max: f32, rec: *HitRecord) bool {
        return self.hit_fn(self.data, r, t_min, t_max, rec);
    }
};

pub const HittableList = struct {
    objects: std.ArrayList(Hittable),

    pub fn init(allocator: std.mem.Allocator) HittableList {
        return .{ .objects = std.ArrayList(Hittable).init(allocator) };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit();
    }

    pub fn add(self: *HittableList, object: Hittable) !void {
        try self.objects.append(object);
    }

    pub fn hit(self: HittableList, r: Ray, t_min: f32, t_max: f32, rec: *HitRecord) bool {
        var temp_rec: HitRecord = undefined;
        var hit_anything = false;
        var closest_so_far = t_max;

        for (self.objects.items) |object| {
            if (object.hit(r, t_min, closest_so_far, &temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec.* = temp_rec;
            }
        }

        return hit_anything;
    }
};
