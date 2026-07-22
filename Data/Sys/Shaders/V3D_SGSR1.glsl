// Snapdragon Game Super Resolution 1 presentation experiment for V3D.
// The algorithm and constants follow Qualcomm's BSD-3-Clause SGSR1 shader.

const float V3D_EDGE_THRESHOLD = 8.0 / 255.0;
const float V3D_EDGE_SHARPNESS = 2.0;

float V3DFastLanczos2(float x)
{
  float w_a = x - 4.0;
  float w_b = x * w_a - w_a;
  w_a *= w_a;
  return w_b * w_a;
}

float2 V3DWeightY(float dx, float dy, float contrast, float stddev)
{
  float x = (dx * dx + dy * dy) * 0.55 + clamp(abs(contrast) * stddev, 0.0, 1.0);
  float weight = V3DFastLanczos2(x);
  return float2(weight, weight * contrast);
}

void main()
{
  float2 source_size = GetResolution() * src_rect.zw;
  float2 target_size = GetTargetResolution();
  if (target_size.x <= source_size.x || target_size.y <= source_size.y)
  {
    SetOutput(Sample());
    return;
  }

  float2 uv = GetCoordinates();
  float2 local_uv = (uv - src_rect.xy) / src_rect.zw;
  float4 color = float4(Sample().xyz, 1.0);
  float2 image_coord = local_uv * source_size + float2(-0.5, 0.5);
  float2 image_pixel = floor(image_coord);
  float2 coord = src_rect.xy + image_pixel * GetInvResolution();
  float2 phase = image_coord - image_pixel;

  const int channel = 1;
  float4 left = textureGather(samp0, float3(coord, GetLayer()), channel);
  float edge_vote = abs(left.z - left.y) + abs(color[channel] - left.y) +
                    abs(color[channel] - left.z);

  if (edge_vote > V3D_EDGE_THRESHOLD)
  {
    coord.x += GetInvResolution().x;
    float4 right = textureGather(
        samp0, float3(coord + float2(GetInvResolution().x, 0.0), GetLayer()), channel);
    float4 up_down;
    up_down.xy = textureGather(
        samp0, float3(coord + float2(0.0, -GetInvResolution().y), GetLayer()), channel).wz;
    up_down.zw = textureGather(
        samp0, float3(coord + float2(0.0, GetInvResolution().y), GetLayer()), channel).yx;

    float mean = (left.y + left.z + right.x + right.w) * 0.25;
    left -= float4(mean);
    right -= float4(mean);
    up_down -= float4(mean);
    color.w = color[channel] - mean;
    float sum = dot(abs(left), float4(1.0)) + dot(abs(right), float4(1.0)) +
                dot(abs(up_down), float4(1.0));
    float stddev = 2.181818 / max(sum, 1.0e-6);

    float2 weights = V3DWeightY(phase.x, phase.y + 1.0, up_down.x, stddev);
    weights += V3DWeightY(phase.x - 1.0, phase.y + 1.0, up_down.y, stddev);
    weights += V3DWeightY(phase.x - 1.0, phase.y - 2.0, up_down.z, stddev);
    weights += V3DWeightY(phase.x, phase.y - 2.0, up_down.w, stddev);
    weights += V3DWeightY(phase.x + 1.0, phase.y - 1.0, left.x, stddev);
    weights += V3DWeightY(phase.x, phase.y - 1.0, left.y, stddev);
    weights += V3DWeightY(phase.x, phase.y, left.z, stddev);
    weights += V3DWeightY(phase.x + 1.0, phase.y, left.w, stddev);
    weights += V3DWeightY(phase.x - 1.0, phase.y - 1.0, right.x, stddev);
    weights += V3DWeightY(phase.x - 2.0, phase.y - 1.0, right.y, stddev);
    weights += V3DWeightY(phase.x - 2.0, phase.y, right.z, stddev);
    weights += V3DWeightY(phase.x - 1.0, phase.y, right.w, stddev);

    float final_y = weights.y / max(weights.x, 1.0e-6);
    float max_y = max(max(left.y, left.z), max(right.x, right.w));
    float min_y = min(min(left.y, left.z), min(right.x, right.w));
    float delta_y = clamp(V3D_EDGE_SHARPNESS * final_y, min_y, max_y) - color.w;
    delta_y = clamp(delta_y, -23.0 / 255.0, 23.0 / 255.0);
    color.xyz = clamp(color.xyz + float3(delta_y), 0.0, 1.0);
  }

  SetOutput(float4(color.xyz, 1.0));
}
