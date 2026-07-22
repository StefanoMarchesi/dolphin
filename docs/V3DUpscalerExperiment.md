# V3D upscaler experiment

This branch provides an isolated, default-off runtime gate for experiments with
SGSR/NIS-style output upscaling on Broadcom V3D. It does not change rendering
when the flag is absent or false, and it does not install or replace Mesa.

The hidden flag is intentionally not exposed in Dolphin's graphics UI while no
backend implementation is connected. Test builds can opt in through `GFX.ini`:

```ini
[Enhancements]
V3DUpscalerMode = 1
```

The active value is available as `g_ActiveConfig.iV3DUpscalerMode`. On Vulkan,
mode 1 selects bundled SGSR1 stock, mode 2 selects its edge-direction weighting
variant, mode 3 selects multi-channel contrast-relative edge detection, mode 4
selects the SGSR2-inspired color-history experiment, and mode 5 adds a separate
lightweight RCAS pass after mode 3. Mode 0 is the unchanged direct path. An
explicitly selected user shader takes priority. Other backends and mode 0 retain
the existing output path; a missing or failed shader falls back through
Dolphin's normal post-processing fallback.

Mode 4 uses persistent RGBA16F ping-pong history, variance clipping, adaptive
history alpha, reactive rejection, and a compact thin-feature lock. It is
deliberately labelled `SGSR2 Color History, no motion`: Dolphin does not expose
game motion vectors to presentation, so this is not the complete Qualcomm
SGSR2 algorithm and does not perform motion-vector reprojection. It resets its
history on source/output resize, shader change, pipeline change, and a frame
gap longer than 250 ms. AMD Optical Flow, robust camera-cut detection, full
SGSR2 motion/depth handling, and frame generation are not connected yet.

The hotkey configuration contains a dedicated `V3D Experiment` group. Its
`Cycle V3D Upscaler Mode` action currently switches at runtime through Direct,
SGSR1 stock, SGSR1 edge-direction, SGSR1 contrast-relative, SGSR2 color-history,
and SGSR1 contrast-relative plus light RCAS. The experimental modes use native
1x. All changes use Dolphin's session layer and therefore do not modify the
saved graphics configuration.

Before exposing the setting in the UI:

1. implement only the Vulkan backend first;
2. preserve the unmodified presentation fallback;
3. handle non-multiple-of-eight source and output sizes;
4. reset temporal history on savestate load, resize, game boot, and camera cut;
5. capture GPU p50/p95/p99 and replay quality metrics;
6. validate on V3DV, not only MoltenVK.

This scaffold is separate from the reproducible shader work in
`StefanoMarchesi/v3d-upscaler-lab`.
