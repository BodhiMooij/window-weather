#include <metal_stdlib>
using namespace metal;

struct FrameUniforms { float2 viewport; float time; float padding; };
struct SnowVertex { float2 position; float2 material; };
struct ParticleInstance { float2 position; float radius; float opacity; float spin; float tint; };
struct DriftOut { float4 position [[position]]; float2 material; float2 point; float season; };
struct FlakeOut { float4 position [[position]]; float2 uv; float opacity; float spin; float tint; float season; };

float4 project(float2 point, constant FrameUniforms &frame) {
    return float4(point.x / frame.viewport.x * 2 - 1, 1 - point.y / frame.viewport.y * 2, 0, 1);
}

float litterHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

half3 litterColor(float kind) {
    if (kind >= 3.5) return half3(0.40, 0.44, 0.16);
    if (kind >= 2.5) return half3(0.42, 0.22, 0.08);
    if (kind >= 1.5) return half3(0.70, 0.28, 0.10);
    if (kind >= 0.5) return half3(0.89, 0.46, 0.12);
    return half3(0.93, 0.72, 0.22);
}

// One settled leaf, sized like a falling leaf and pointed so the cell does not crop it flat.
struct SettledLeaf { float mask; float kind; float x; float y; float up; };

SettledLeaf settledLeaf(float2 point, float2 cell, float2 offset) {
    float2 id = floor(point / cell + offset);
    float2 local = fract(point / cell + offset) - 0.5;
    float spin = litterHash(id + offset * 13.0);
    float shape = litterHash(id.yx + offset + 7.0);
    float angle = spin * 6.2831853;
    float cs = cos(angle);
    float sn = sin(angle);
    float2 q = float2(cs * local.x - sn * local.y, sn * local.x + cs * local.y);
    q.x *= mix(2.35, 2.85, shape);
    q.y *= mix(2.15, 2.55, spin);
    float along = clamp((q.y + 0.92) / 1.84, 0.0, 1.0);
    float profile = sin(along * 3.14159265) * smoothstep(0.0, 0.1, along);
    float teeth = 0.78 + 0.22 * sin(along * 23.0 + shape * 5.0);
    float halfWidth = profile * teeth * mix(0.5, 0.62, shape);
    float side = q.x + sin(along * 3.1) * 0.045;
    float body = 1.0 - smoothstep(halfWidth - 0.05, halfWidth + 0.02, abs(side));
    body *= smoothstep(-1.02, -0.78, q.y);
    float stem = (1.0 - smoothstep(0.035, 0.08, abs(q.x))) * smoothstep(-1.08, -0.82, q.y) * (1.0 - smoothstep(-0.25, 0.08, q.y));
    float up = saturate(-cs);
    return SettledLeaf{ max(body, stem), floor(shape * 5.0), q.x, q.y, up };
}

vertex DriftOut driftVertex(uint id [[vertex_id]], const device SnowVertex *vertices [[buffer(0)]],
                            constant FrameUniforms &frame [[buffer(1)]]) {
    SnowVertex v = vertices[id];
    return { project(v.position, frame), v.material, v.position, frame.padding };
}

