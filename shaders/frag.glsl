#version 300 es

precision highp float;

in vec2 pos;

uniform vec2 u_resolution;
uniform float u_seed;
uniform sampler2D u_prev_frame;

const float PI = 3.1415926535897932384626433832795;
const float eps = 1e-5;

float cur_seed;

out vec4 outColor;

struct Material {
    vec3 albedo;
    vec3 emission;
    float reflectivity;
    float albedoFactor;
    bool isGlass;
};

struct Sphere {
    vec3 center;
    float radius;
    Material material;
};

struct Plane {
    vec3 normal;
    float distance;
    Material material;
};

struct Cube {
    vec3 min;
    vec3 max;
    Material material;
};

struct Intersection {
    vec3 position;
    vec3 normal;
    float distance;

    Material material;
};

struct Ray {
    vec3 origin;
    vec3 dir;
};

float random(vec3 scale, float seed) {
    return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
}
void createCoordinateSystem(vec3 normal, out vec3 tangent, out vec3 bitangent) {
    if (abs(normal.x) > abs(normal.z)) {
        float invLen = 1.0 / sqrt(normal.x * normal.x + normal.y * normal.y);
        tangent = vec3(-normal.y * invLen, normal.x * invLen, 0.0);
    } else {
        float invLen = 1.0 / sqrt(normal.y * normal.y + normal.z * normal.z);
        tangent = vec3(0.0, -normal.z * invLen, normal.y * invLen);
    }
    bitangent = cross(normal, tangent);
}
vec3 cosineWeightedDirection(float seed, vec3 normal) {
    // float u = random(vec3(12.9898, 78.233, 151.7182), seed);
    // float v = random(vec3(63.7264, 10.873, 623.6736), seed);
    // float r = sqrt(u);
    // float angle = 2.0 * PI * v;
    // vec3 sdir, tdir;
    // if(abs(normal.x) < .5) {
    //     sdir = cross(normal, vec3(1, 0, 0));
    // } else {
    //     sdir = cross(normal, vec3(0, 1, 0));
    // }
    // tdir = cross(normal, sdir);
    // return r * cos(angle) * sdir + r * sin(angle) * tdir + sqrt(1. - u) * normal;
    vec3 rotX, rotY;
    createCoordinateSystem(normal, rotX, rotY);
    float r1 = 2.0 * PI * random(vec3(12.9898, 78.233, 151.7182), seed);
    float r2 = random(vec3(63.7264, 10.873, 623.6736), seed);
    float r2s = sqrt(r2);
    vec3 w = normal;
    vec3 u = rotX;
    vec3 v = rotY;
    vec3 d = normalize(u * cos(r1) * r2s + v * sin(r1) * r2s + w * sqrt(1.0 - r2));
    return d;
}

//Scene
const int numSpheres = 4;
Sphere spheres[numSpheres] = Sphere[](
    //metal
    Sphere(vec3(-0.75, -1.45, -4.4), 1.05, 
    Material(
        vec3(0.8, 0.4, 0.8), 
        vec3(0.0), 1.0, 0.8, false)),

    //glass
    Sphere(vec3(2.0, -2.05, -3.7), 0.5, 
    Material(
        vec3(0.9, 1.0, 0.8), 
        vec3(0.0), 0.0, 0.8, true)),

    Sphere(vec3(-1.75, -1.95, -3.1), 0.6, 
    Material(
        vec3(1, 1, 1), 
        vec3(0.0), 0.0, 0.8, false)),

    //light
    Sphere(vec3(0, 17.8, -1), 15.0, 
        Material(
            vec3(0.0, 0.0, 0.0), 
            vec3(50000.0, 40000.0, 45000.0), 0.0, 0.8, false))
);

const int numPlanes = 6;
Plane planes[numPlanes] = Plane[](
    Plane(vec3(0, 1, 0), 2.5, 
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.6, 0.8, false)),
    Plane(vec3(0, -1, 0), 3.0,
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.0, 0.8, false)),

    //Left / Right
    Plane(vec3(1, 0, 0), 2.75,
        Material(
            vec3(1, 0.1, 0.1), 
            vec3(0.0), 0.4, 0.8, false)),
    Plane(vec3(-1, 0, 0), 2.75,
        Material(
            vec3(0.1, 1, 0.1), 
            vec3(0.0), 0.0, 0.8, false)),

    //Back / Front
    Plane(vec3(0, 0, 1), 6.0,
        Material(
            vec3(0.8, 0.8, 0.5), 
            vec3(0.0), 1.0, 0.6, false)),
    Plane(vec3(0, 0, -1), 0.5,
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.2, 0.8, false))
);

const int numCubes = 1;
Cube cubes[numCubes] = Cube[](
    Cube(vec3(2.4, 1.0, -4.5), vec3(2.6, 1.8, -3.5),
        Material(
            vec3(0.6, 0.6, 0.9), 
            vec3(0.0), 0.2, 0.8, false))
);



