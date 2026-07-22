// Lightweight duplicate-VI frame generation for V3D.
// samp0 is the previous real SGSR2 output; samp1 is the current real SGSR2 output.
// This intentionally does not claim motion compensation.

float V3DFrameGenLuma(float3 color)
{
  return dot(color, float3(0.2126, 0.7152, 0.0722));
}

void main()
{
  float2 uv = GetCoordinates();
  float3 previous = clamp(textureLod(samp0, float3(uv, GetLayer()), 0.0).xyz, 0.0, 1.0);
  float3 current = clamp(textureLod(samp1, float3(uv, GetLayer()), 0.0).xyz, 0.0, 1.0);
  float phase = clamp(v3d_frame_generation_phase, 0.0, 1.0);

  float luma_delta = abs(V3DFrameGenLuma(previous) - V3DFrameGenLuma(current));
  float color_delta = max(abs(previous.r - current.r),
                          max(abs(previous.g - current.g), abs(previous.b - current.b)));
  float reactive = smoothstep(0.10, 0.35, max(luma_delta, color_delta));

  // On discontinuities choose the nearest real endpoint. Stable regions receive interpolation.
  float blend_phase = mix(phase, step(0.5, phase), reactive);
  SetOutput(float4(mix(previous, current, blend_phase), 1.0));
}
