# OneClient Liquid Glass (`oc_liquid_glass`) — Complete Tutorial & API Guide

This guide turns the official docs into a practical, end-to-end reference you can drop into a codebase. It covers installation, mental model, core widgets, all parameters, patterns (single droplet, groups, animated), performance tips, and troubleshooting—**with direct citations to the API pages**.

---

## What is it?

**`oc_liquid_glass`** renders realistic “liquid glass” droplets—refraction, blur/frost, specular highlights, and a light band—using **GPU fragment shaders** (Impeller) for smooth performance. You place droplets as widgets; a parent “group” widget composes them into a single shader pass. ([Dart packages][1])

### Feature snapshot

* No external deps; pure Flutter widget API. Refraction + blur + specular highlights, configurable lighting, per-droplet color. Works in scrollables and modal route animations. Unlimited droplets (performance depends on count). ([Dart packages][1])
* **Limitations:** Requires **Impeller**; grouped shapes are limited to **4 per group** (shader uniform limits); Android emulator upside-down bug tracked upstream. ([Dart packages][1])

---

## Install

```yaml
dependencies:
  oc_liquid_glass: ^0.2.1
```

```bash
flutter pub get
```

> The README shows earlier version constraints; use the **latest** (0.2.1 at the time of writing) unless your project requires otherwise. ([Dart packages][1])

### Import

```dart
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
```

---

## Mental Model (How it Works)

* **`OCLiquidGlassGroup`** is a container that **loads the fragment shader** and **collects** child droplets anywhere under its `child` tree. It acts like a “glass layer.” You typically put it above your background content (e.g., in a `Stack`). ([Dart packages][2])
* **`OCLiquidGlass`** is a **single droplet**: a rounded rectangle rendered by the shader with refraction + lighting. It **must live inside** a group to render. Its geometry and style are passed through a lightweight **`ShapeData`** struct to the GPU. **Border radius is clamped** to half the smaller side. ([Dart packages][3])
* Under the hood, each droplet becomes a **`RenderLiquidGlass`** proxy box that registers with the group layer and contributes geometry + parameters to the shader. ([Dart packages][4])

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