fragment half4 driftFragment(DriftOut in [[stage_in]]) {
    float shade = smoothstep(0.0, 1.0, in.material.x);
    float grain = fract(52.9829189 * fract(dot(in.point, float2(0.06711056, 0.00583715))));
    half3 color;
    float alphaScale = 1.0;
    if (in.season < 0.5) {
        color = mix(half3(0.76, 0.84, 0.93), half3(0.99, 0.995, 1.0), half(shade));
        color += half((grain - 0.5) * 0.012);
    } else {
        // Same span as a falling leaf: about 7–12 points along the stem.
        float2 cell = float2(14.0, 14.0);
        SettledLeaf leaves[3] = {
            settledLeaf(in.point, cell, float2(0.0, 0.0)),
            settledLeaf(in.point, cell, float2(0.46, 0.33)),
            settledLeaf(in.point, cell, float2(0.14, 0.68))
        };
        float best = 0.0;
        float tips = 0.0;
        int pick = 0;
        for (int i = 0; i < 3; ++i) {
            float point = leaves[i].mask * smoothstep(0.15, 0.72, leaves[i].y) * smoothstep(0.05, 0.8, leaves[i].up);
            tips = max(tips, point);
            if (leaves[i].mask > best) {
                best = leaves[i].mask;
                pick = i;
            }
        }
        SettledLeaf leaf = leaves[pick];
        float along = clamp((leaf.y + 0.92) / 1.84, 0.0, 1.0);
        float patch = floor(litterHash(floor(in.point / cell)) * 5.0);
        half3 packed = litterColor(patch) * mix(half(0.58), half(0.86), half(shade));
        half3 tone = litterColor(leaf.kind);
        float mottled = litterHash(float2(floor(along * 4.0), leaf.kind + 2.0));
        tone = mix(tone * 0.74, tone * 1.08, half(mottled));
        tone = mix(tone * 0.7, tone, half(smoothstep(-0.35, 0.55, leaf.y)));
        float vein = (1.0 - smoothstep(0.018, 0.06, abs(leaf.x))) * smoothstep(-0.4, 0.05, leaf.y) * (1.0 - smoothstep(0.45, 0.78, leaf.y));
        float branch = sin(along * 16.0 + leaf.kind);
        float sideVein = (1.0 - smoothstep(0.02, 0.055, abs(abs(leaf.x) - abs(branch) * 0.28))) * step(0.22, along) * step(along, 0.82);
        tone = mix(tone, tone * 0.52, half(max(vein, sideVein * 0.65)));
        float speck = step(0.8, litterHash(floor(in.point * 0.9) + leaf.kind));
        tone = mix(tone, tone * half3(0.55, 0.32, 0.16), half(speck * best));
        float rim = smoothstep(0.08, 0.38, best) * (1.0 - smoothstep(0.8, 1.0, best));
        tone = mix(tone, tone * 0.68, half(rim));
        color = mix(packed, tone, half(smoothstep(0.12, 0.7, best)));
        // Break the flat cap: the upper edge keeps upward leaf tips and opens gaps between them.
        float crest = smoothstep(0.8, 1.0, shade);
        float crestKeep = mix(1.0, mix(0.22, 1.0, smoothstep(0.04, 0.5, tips)), crest);
        alphaScale = crestKeep;
    }
    half alpha = half(in.material.y * alphaScale);
    return half4(color * alpha, alpha);
}

vertex FlakeOut flakeVertex(uint id [[vertex_id]], uint instance [[instance_id]],
                            const device ParticleInstance *particles [[buffer(0)]],
                            constant FrameUniforms &frame [[buffer(1)]]) {
    const float2 corners[6] = { {-1,-1}, {1,-1}, {-1,1}, {1,-1}, {1,1}, {-1,1} };
    ParticleInstance p = particles[instance];
    float2 uv = corners[id];
    float c = cos(p.spin);
    float s = sin(p.spin);
    float2 turned = float2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
    float2 placed = frame.padding < 0.5 ? uv : turned;
    return { project(p.position + placed * (p.radius + 0.6), frame), uv, p.opacity, p.spin, p.tint, frame.padding };
}

fragment half4 flakeFragment(FlakeOut in [[stage_in]]) {
    if (in.season < 0.5) {
        float distance = length(in.uv);
        half alpha = half((1 - smoothstep(0.30, 1.0, distance)) * in.opacity);
        return half4(half3(0.96, 0.98, 1.0) * alpha, alpha);
    }
    float2 p = in.uv;
    float along = clamp((p.y + 0.82) / 1.7, 0.0, 1.0);
    float profile = sin(along * 3.14159265);
    profile *= smoothstep(0.0, 0.14, along);
    float halfWidth = 0.58 * profile;
    float body = 1.0 - smoothstep(halfWidth - 0.07, halfWidth + 0.015, abs(p.x));
    body *= smoothstep(-1.02, -0.78, p.y);
    body *= 1.0 - smoothstep(0.9, 1.04, p.y);
    float stem = (1.0 - smoothstep(0.04, 0.09, abs(p.x))) * smoothstep(-1.05, -0.8, p.y) * (1.0 - smoothstep(-0.15, 0.25, p.y));
    float mask = max(body, stem * 0.9);
    half alpha = half(mask * in.opacity);
    half3 gold = half3(0.93, 0.72, 0.22);
    half3 orange = half3(0.89, 0.46, 0.12);
    half3 rust = half3(0.70, 0.28, 0.10);
    half3 brown = half3(0.42, 0.22, 0.08);
    float kind = clamp(in.tint, 0.0, 3.0);
    half3 color = gold;
    if (kind >= 2.5) color = brown;
    else if (kind >= 1.5) color = rust;
    else if (kind >= 0.5) color = orange;
    color = mix(color * 0.78, color, half(smoothstep(-0.35, 0.55, p.y)));
    return half4(color * alpha, alpha);
}
