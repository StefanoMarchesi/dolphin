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
lightweight RCAS pass after mode 3. Mode 6 adds duplicate-VI color-history frame
generation to mode 4. Mode 0 is the unchanged direct path. An
explicitly selected user shader takes priority. Other backends and mode 0 retain
the existing output path; a missing or failed shader falls back through
Dolphin's normal post-processing fallback.

Mode 4 uses persistent RGBA16F ping-pong history, variance clipping, adaptive
history alpha, reactive rejection, and a compact thin-feature lock. It is
deliberately labelled `SGSR2 Color History, no motion`: Dolphin does not expose
game motion vectors to presentation, so this is not the complete Qualcomm
SGSR2 algorithm and does not perform motion-vector reprojection. It resets its
history on source/output resize, shader change, pipeline change, and a frame
gap longer than 250 ms. AMD Optical Flow, robust camera-cut detection, and full
SGSR2 motion/depth handling are not connected yet.

Mode 6 measures the preceding unique-XFB cadence and replaces duplicate VI
presents with interpolation phases. A 30 fps title on a 60 Hz VI receives a
midpoint; a 20 fps title receives one-third and two-thirds frames. The mode does
not add presents, alter emulation speed, or interpolate Immediate XFB presents.
Large per-pixel changes use reactive endpoint selection to reduce HUD and scene
cut blending. Because motion vectors are unavailable, it is explicitly a
color-history experiment and can show double images during fast camera motion.

The hotkey configuration contains a dedicated `V3D Experiment` group. Its
`Cycle V3D Upscaler Mode` action currently switches at runtime through Direct,
SGSR1 stock, SGSR1 edge-direction, SGSR1 contrast-relative, SGSR2 color-history,
SGSR1 contrast-relative plus light RCAS, and SGSR2 plus duplicate-VI frame
generation. The experimental modes use native 1x. All changes use Dolphin's
session layer and therefore do not modify the saved graphics configuration.

Before exposing the setting in the UI:

1. implement only the Vulkan backend first;
2. preserve the unmodified presentation fallback;
3. handle non-multiple-of-eight source and output sizes;
4. reset temporal history on savestate load, resize, game boot, and camera cut;
5. capture GPU p50/p95/p99 and replay quality metrics;
6. validate on V3DV, not only MoltenVK.

This scaffold is separate from the reproducible shader work in
`StefanoMarchesi/v3d-upscaler-lab`.