Intersection intersect(Ray ray) {
    Intersection intersection;
    intersection.distance = -1.0;

    for (int i = 0; i < numSpheres; i++) {
        Sphere sphere = spheres[i];

        vec3 oc = ray.origin - sphere.center;
        float b = dot(oc, ray.dir);
        float c = dot(oc, oc) - sphere.radius * sphere.radius;
        float h = b * b - c;

        if (h >= 0.0) {
            float h = sqrt(h);
            float t = -b - h;
            if(t < eps)
                t = -b + h;
            
            if (t >= eps && (intersection.distance < 0.0 || t < intersection.distance)) {
                intersection.distance = t;
                intersection.position = ray.origin + ray.dir * t;
                intersection.normal = normalize(intersection.position - sphere.center);
                intersection.material = sphere.material;
            }
        }
    }

    for (int i = 0; i < numPlanes; i++) {
        Plane plane = planes[i];

        float denom = dot(ray.dir, plane.normal);
        if (abs(denom) > 0.0001) {
            float t = -(dot(ray.origin, plane.normal) + plane.distance) / denom;
            if (t >= eps && (intersection.distance < 0.0 || t < intersection.distance)) {
                intersection.distance = t;
                intersection.position = ray.origin + ray.dir * t;
                intersection.normal = plane.normal;
                intersection.material = plane.material;
            }
        }
    }

    for (int i = 0; i < numCubes; i++) {
        Cube cube = cubes[i];

        vec3 invDir = 1.0 / ray.dir;
        vec3 tbot = invDir * (cube.min - ray.origin);
        vec3 ttop = invDir * (cube.max - ray.origin);

        vec3 tmin = min(ttop, tbot);
        vec3 tmax = max(ttop, tbot);

        float t0 = max(max(tmin.x, tmin.y), tmin.z);
        float t1 = min(min(tmax.x, tmax.y), tmax.z);

        if (t0 < t1 && t1 >= eps) {
            float t = t0;
            if (t < eps)
                t = t1;
            if (t >= eps && (intersection.distance < 0.0 || t < intersection.distance)) {
                intersection.distance = t;
                intersection.position = ray.origin + ray.dir * t;
                intersection.normal = normalize(intersection.position - ray.origin);
                intersection.material = cube.material;
            }
        }
    }
    return intersection;
}


const float finalLumScale = 0.0008;
const int MAX_BOUNCES = 15;
vec3 pathTrace(Ray ray) {
    int depth = 0;
    //color of ray, that flew out of the camera
    vec3 lightColor = vec3(0.0);
    vec3 throughput = vec3(1.0);

    while(depth < MAX_BOUNCES) {
        Intersection intersection = intersect(ray);
        if(intersection.distance == -1.0) {
            break;
        }

        ray.origin = intersection.position;
        
        //update light color and throughput
        if(intersection.material.emission != vec3(0.0)) {
            lightColor = intersection.material.emission;
            break;
        } else {
            if(intersection.material.isGlass) {
                float n = 1.5;
                float R0 = (1.0 - n) / (1.0 + n);
                R0 = R0 * R0;
                if(dot(ray.dir, intersection.normal) > 0.0) {
                    intersection.normal = -intersection.normal;
                    n = 1.0 / n;
                }
                n = 1.0 / n;
                float cost1 = (-dot(ray.dir, intersection.normal));
                float cost2 = 1.0 - n * n * (1.0 - cost1 * cost1);
                float R = R0 + (1.0 - R0) * pow(1.0 - cost1, 5.0); // Schlick's approximation
                if (cost2 > 0.0 || random(vec3(252.315, 26.236, 152.9342), cur_seed + float(depth)) > R) {
                    ray.dir = normalize(n * ray.dir + (n * cost1 - sqrt(cost2)) * intersection.normal);
                } else {
                    ray.dir = normalize(reflect(ray.dir, intersection.normal));
                }
                throughput *= intersection.material.albedo;
            } 
            else {
                if(random(vec3(52.315, 126.236, 154.9342), cur_seed + float(depth)) >= intersection.material.reflectivity) {
                //if(true) {
                    //diffuse
                    
                    ray.dir = cosineWeightedDirection(cur_seed + float(depth), intersection.normal);
                    
                    float cost = dot(ray.dir, intersection.normal);
                    throughput *= intersection.material.albedo * intersection.material.albedoFactor * cost / PI;
                } else {
                    //reflection
                    float cost = dot(ray.dir, intersection.normal);
                    ray.dir = normalize(ray.dir - intersection.normal * cost * 2.0);
                    throughput *= intersection.material.albedo * intersection.material.albedoFactor;
                }
            }
        }

        // // Russian Roulette
        // float p = max(throughput.x, max(throughput.y, throughput.z));
        // if(random(vec3(24.547, 2.1234, 425.216), cur_seed + float(depth)) >= p) {
        //     break;
        // }
        // throughput /= p;

        depth++;
    }
    return lightColor * throughput;
}
const int SAMPLES = 8;
const float aa_factor = 3.0;
void main() {
    cur_seed = u_seed;
    Ray ray;
    float fovscale = 1.0;
    if(u_resolution.y > u_resolution.x) {
        fovscale *= u_resolution.y / u_resolution.x;
    }
    ray.dir = vec3(0.0, 0.0, -1.0) + vec3(pos.x*(u_resolution.x / u_resolution.y), pos.y, 0.0) * fovscale;
    ray.dir = normalize(ray.dir);
    ray.origin = vec3(0.0, 0.0, 0.0);
    vec3 col = vec3(0.0);
    for(int i = 0; i < SAMPLES; i++) {
        if(aa_factor > 0.0) {
            ray.dir = vec3(0.0, 0.0, -1.0) + vec3(pos.x*(u_resolution.x / u_resolution.y), pos.y, 0.0) * fovscale;
            ray.dir.x += (random(vec3(525.315, 126.26, 12.42), cur_seed + float(i)) - 0.5) / u_resolution.x * aa_factor;
            ray.dir.y += (random(vec3(125.231, 162.135, 115.321), cur_seed + float(i)) - 0.5) / u_resolution.y * aa_factor;
            ray.dir = normalize(ray.dir);
            cur_seed += random(vec3(315.231, 13.5123, 125.3215), cur_seed);
        }
        col += pathTrace(ray);
    }
    col /= float(SAMPLES);
    col *=  finalLumScale;
    vec2 texCoord = pos * 0.5 + 0.5;
    vec4 oldCol = texture(u_prev_frame, texCoord);
    outColor = oldCol + vec4(col, 1.0);

}