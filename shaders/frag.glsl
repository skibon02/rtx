#version 300 es

precision highp float;

in vec2 pos;

uniform float u_seed;
uniform float u_sample_count;

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


float rand(){
    float res = fract(sin(cur_seed) * 43758.5453123);
    cur_seed += 112312.1523651;
    return res;
}

//Scene
const int numSpheres = 4;
Sphere spheres[numSpheres] = Sphere[](
    Sphere(vec3(-0.75, -1.45, -4.4), 1.05, 
    Material(
        vec3(0.4, 0.8, 0.4), 
        vec3(0.0), 1.0, 0.8, false)),

    Sphere(vec3(2.0, -2.05, -3.7), 0.5, 
    Material(
        vec3(1, 1, 0.1), 
        vec3(0.0), 0.0, 0.8, true)),

    Sphere(vec3(-1.75, -1.95, -3.1), 0.6, 
    Material(
        vec3(1, 1, 1), 
        vec3(0.0), 0.0, 0.8, false)),

    Sphere(vec3(0, 17.8, -1), 15.0, 
        Material(
            vec3(0.0, 0.0, 0.0), 
            vec3(50000), 0.0, 0.8, false))
);

const int numPlanes = 6;
Plane planes[numPlanes] = Plane[](
    Plane(vec3(0, 1, 0), 2.5, 
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.0, 0.8, false)),
    Plane(vec3(0, -1, 0), 3.0,
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.0, 0.8, false)),

    //Left / Right
    Plane(vec3(1, 0, 0), 2.75,
        Material(
            vec3(1, 0.1, 0.1), 
            vec3(0.0), 0.1, 0.8, false)),
    Plane(vec3(-1, 0, 0), 2.75,
        Material(
            vec3(0.1, 1, 0.1), 
            vec3(0.0), 0.1, 0.8, false)),

    //Back / Front
    Plane(vec3(0, 0, 1), 6.0,
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.01, 0.8, false)),
    Plane(vec3(0, 0, -1), 0.5,
        Material(
            vec3(0.9, 0.9, 0.9), 
            vec3(0.0), 0.0, 0.8, false))
);

const float finalLumScale = 0.0004;

const int RAY_BOUNCE_MAX_STACK_SIZE = 25;

int depth = 0;

vec3 rayBounceStack[RAY_BOUNCE_MAX_STACK_SIZE];


Intersection intersect(Ray ray) {
    Intersection intersection;
    intersection.distance = -1.0;

    for (int i = 0; i < numSpheres; i++) {
        Sphere sphere = spheres[i];

        vec3 oc = ray.origin - sphere.center;
        float a = dot(ray.dir, ray.dir);
        float b = 2.0 * dot(oc, ray.dir);
        float c = dot(oc, oc) - sphere.radius * sphere.radius;
        float discriminant = b * b - 4.0 * a * c;

        if (discriminant > 0.0) {
            //closest point
            float t = (-b - sqrt(discriminant)) / (2.0 * a);
            if(t < 0.0)
                t = (-b + sqrt(discriminant)) / (2.0 * a);
            if (t > 0.0 && (intersection.distance < 0.0 || t < intersection.distance)) {
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
            if (t > 0.0 && (intersection.distance < 0.0 || t < intersection.distance)) {
                intersection.distance = t;
                intersection.position = ray.origin + ray.dir * t;
                intersection.normal = plane.normal;
                intersection.material = plane.material;
            }
        }
    }
    return intersection;
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

vec3 pathTrace(Ray ray) {
    int depth = 0;
    //color of ray, that flew out of the camera
    vec3 lightColor = vec3(0.8, 0.2, 0.4);

    while(depth < RAY_BOUNCE_MAX_STACK_SIZE) {
        Intersection intersection = intersect(ray);
        if(intersection.distance == -1.0) {
            break;
        }

        ray.origin = ray.origin + ray.dir * intersection.distance + intersection.normal * 0.01;
        
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
                float cosI = -dot(ray.dir, intersection.normal);
                float sinT2 = n * n * (1.0 - cosI * cosI);
                if(sinT2 > 1.0) {
                    //total internal reflection
                    ray.dir = reflect(ray.dir, intersection.normal);
                } else {
                    float cosT = sqrt(1.0 - sinT2);
                    float R = R0 + (1.0 - R0) * pow(1.0 - cosI, 5.0);
                    float T = 1.0 - R;
                    if(rand() < R) {
                        ray.dir = reflect(ray.dir, intersection.normal);
                    } else {
                        //refraction
                        ray.origin = ray.origin + intersection.normal * 0.02;
                        ray.dir = normalize(ray.dir * n + intersection.normal * (n * cosI - cosT));
                    }
                }
                rayBounceStack[depth] = intersection.material.albedo;
            } 
            else {
                if(rand() > intersection.material.reflectivity) {
                    //diffuse
                    vec3 rotX, rotY;
                    createCoordinateSystem(intersection.normal, rotX, rotY);
                    float r1 = 2.0 * 3.14159265359 * rand();
                    float r2 = rand();
                    float r2s = sqrt(r2);
                    vec3 w = intersection.normal;
                    vec3 u = rotX;
                    vec3 v = rotY;
                    vec3 d = normalize(u * cos(r1) * r2s + v * sin(r1) * r2s + w * sqrt(1.0 - r2));
                    ray.dir = d;
                    
                    float cost = dot(ray.dir, intersection.normal);
                    rayBounceStack[depth] = intersection.material.albedo * intersection.material.albedoFactor * cost;
                } else {
                    //reflection
                    float cost = dot(ray.dir, intersection.normal);
                    ray.dir = normalize(ray.dir - intersection.normal * cost * 2.0);
                    rayBounceStack[depth] = intersection.material.albedo;
                }
            }
        }
        depth++;
    }
    while(depth-- > 0) {
        lightColor *= rayBounceStack[depth];
    }
    return lightColor;
}

void main() {
    cur_seed = u_seed + pos.x * 421.24 + pos.y * 192.52;
    cur_seed *= rand();
    Ray ray;
    ray.dir = vec3(0.0, 0.0, -1.0) + vec3(pos.x*1.2, pos.y, 0.0);
    ray.dir = normalize(ray.dir);
    ray.origin = vec3(0.0, 0.0, 0.0);
    vec3 col = pathTrace(ray) * finalLumScale;
    outColor = vec4(col, 1.0);
}