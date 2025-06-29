const vec3 = @import("vec3.zig");
const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;

pub const Ray = struct {
    origin: Point3,
    direction: Vec3,

    pub fn at(self: Ray, t: f32) Point3 {
        return self.origin.add(self.direction.mul(t));
    }
};
