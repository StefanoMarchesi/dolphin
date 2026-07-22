// SGSR1 edge-direction weighting variant for V3D.

const float V3D_EDGE_THRESHOLD = 8.0 / 255.0;
const float V3D_EDGE_SHARPNESS = 2.0;

float V3DFastLanczos2(float x)
{
  float w_a = x - 4.0;
  float w_b = x * w_a - w_a;
  w_a *= w_a;
  return w_b * w_a;
}

float2 V3DEdgeDirection(float4 left, float4 right)
{
  float rx_lz = right.x - left.z;
  float rw_ly = right.w - left.y;
  float2 delta = float2(rx_lz + rw_ly, rx_lz - rw_ly);
  return delta * inversesqrt(dot(delta, delta) + 3.075740e-05);
}

float2 V3DWeightY(float dx, float dy, float contrast, float3 data)
{
  float edge_distance = dx * data.z + dy * data.y;
  float x = dx * dx + dy * dy + edge_distance * edge_distance *
            (clamp(contrast * contrast * data.x, 0.0, 1.0) * 0.7 - 1.0);
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
    float sum_mean = 1.014185e+01 / max(sum, 1.0e-6);
    float3 data = float3(sum_mean * sum_mean, V3DEdgeDirection(left, right));

    float2 weights = V3DWeightY(phase.x, phase.y + 1.0, up_down.x, data);
    weights += V3DWeightY(phase.x - 1.0, phase.y + 1.0, up_down.y, data);
    weights += V3DWeightY(phase.x - 1.0, phase.y - 2.0, up_down.z, data);
    weights += V3DWeightY(phase.x, phase.y - 2.0, up_down.w, data);
    weights += V3DWeightY(phase.x + 1.0, phase.y - 1.0, left.x, data);
    weights += V3DWeightY(phase.x, phase.y - 1.0, left.y, data);
    weights += V3DWeightY(phase.x, phase.y, left.z, data);
    weights += V3DWeightY(phase.x + 1.0, phase.y, left.w, data);
    weights += V3DWeightY(phase.x - 1.0, phase.y - 1.0, right.x, data);
    weights += V3DWeightY(phase.x - 2.0, phase.y - 1.0, right.y, data);
    weights += V3DWeightY(phase.x - 2.0, phase.y, right.z, data);
    weights += V3DWeightY(phase.x - 1.0, phase.y, right.w, data);

    float final_y = weights.y / max(weights.x, 1.0e-6);
    float max_y = max(max(left.y, left.z), max(right.x, right.w));
    float min_y = min(min(left.y, left.z), min(right.x, right.w));
    float delta_y = clamp(V3D_EDGE_SHARPNESS * final_y, min_y, max_y) - color.w;
    delta_y = clamp(delta_y, -23.0 / 255.0, 23.0 / 255.0);
    color.xyz = clamp(color.xyz + float3(delta_y), 0.0, 1.0);
  }

  SetOutput(float4(color.xyz, 1.0));
}
