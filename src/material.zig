const std = @import("std");
const Random = std.Random;
const ray = @import("ray.zig");
const vec3 = @import("vec3.zig");
const hittable = @import("hittable.zig");

const Ray = ray.Ray;
const Color = vec3.Color;
const HitRecord = hittable.HitRecord;
const DefaultPrng = Random.DefaultPrng;

pub const Material = struct {
    scatter_fn: *const fn(self: *const anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool,
    emitted_fn: ?*const fn(self: *const anyopaque, rec: *const HitRecord) Color = null,
    data: *const anyopaque,

    pub fn scatter(self: Material, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
        return self.scatter_fn(self.data, r_in, rec, attenuation, scattered, rng);
    }
    pub fn emitted(self: Material, rec: *const HitRecord) Color {
        if (self.emitted_fn) |f| {
            return f(self.data, rec);
        }
        return Color.new(0, 0, 0);
    }
};

pub const Lambertian = struct {
    albedo: Color,

    pub fn scatter(self: *const Lambertian, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
        _ = r_in;
        var scatter_direction = rec.normal.add(random_unit_vector(rng));
        if (scatter_direction.near_zero()) scatter_direction = rec.normal;
        scattered.* = Ray{ .origin = rec.p, .direction = scatter_direction };
        attenuation.* = self.albedo;
        return true;
    }

    pub fn as_material(self: *const Lambertian) Material {
        return .{
            .data = self,
            .scatter_fn = struct {
                fn scatter_wrapper(self_ptr: *const anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
                    const mat: *const Lambertian = @alignCast(@ptrCast(self_ptr));
                    return mat.scatter(r_in, rec, attenuation, scattered, rng);
                }
            }.scatter_wrapper,
        };
    }
};

pub const Metal = struct {
    albedo: Color,
    fuzz: f32,

    pub fn scatter(self: *const Metal, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
        const reflected = reflect(r_in.direction.unit_vector(), rec.normal);
        scattered.* = Ray{ .origin = rec.p, .direction = reflected.add(random_in_unit_sphere(rng).mul(self.fuzz)) };
        attenuation.* = self.albedo;
        return scattered.direction.dot(rec.normal) > 0;
    }

    pub fn as_material(self: *const Metal) Material {
        return .{
            .data = self,
            .scatter_fn = struct {
                fn scatter_wrapper(self_ptr: *const anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
                    const mat: *const Metal = @alignCast(@ptrCast(self_ptr));
                    return mat.scatter(r_in, rec, attenuation, scattered, rng);
                }
            }.scatter_wrapper,
        };
    }
};

pub const Dielectric = struct {
    ir: f32, // Index of Refraction
    pub fn scatter(self: *const Dielectric, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
        attenuation.* = Color.new(1.0, 1.0, 1.0);
        const refraction_ratio = if (rec.front_face) (1.0 / self.ir) else self.ir;
        const unit_direction = r_in.direction.unit_vector();
        const cos_theta = @min(unit_direction.mul(-1).dot(rec.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
        const cannot_refract = refraction_ratio * sin_theta > 1.0;
        var direction: @import("vec3.zig").Vec3 = undefined;
        if (cannot_refract or reflectance(cos_theta, refraction_ratio) > rng.random().float(f32)) {
            direction = reflect(unit_direction, rec.normal);
        } else {
            direction = refract(unit_direction, rec.normal, refraction_ratio);
        }
        scattered.* = Ray{ .origin = rec.p, .direction = direction };
        return true;
    }
    pub fn as_material(self: *const Dielectric) Material {
        return .{
            .data = self,
            .scatter_fn = struct {
                fn scatter_wrapper(self_ptr: *const anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
                    const mat: *const Dielectric = @alignCast(@ptrCast(self_ptr));
                    return mat.scatter(r_in, rec, attenuation, scattered, rng);
                }
            }.scatter_wrapper,
        };
    }
};

pub const Emission = struct {
    color: Color,
    pub fn emitted(self: *const Emission, rec: *const HitRecord) Color {
        // Only emit if the ray hits the front face
        return if (rec.front_face) self.color else Color.new(0, 0, 0);
    }
    pub fn as_material(self: *const Emission) Material {
        return .{
            .data = self,
            .scatter_fn = struct {
                fn scatter_wrapper(self_ptr: *const anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray, rng: *DefaultPrng) bool {
                    _ = self_ptr;
                    _ = r_in;
                    _ = rec;
                    _ = attenuation;
                    _ = scattered;
                    _ = rng;
                    return false;
                }
            }.scatter_wrapper,
            .emitted_fn = struct {
                fn emitted_wrapper(self_ptr: *const anyopaque, rec: *const HitRecord) Color {
                    const em: *const Emission = @alignCast(@ptrCast(self_ptr));
                    return em.emitted(rec);
                }
            }.emitted_wrapper,
        };
    }
};

fn reflect(v: vec3.Vec3, n: vec3.Vec3) vec3.Vec3 {
    return v.sub(n.mul(2 * v.dot(n)));
}

fn random_unit_vector(rng: *DefaultPrng) vec3.Vec3 {
    const a = rng.random().float(f32) * 2.0 * std.math.pi;
    const z = rng.random().float(f32) * 2.0 - 1.0;
    const r = std.math.sqrt(1.0 - z * z);
    return vec3.Vec3.new(r * std.math.cos(a), r * std.math.sin(a), z);
}

fn random_in_unit_sphere(rng: *DefaultPrng) vec3.Vec3 {
    while (true) {
        const p = vec3.Vec3.new(rng.random().float(f32) * 2 - 1, rng.random().float(f32) * 2 - 1, rng.random().float(f32) * 2 - 1);
        if (p.length_squared() >= 1) continue;
        return p;
    }
}

fn refract(uv: @import("vec3.zig").Vec3, n: @import("vec3.zig").Vec3, etai_over_etat: f32) @import("vec3.zig").Vec3 {
    const cos_theta = @min(uv.mul(-1).dot(n), 1.0);
    const r_out_perp = uv.add(n.mul(cos_theta)).mul(etai_over_etat);
    const r_out_parallel = n.mul(-@sqrt(@abs(1.0 - r_out_perp.length_squared())));
    return r_out_perp.add(r_out_parallel);
}

fn reflectance(cosine: f32, ref_idx: f32) f32 {
    // Schlick's approximation
    var r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * std.math.pow(f32, 1.0 - cosine, 5.0);
}

// Helper for near-zero vector
pub fn near_zero(self: vec3.Vec3) bool {
    const s = 1e-8;
    return std.math.abs(self.x) < s and std.math.abs(self.y) < s and std.math.abs(self.z) < s;
}