class DemoGlass extends StatelessWidget {
  const DemoGlass({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background that will refract through droplets:
        Positioned.fill(
          child: Image.asset('assets/background.jpg', fit: BoxFit.cover),
        ),

        // Glass "layer" + one droplet:
        OCLiquidGlassGroup(
          settings: const OCLiquidGlassSettings(), // defaults
          child: Center(
            child: OCLiquidGlass(
              width: 160,
              height: 100,
              borderRadius: 40,                // <- double, clamped to min(w,h)/2
              color: Colors.cyan.withOpacity(.25),
              child: const SizedBox(),        // optional foreground content
            ),
          ),
        ),
      ],
    );
  }
}
```

* **Why a group?** It loads the shader and coordinates all droplets in its subtree. ([Dart packages][2])
* **Why numeric `borderRadius`?** The widget takes a **`double`**, *not* `BorderRadius`; it’s auto-clamped to avoid invalid geometry. ([Dart packages][3])

---

## Core Widgets & Classes

### 1) `OCLiquidGlassGroup`

Container that **manages multiple shapes** and applies the unified shader. Collects any `OCLiquidGlass` in its subtree. You can optionally inject a `repaint` `Listenable` to externally drive repaints (e.g., merged animations). **Constructor**:
`OCLiquidGlassGroup({ required OCLiquidGlassSettings settings, required Widget child, Listenable? repaint })` ([Dart packages][2])

**When to use it**

* Always wrap droplets with a group. Put it **above** background content (Stack) so refraction samples the right pixels.
* Use **one group per visual layer** you want to composite independently.

---

### 2) `OCLiquidGlass` (droplet)

A render‐object widget wrapping a single child into a rounded glass droplet. **Constructor**:
`OCLiquidGlass({ bool enabled = true, double? width, double? height, Color color = Colors.transparent, double borderRadius = 0.0, BoxShadow? shadow, Widget? child })` ([Dart packages][3])

**Key properties**

* `enabled: bool` — toggle the effect on/off. ([Dart packages][3])
* `width/height: double?` — size of the droplet box (use `SizedBox`, constraints, or `Positioned` if you prefer). ([Dart packages][3])
* `color: Color` — **tint** atop the glass (per droplet). Useful to differentiate droplets even within one group. ([Dart packages][3])
* `borderRadius: double` — uniform radius, **auto-clamped** to `min(width, height)/2`. ([Dart packages][3])
* `shadow: BoxShadow?` — optional drop shadow for the droplet. ([Dart packages][3])
* `child: Widget?` — foreground content rendered within the droplet bounds. ([Dart packages][3])

**Under the hood:** Each droplet maps to **`RenderLiquidGlass`**, which registers/unregisters with the layer and pushes geometry + style to the shader system. It’s a proxy box; it doesn’t alter layout. ([Dart packages][4])

---

### 3) `OCLiquidGlassSettings` (shader knobs)

Create once per group; tweak refraction, blur/frost, specular highlights, and light band. **Constructor**:
`OCLiquidGlassSettings({ blendPx=5, refractStrength=-0.06, distortFalloffPx=45, distortExponent=4, blurRadiusPx=0, specAngle=4, specStrength=20.0, specPower=100, specWidth=10, lightbandOffsetPx=10, lightbandWidthPx=30, lightbandStrength=0.9, lightbandColor=Colors.white })` with `copyWith(...)` available. ([Dart packages][5])

**Parameter cheatsheet**

| Setting             | Type   | What it does                                                                                                      |
| ------------------- | ------ | ----------------------------------------------------------------------------------------------------------------- |
| `blendPx`           | double | Edge-blend distance for softer droplet edges. ([Dart packages][1])                                                |
| `refractStrength`   | double | Strength of lens refraction; **negative** gives a concave lens look (pulling pixels inward). ([Dart packages][1]) |
| `distortFalloffPx`  | double | How far distortion extends from edges before fading out. ([Dart packages][1])                                     |
| `distortExponent`   | double | Curve/steepness of the distortion’s falloff. Higher = sharper edge effect. ([Dart packages][1])                   |
| `blurRadiusPx`      | double | Frosted-glass blur amount (0 = off). ([Dart packages][1])                                                         |
| `specAngle`         | double | Incoming light angle for specular highlights. ([Dart packages][5])                                                |
| `specStrength`      | double | Intensity (brightness) of specular highlights. ([Dart packages][5])                                               |
| `specPower`         | double | Sharpness of highlight (like Phong exponent). ([Dart packages][5])                                                |
| `specWidth`         | double | Pixel width of the highlight. ([Dart packages][5])                                                                |
| `lightbandOffsetPx` | double | Distance from the edge where the light band appears. ([Dart packages][5])                                         |
| `lightbandWidthPx`  | double | Width of the light band. ([Dart packages][5])                                                                     |
| `lightbandStrength` | double | Intensity of the light band. ([Dart packages][5])                                                                 |
| `lightbandColor`    | Color  | Color of the band (e.g., white for a clean highlight, cyan for stylized). ([Dart packages][5])                    |

> You can **`copyWith`** to derive variants for hover/press states or themes. ([Dart packages][5])

---

## Common Recipes

### A) Basic “glass card”

```dart
Stack(
  children: [
    Positioned.fill(child: YourBackground()),
    OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(blurRadiusPx: 1.5),
      child: Center(
        child: OCLiquidGlass(
          width: 260, height: 140, borderRadius: 28,
          color: Colors.white.withOpacity(.18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Liquid Glass', style: TextStyle(color: Colors.white)),
                SizedBox(height: 8),
                Text('Looks like iOS “droplet” UI'),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
);
```

Uses blur + tint; highlight defaults give a subtle sheen. ([Dart packages][1])

---

### B) Multiple droplets in one layer

```dart
OCLiquidGlassGroup(
  settings: const OCLiquidGlassSettings(
    refractStrength: -0.08,   // more lensing
    blurRadiusPx: 1.5,
    specStrength: 15,
    lightbandColor: Colors.white70,
  ),
  child: Stack(
    children: [
      Positioned(
        top: 100, left: 50,
        child: OCLiquidGlass(width: 200, height: 120, borderRadius: 60,
          color: Colors.amber.withOpacity(.30),
          child: const SizedBox()),
      ),
      Positioned(
        top: 250, left: 300,
        child: OCLiquidGlass(width: 150, height: 100, borderRadius: 50,
          color: Colors.blue.withOpacity(.20),
          child: const SizedBox()),
      ),
      Positioned(
        top: 180, left: 200,
        child: OCLiquidGlass(width: 80, height: 60, borderRadius: 30,
          color: Colors.pink.withOpacity(.25),
          child: const SizedBox()),
      ),
      Positioned(
        top: 320, left: 150,
        child: OCLiquidGlass(width: 60, height: 40, borderRadius: 20,
          color: Colors.green.withOpacity(.20),
          child: const SizedBox()),
      ),
    ],
  ),
);
```

Matches the multi-droplet pattern shown in docs. ([Dart packages][1])

---

### C) “Lensy” droplet (strong refraction + sharp specular)

```dart
OCLiquidGlassGroup(
  settings: const OCLiquidGlassSettings(
    refractStrength: -0.10,    // strong concave lensing
    distortFalloffPx: 32,      // tighter edge zone
    distortExponent: 5,        // sharper falloff
    specStrength: 28, specPower: 140, specWidth: 8,
    lightbandOffsetPx: 12, lightbandWidthPx: 24, lightbandStrength: .9,
    lightbandColor: Colors.white,
  ),
  child: Center(
    child: OCLiquidGlass(
      width: 180, height: 100, borderRadius: 40,
      color: Colors.white.withOpacity(.12),
    ),
  ),
);
```

All parameters sourced from settings constructor signatures. ([Dart packages][5])

---

### D) Programmatic themes via `copyWith`

```dart
const base = OCLiquidGlassSettings(
  refractStrength: -0.06,
  blurRadiusPx: 1.0,
  specStrength: 18,
  lightbandColor: Colors.white70,
);

final pressed = base.copyWith(
  specStrength: 26,
  blurRadiusPx: 1.8,
  lightbandColor: Colors.cyanAccent,
);
```

Create consistent variants for hover/press/active states. ([Dart packages][5])

---

## Performance & Platform Notes

* **Impeller required.** If your target platform/device doesn’t support Impeller (or has it disabled), effects won’t render properly. ([Dart packages][1])
* **Group limits:** Docs note a limit of **4 shapes per group** (shader uniform constraints). If you need many droplets, split into multiple groups or design with fewer, larger elements. ([Dart packages][1])
* **Layering:** Keep the group’s visual area tight (only where droplets appear) to reduce overdraw.
* **Animation:** If coordinating multiple animations that should repaint together, pass a shared `Listenable` to the group’s `repaint` to avoid redundant frames. ([Dart packages][2])
* **Geometry sanity:** Border radius is **auto-clamped** to avoid impossible curves; don’t fight it—design with realistic radii. ([Dart packages][6])

---

## Troubleshooting

**“Nothing renders”**

* Check you placed droplets **inside** an `OCLiquidGlassGroup`. The group is responsible for shader loading and collecting droplets. ([Dart packages][2])
* Verify Impeller is enabled/supported on the device. Limitation is explicit in docs. ([Dart packages][1])

**“Border radius type mismatch”**

* `borderRadius` is a **`double`**, not `BorderRadius`/`Radius`. Pass `borderRadius: 24` (number). It’ll be clamped to half the smaller side. ([Dart packages][3])

**“Too many droplets”**

* Use **≤ 4** per group; otherwise split into multiple groups or simplify. ([Dart packages][1])

**“I want per-droplet color”**

* Use `OCLiquidGlass.color`. Each droplet can have its own tint, even within the same group. ([Dart packages][3])

---

## Full API Surfaces (Deep Links)

* **Package overview & quick examples** — install, features, limits, quick snippets. ([Dart packages][1])
* **Library index** — classes list. ([Dart packages][7])
* **`OCLiquidGlass`** — constructor & properties (`enabled`, `width`, `height`, `color`, `borderRadius`, `shadow`, `child`). ([Dart packages][3])
* **`OCLiquidGlassGroup`** — constructor (`settings`, `child`, `repaint`) + usage note. ([Dart packages][2])
* **`OCLiquidGlassSettings`** — constructor defaults & `copyWith`. ([Dart packages][5])
* **`RenderLiquidGlass`** — render object behavior (registers with group, passes geometry, toggle `enabled`). ([Dart packages][4])
* **`ShapeData`** — low-level geometry data; border radius clamp rule. ([Dart packages][6])

---

## Design Context (Optional Reading)

If you’re targeting Apple’s **Liquid Glass** UI feel (iconography, materials), see Apple’s tech overviews and examples for UI material behavior and interaction cues (light bands, touch response). These aren’t required to use the Flutter package, but help you match platform aesthetics. ([Apple Developer][8])

---

## Copy-paste Templates

### Minimal scaffold

```dart
Stack(
  children: [
    Positioned.fill(child: YourBackground()),
    OCLiquidGlassGroup(
      settings: const OCLiquidGlassSettings(),
      child: const Center(
        child: OCLiquidGlass(
          width: 140, height: 88, borderRadius: 28,
          color: Colors.white24,
        ),
      ),
    ),
  ],
);
```

([Dart packages][1])

### Tuned droplet

```dart
OCLiquidGlassGroup(
  settings: const OCLiquidGlassSettings(
    refractStrength: -0.08,
    blurRadiusPx: 2.0,
    specStrength: 25.0,
    lightbandColor: Colors.cyan,
  ),
  child: Center(
    child: OCLiquidGlass(
      width: 120, height: 80, borderRadius: 40,
      color: Colors.cyanAccent.withOpacity(.20),
    ),
  ),
);
```

([Dart packages][1])

---

### Final Tips

* Start from defaults; tweak **refract/blur/spec** in small increments to avoid “plastic” looks.
* Use **per-droplet tint** (`color`) to separate layers visually.
* Keep **≤ 4 droplets per group**; split complex layouts into multiple groups for stability. ([Dart packages][1])

If you want, I can export this as a **downloadable README.md** or scaffold a demo screen in your app using these snippets.

[1]: https://pub.dev/documentation/oc_liquid_glass/latest/ "oc_liquid_glass - Dart API docs"
[2]: https://pub.dev/documentation/oc_liquid_glass/latest/oc_liquid_glass/OCLiquidGlassGroup-class.html "OCLiquidGlassGroup class - oc_liquid_glass library - Dart API"
[3]: https://pub.dev/documentation/oc_liquid_glass/latest/oc_liquid_glass/OCLiquidGlass-class.html "OCLiquidGlass class - oc_liquid_glass library - Dart API"
[4]: https://pub.dev/documentation/oc_liquid_glass/latest/oc_liquid_glass/RenderLiquidGlass-class.html "RenderLiquidGlass class - oc_liquid_glass library - Dart API"
[5]: https://pub.dev/documentation/oc_liquid_glass/latest/oc_liquid_glass/OCLiquidGlassSettings-class.html "OCLiquidGlassSettings class - oc_liquid_glass library - Dart API"
[6]: https://pub.dev/documentation/oc_liquid_glass/latest/oc_liquid_glass/ShapeData-class.html "ShapeData class - oc_liquid_glass library - Dart API"
[7]: https://pub.dev/documentation/oc_liquid_glass/latest/oc_liquid_glass/ "oc_liquid_glass library - Dart API"
[8]: https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass?utm_source=chatgpt.com "Liquid Glass | Apple Developer Documentation"
