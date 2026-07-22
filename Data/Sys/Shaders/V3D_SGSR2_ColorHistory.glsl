// SGSR2-inspired temporal color-history fallback for Dolphin/V3D.
// This is a real ping-pong history path, but it deliberately does not claim
// motion-vector reprojection: Dolphin does not expose game motion at present.

float V3DSGSR2Luma(float3 color)
{
  return dot(color, float3(0.2126, 0.7152, 0.0722));
}

void main()
{
  float2 source_size = GetResolution() * src_rect.zw;
  float2 target_size = GetTargetResolution();
  float2 uv = GetCoordinates();
  float2 local_uv = clamp((uv - src_rect.xy) / src_rect.zw, float2(0.0), float2(1.0));

  if (target_size.x <= source_size.x || target_size.y <= source_size.y)
  {
    SetOutput(Sample());
    return;
  }

  // Use Dolphin's stable bilinear reconstruction while validating the temporal path. The
  // experimental nine-tap kernel previously used here produced sparse outliers on V3DV.
  float3 current = clamp(Sample().xyz, 0.0, 1.0);
  float2 source_texel = GetInvResolution();
  float2 minimum_uv = src_rect.xy + source_texel * 0.5;
  float2 maximum_uv = src_rect.xy + src_rect.zw - source_texel * 0.5;
  float3 box_min = float3(1.0e10);
  float3 box_max = float3(-1.0e10);
  float3 box_sum = float3(0.0);
  float3 box_squared_sum = float3(0.0);

  for (int y = -1; y <= 1; ++y)
  {
    for (int x = -1; x <= 1; ++x)
    {
      float2 sample_uv = clamp(uv + float2(x, y) * source_texel, minimum_uv, maximum_uv);
      float3 sample_color =
          clamp(textureLod(samp0, float3(sample_uv, GetLayer()), 0.0).xyz, 0.0, 1.0);
      box_min = min(box_min, sample_color);
      box_max = max(box_max, sample_color);
      box_sum += sample_color;
      box_squared_sum += sample_color * sample_color;
    }
  }

  float3 box_mean = box_sum / 9.0;
  float3 box_variance = max(box_squared_sum / 9.0 - box_mean * box_mean, float3(0.0));
  float3 box_sigma = sqrt(box_variance);

  // Never sample newly allocated history. Undefined texels can contain NaNs, and a subsequent
  // mix with zero history weight is not guaranteed to remove them on every Vulkan driver.
  if (intermediary_buffer == 0)
  {
    SetOutput(float4(clamp(current, 0.0, 1.0), 1.0));
    return;
  }

  float3 history = textureLod(samp1, float3(local_uv, 0.0), 0.0).xyz;
  // Comparisons against NaN are false, so this also rejects non-finite history without relying
  // on backend-specific isnan/isinf lowering. A valid SDR history is always in [0, 1].
  if (!all(greaterThanEqual(history, float3(0.0))) ||
      !all(lessThanEqual(history, float3(1.0))))
  {
    history = current;
  }
  float3 variance_min = max(box_min, box_mean - box_sigma * 1.25);
  float3 variance_max = min(box_max, box_mean + box_sigma * 1.25);
  float3 clipped_history = clamp(history, variance_min, variance_max);

  float luma_delta = abs(V3DSGSR2Luma(history) - V3DSGSR2Luma(current));
  float color_delta = max(abs(history.r - current.r),
                          max(abs(history.g - current.g), abs(history.b - current.b)));
  float reactive = smoothstep(0.025, 0.18, max(luma_delta, color_delta));

  // Compact thin-feature lock: stable high-contrast boxes retain slightly more history.
  float box_range = V3DSGSR2Luma(box_max) - V3DSGSR2Luma(box_min);
  float thin_lock = (1.0 - reactive) * smoothstep(0.08, 0.30, box_range);
  float history_alpha = mix(0.82, 0.91, thin_lock) * (1.0 - reactive);
  float3 output_color = mix(current, clipped_history, history_alpha);
  SetOutput(float4(clamp(output_color, 0.0, 1.0), 1.0));
}
