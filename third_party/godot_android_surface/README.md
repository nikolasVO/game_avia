# Android surface lifecycle recovery (experimental)

Pinned Godot4.7.2 native engine remains unchanged. This directory changes the Android Java `GLSurfaceView` from exact engine commit `ed1daf0bf001b61586d9930840f2f1394092c079`. The original file SHA256 is `15d56bda1cf68e72bb3b48f8e2b0cd6a57dfab9832a674a6f2b4ce82b2f44dbb`.

An in-flight draw can outlive a SurfaceHolder destroy/create pair. The GL thread may miss the temporary `mHasSurface=false`; a subsequent stale EGL failure sets `mSurfaceIsBad` after the new surface exists. The stock loop then waits without rendering. This is an inference from exact source, reproduced emulator behavior and a native stack waiting in `guardedRun`; it does not establish every black-screen cause.

The patch counts holder callbacks under the existing monitor and records the generation used to create the EGL surface. A failure for an older generation releases that EGL surface and requests a render on the current holder. A failure of the current generation retains stock bad-surface handling. It adds no UI-thread wait and changes neither native binaries nor gameplay authority. Existing EGL context-loss handling remains in place. Recovery writes `GAME_AVIA_SURFACE_RECOVERY old->new` diagnostics.

`GLSurfaceView.java` is the modified source; `surface-generation.patch` records the exact delta. Retain `NOTICE`, `LICENSE-2.0.txt` (AOSP Apache2.0) and `GODOT-LICENSE.txt` (Godot MIT) with distribution. The app's normal Godot attribution still applies.

Build from the exact official debug AAR with JDK17 and installed Android35 `android.jar`:

```sh
python3 third_party/godot_android_surface/build_library.py \
  --aar /path/to/official/godot-lib.template_debug.aar \
  --jdk /path/to/jdk17 --android-jar /path/to/android-sdk/platforms/android-35/android.jar \
  --out /path/to/owned-output/surface-debug.aar
```

The builder pins source/AAR hashes, replaces only15 GL Java classes, verifies every other AAR entry unchanged, and records all8 native hashes. It never overwrites its input or installed templates. Output ZIP metadata is preserved for repeatability with the same compiler. The added source notice produces byte-identical classes to the runtime-tested patch.

`tools/build_android_surface.py` copies the actual materialized game into a fresh owned output directory, uses the official source template with this Java library, limits Gradle to2workers/2GiB, and exports a compact debug APK. It records actual source hashes, dirty status, Java customization and native equivalence. This is an explicit experimental build route; ordinary `tools/build_game.py` still builds stock templates. Do not describe a Java-customized APK as entirely stock or equate export success with runtime/phone acceptance.

See `docs/evidence/android-surface-isolation.json` for actual scenario scopes. Physical devices, long sessions and all Android drivers remain unverified.

Isolated game build example (all paths explicit; fresh output directory required):

```sh
python3 tools/build_android_surface.py --godot /path/to/Godot \
  --jdk /path/to/jdk17 --sdk /path/to/android-sdk \
  --templates '/path/to/export_templates/4.7.2.stable' \
  --out /path/to/new-owned-build
```

Reproduce diagnostic after installing its APK yourself:

```sh
python3 tools/android_surface_probe.py --adb /path/to/adb \
  --serial emulator-5554 --package com.nikolasvo.gameavia.surfacepatched \
  --out /path/to/new-diagnostic-evidence --cold --cycles 20
```

The probe filters its own PID and does not clear global logs, root the device, stop other applications or install packages. It keeps a failing fixture alive for investigation and exits nonzero on a recorded failure. Review its screenshot and `actual_cold` field; a warmed first frame does not prove the cold race.

The builder now also accepts `--variant release` for the exact official release AAR (`8791eecfe7c96a4de2d188a0bccfe9b83b92589a5a6825847473416a990e8629`). Actual JDK17 compilation preserved all8 release native libraries and replaced the same15 Java classes. `tools/build_android_surface.py --target aab` prepares an unsigned AAB using that variant; APK remains the default target. Export/runtime evidence must be recorded separately. It never creates a release signing key.
