const hittable = @import("hittable.zig");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const material = @import("material.zig");

const HitRecord = hittable.HitRecord;
const Hittable = hittable.Hittable;
const Point3 = vec3.Point3;
const Ray = ray.Ray;
const Material = material.Material;

pub const Sphere = struct {
    center: Point3,
    radius: f32,
    mat: Material,

    pub fn hit(self: *const Sphere, r: Ray, t_min: f32, t_max: f32, rec: *HitRecord) bool {
        const oc = r.origin.sub(self.center);
        const a = r.direction.length_squared();
        const half_b = oc.dot(r.direction);
        const c = oc.length_squared() - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;

        if (discriminant < 0) {
            return false;
        }

        const sqrtd = @sqrt(discriminant);
        var root = (-half_b - sqrtd) / a;
        if (root < t_min or root > t_max) {
            root = (-half_b + sqrtd) / a;
            if (root < t_min or root > t_max) {
                return false;
            }
        }

        rec.t = root;
        rec.p = r.at(rec.t);
        const outward_normal = rec.p.sub(self.center).div(self.radius);
        rec.set_face_normal(r, outward_normal);
        rec.mat = &self.mat;
        return true;
    }

    pub fn as_hittable(self: *const Sphere) Hittable {
        return .{
            .data = self,
            .hit_fn = struct {
                fn hit_wrapper(self_ptr: *const anyopaque, r: Ray, t_min: f32, t_max: f32, rec: *HitRecord) bool {
                    const sphere: *const Sphere = @alignCast(@ptrCast(self_ptr));
                    return sphere.hit(r, t_min, t_max, rec);
                }
            }.hit_wrapper,
        };
    }
};
