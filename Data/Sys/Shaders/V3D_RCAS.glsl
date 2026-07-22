// Lightweight RCAS-style second pass for the V3D SGSR1 contrast candidate.

void main()
{
  float2 uv = GetCoordinates();
  float2 pixel = GetInvResolution();
  float3 b = textureLod(samp0, float3(uv + float2(0.0, -pixel.y), GetLayer()), 0.0).xyz;
  float3 d = textureLod(samp0, float3(uv + float2(-pixel.x, 0.0), GetLayer()), 0.0).xyz;
  float3 e = textureLod(samp0, float3(uv, GetLayer()), 0.0).xyz;
  float3 f = textureLod(samp0, float3(uv + float2(pixel.x, 0.0), GetLayer()), 0.0).xyz;
  float3 h = textureLod(samp0, float3(uv + float2(0.0, pixel.y), GetLayer()), 0.0).xyz;

  float3 minimum = min(min(b, d), min(f, h));
  float3 maximum = max(max(b, d), max(f, h));
  float3 hit_minimum = minimum / max(float3(4.0) * maximum, float3(1.0e-5));
  float3 hit_maximum = (float3(1.0) - maximum) /
                       max(float3(4.0) * minimum - float3(4.0), float3(-1.0e-5));
  float3 lobe_rgb = max(-hit_minimum, hit_maximum);
  float lobe = max(-0.1875, min(max(lobe_rgb.r, max(lobe_rgb.g, lobe_rgb.b)), 0.0));
  lobe *= 0.35;
  float reciprocal = 1.0 / max(4.0 * lobe + 1.0, 1.0e-5);
  float3 sharpened = (lobe * (b + d + f + h) + e) * reciprocal;
  SetOutput(float4(clamp(sharpened, 0.0, 1.0), 1.0));
}
