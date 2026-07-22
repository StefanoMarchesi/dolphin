# V3D upscaler experiment

This branch provides an isolated, default-off runtime gate for experiments with
SGSR/NIS-style output upscaling on Broadcom V3D. It does not change rendering
when the flag is absent or false, and it does not install or replace Mesa.

The hidden flag is intentionally not exposed in Dolphin's graphics UI while no
backend implementation is connected. Test builds can opt in through `GFX.ini`:

```ini
[Enhancements]
V3DUpscalerExperiment = True
```

The active value is available as
`g_ActiveConfig.bV3DUpscalerExperiment`. On Vulkan, enabling it with no explicit
post-processing shader selects the bundled `V3D_SGSR1` presentation shader.
An explicitly selected user shader takes priority. Other backends and the
disabled setting retain the existing output path; a missing or failed shader
falls back through Dolphin's normal post-processing fallback.

This is a spatial SGSR1 integration only. AMD Optical Flow, mip-1 scene-change
detection, SGSR2 temporal history, and frame generation are not connected to
Dolphin yet.

Before exposing the setting in the UI:

1. implement only the Vulkan backend first;
2. preserve the unmodified presentation fallback;
3. handle non-multiple-of-eight source and output sizes;
4. reset temporal history on savestate load, resize, game boot, and camera cut;
5. capture GPU p50/p95/p99 and replay quality metrics;
6. validate on V3DV, not only MoltenVK.

This scaffold is separate from the reproducible shader work in
`StefanoMarchesi/v3d-upscaler-lab`.
