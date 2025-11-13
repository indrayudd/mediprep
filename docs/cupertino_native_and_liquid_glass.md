# Flutter “Liquid Glass” Native UI — Field Guide

This guide covers **both** packages you mentioned—**`cupertino_native`** (native iOS/macOS widgets with the liquid-glass look) and **`liquid_glass_renderer`** (shader-based “liquid glass” effect for any Flutter widget). It’s written so you can implement everything without opening the docs.

---

## Part 1 — `cupertino_native`

### What it is

A Flutter plugin that embeds **real UIKit/AppKit controls** via Platform Views, giving you **pixel-perfect** iOS/macOS widgets that already match Apple’s Liquid Glass aesthetic. Falls back to Flutter equivalents on non-Apple platforms. Minimums: iOS 14+, macOS 11+; the README notes Xcode 26 beta requirement and `xcode-select` switch for current builds. ([Dart packages][1])

### Install

```bash
flutter pub add cupertino_native
```

If you’re targeting iOS/macOS, ensure:

* iOS: `platform :ios, '14.0'` in your Podfile
* macOS: 11.0+
* (As of the package README) use Xcode 26 beta: `sudo xcode-select -s /Applications/Xcode-beta.app` ([Dart packages][2])

### Import

```dart
import 'package:cupertino_native/cupertino_native.dart';
```

### Widgets & APIs (all shipped today)

The package exposes these components (with native behavior on Apple platforms):

* **CNSlider** — Cupertino-native slider
* **CNSwitch** — native toggle
* **CNSegmentedControl** — segmented selector
* **CNButton / CNButton.icon** — push button (text or circular icon)
* **CNIcon (with CNSymbol)** — SF Symbols with rendering modes
* **CNPopupMenuButton** — native popup/context menu
* **CNTabBar** — iOS-style bottom bar (overlay) ([Dart packages][2])

Below are usage patterns and relevant options. (Where detailed symbol/style enums exist, they’re documented from the API reference.)

---

### CNButton (and CNButton.icon)

**Purpose:** Native UIButton/NSButton embedded in Flutter. On non-Apple platforms, it falls back to `CupertinoButton`. ([Dart packages][3])

**Constructors & key params**

```dart
CNButton(
  label: 'Press me',
  onPressed: () {},
  enabled: true,
  tint: const Color(0xFF007AFF), // accent
  height: 32.0,
  shrinkWrap: false,
  style: CNButtonStyle.plain,     // see styles below
);

CNButton.icon(
  icon: const CNSymbol('heart.fill'),
  onPressed: () {},
  enabled: true,
  tint: const Color(0xFF007AFF),
  size: 44.0,
  style: CNButtonStyle.glass,
);
```

* `style` uses the `CNButtonStyle` enum described below.
* `shrinkWrap` sizes to intrinsic width (helpful for text-length dependent buttons). ([Dart packages][3])

#### CNButtonStyle (visual styles)

Values include: `plain`, `gray`, `tinted`, `bordered`, `borderedProminent`, `filled`, `glass`, `prominentGlass`. Use them to match Apple’s look (especially `glass` styles for liquid-glass UI). ([Dart packages][4])

---

### CNSymbol & CNIcon (SF Symbols)

Use **`CNSymbol`** to describe an SF Symbol, then render it with **`CNIcon`**.

```dart
const CNIcon(
  symbol: CNSymbol(
    'paintpalette.fill',
    size: 24.0,
    color: Color(0xFF111111),
    paletteColors: [Color(0xFFB00020), Color(0xFFFFC107)],
    mode: CNSymbolRenderingMode.multicolor, // or monochrome/hierarchical/palette
    gradient: true,
  ),
);
```

* `CNSymbol(name, {size, color, paletteColors, mode, gradient})`
* `CNSymbolRenderingMode` values: `monochrome`, `hierarchical`, `palette`, `multicolor`. ([Dart packages][5])

---

### CNSlider

```dart
double _value = 50;
CNSlider(
  value: _value,
  min: 0,
  max: 100,
  onChanged: (v) => setState(() => _value = v),
);
```

Native slider visuals with Flutter-simple API. ([Dart packages][2])

---

### CNSwitch

```dart
bool _on = true;
CNSwitch(
  value: _on,
  onChanged: (v) => setState(() => _on = v),
);
```

Native switch with platform look & haptics. ([Dart packages][2])

---

### CNSegmentedControl

```dart
int _index = 0;
CNSegmentedControl(
  labels: const ['One', 'Two', 'Three'],
  selectedIndex: _index,
  onValueChanged: (i) => setState(() => _index = i),
);
```

Native segmented control with simple integer selection. ([Dart packages][2])

---

### CNPopupMenuButton

```dart
final items = [
  const CNPopupMenuItem(label: 'New File',   icon: CNSymbol('doc', size: 18)),
  const CNPopupMenuItem(label: 'New Folder', icon: CNSymbol('folder', size: 18)),
  const CNPopupMenuDivider(),
  const CNPopupMenuItem(label: 'Rename', icon: CNSymbol('rectangle.and.pencil.and.ellipsis', size: 18)),
];

CNPopupMenuButton(
  buttonLabel: 'Actions',
  items: items,
  onSelected: (index) {
    // Handle selection by item index
  },
);
```

Native popup/context menu presentation and selection callbacks. ([Dart packages][2])

---

### CNTabBar (bottom overlay)

```dart
int _tabIndex = 0;

Stack(
  children: [
    // page content...
    Align(
      alignment: Alignment.bottomCenter,
      child: CNTabBar(
        items: const [
          CNTabBarItem(label: 'Home',     icon: CNSymbol('house.fill')),
          CNTabBarItem(label: 'Profile',  icon: CNSymbol('person.crop.circle')),
          CNTabBarItem(label: 'Settings', icon: CNSymbol('gearshape.fill')),
        ],
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    ),
  ],
);
```

Tab selection by index; renders a native-matching bottom bar UI. ([Dart packages][2])

---

### Notes & caveats

* The package positions itself as a **proof-of-concept** (components do work, but APIs may evolve; macOS liquid-glass visuals are noted as “untested” in README). ([Dart packages][2])
* `cupertino_native` provides library pages for buttons, icon/symbols, popup menu, segmented control, slider, switch, and tab bar; you can inspect those for deeper param lists as they evolve. ([Dart packages][2])

---

## Part 2 — `liquid_glass_renderer`

### What it is

A **shader-based** “liquid glass” renderer for Flutter that refracts the pixels **behind** your widget. Supports layers, blending multiple shapes, glow, and an interactive stretch effect. **Experimental**; recommended only with **Impeller** (Skia unsupported for now). It enumerates performance limits and best practices (e.g., keep shapes per layer limited). ([Dart packages][6])

### Install & import

```bash
flutter pub add liquid_glass_renderer
```

```dart
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
// For experimental Glassify widget:
import 'package:liquid_glass_renderer/experimental.dart';
```

Basic usage requires placing your glass inside a **Stack** above the content it should refract. ([Dart packages][6])

---

### Core building blocks

#### 1) `LiquidGlassLayer`

A **required ancestor** that hosts one or more glass shapes and provides shared `LiquidGlassSettings`. Keep the layer’s area tight for performance; Impeller limits **≈16 shapes per layer** (uniform buffer limit). ([Dart packages][7])

```dart
LiquidGlassLayer(
  settings: const LiquidGlassSettings(
    thickness: 20,
    blur: 10,
    glassColor: Color(0x33FFFFFF),
  ),
  child: Column(
    children: [
      LiquidGlass.inLayer(
        shape: LiquidRoundedSuperellipse(borderRadius: 50),
        child: const SizedBox.square(dimension: 120),
      ),
      const SizedBox(height: 24),
      LiquidGlass.inLayer(
        shape: LiquidRoundedRectangle(borderRadius: const Radius.circular(24)),
        child: const SizedBox.square(dimension: 120),
      ),
    ],
  ),
);
```

Key API:

* `LiquidGlassLayer({required Widget child, LiquidGlassSettings settings = const ...})` ([Dart packages][7])

---

#### 2) `LiquidGlass`

A **single glass shape** that refracts background pixels. Use:

* `LiquidGlass(...)` to **auto-create its own layer**, or
* `LiquidGlass.inLayer(...)` when you already have a shared `LiquidGlassLayer`. ([Dart packages][8])

```dart
// Standalone (own layer)
LiquidGlass(
  shape: LiquidRoundedSuperellipse(borderRadius: 30),
  settings: const LiquidGlassSettings(thickness: 15, blur: 8),
  glassContainsChild: false, // draw child above glass (default)
  child: const SizedBox.square(dimension: 100),
);

// Inside a shared layer
LiquidGlass.inLayer(
  shape: LiquidOval(),
  glassContainsChild: true, // child gets tinted/refracted
  child: const Icon(Icons.ac_unit, size: 40),
);
```

Important props:

* `shape: LiquidShape` (see shapes below)
* `settings: LiquidGlassSettings` (standalone only; in shared layer, settings come from layer)
* `glassContainsChild: bool` (child rendered “inside” the glass or on top)
* `fake: bool` (use lightweight “fake glass” pipeline)
* `clipBehavior: Clip.hardEdge` default ([Dart packages][8])

> The library also exposes a constant like `maxShapesPerLayer` (used internally to cap shapes); practical guidance in docs recommends keeping blended shapes modest. ([Dart packages][8])

---

#### 3) `LiquidGlassSettings` (all knobs in one place)

```dart
const LiquidGlassSettings({
  this.visibility = 1.0,
  this.glassColor = const Color.fromARGB(0, 255, 255, 255),
  this.thickness = 20,
  this.blur = 5,
  this.chromaticAberration = .01, // WIP
  this.lightAngle = 0.5 * pi,
  this.lightIntensity = .5,
  this.ambientStrength = 0,
  this.refractiveIndex = 1.2,
  this.saturation = 1.5,
});

// Figma-like constructor
const LiquidGlassSettings.figma({
  required double refraction,
  required double depth,
  required double dispersion,
  required double frost,
  double visibility = 1.0,
  double lightIntensity = 50,
  double lightAngle = 0.5 * pi,
  Color glassColor = const Color.fromARGB(0, 255, 255, 255),
});
```

Includes `copyWith(...)` plus `...effective*` getters that factor in `visibility`. Use `LiquidGlassSettings.of(context)` to read the nearest layer’s settings. ([Dart packages][9])

**Tuning tips (from package guidance):**

* Minimize the pixel area of each `LiquidGlassLayer` and `LiquidGlassBlendGroup`
* Limit number of shapes in one blend group
* Limit animations/moves; static shapes are cheap, moving shapes re-render every frame ([Dart packages][6])

---

### Shapes (`LiquidShape` hierarchy)

Use one of the provided shapes:

```dart
LiquidRoundedSuperellipse(borderRadius: 30) // “squircle”, recommended
LiquidOval()                                 // ellipse/circle
LiquidRoundedRectangle(borderRadius: const Radius.circular(24))
```

* `LiquidOval` ~ `OvalBorder` behavior. ([Dart packages][10])
* `LiquidRoundedRectangle` ~ `RoundedRectangleBorder` behavior. ([Dart packages][11])
* `LiquidRoundedSuperellipse` is the nice “squircle” for iOS-like glass. ([Dart packages][12])

---

### Blending multiple shapes

Place multiple shapes **inside one layer** to blend. (Some versions mention a blend group widget; the up-to-date API reference focuses on using a shared `LiquidGlassLayer` with multiple `LiquidGlass.inLayer` shapes. Keep counts reasonable for performance.) ([Dart packages][7])

---

### Fake glass (fast fallback): `FakeGlass`

A cheaper look-alike that avoids the heavy shader. You can use it standalone or inside a layer to inherit settings. ([Dart packages][13])

```dart
FakeGlass(
  shape: LiquidRoundedSuperellipse(borderRadius: 20),
  settings: const LiquidGlassSettings(blur: 10, glassColor: Color(0x33FFFFFF)),
  child: const SizedBox.square(dimension: 100),
);

// Or inherit settings from nearest LiquidGlassLayer:
FakeGlass.inLayer(
  shape: LiquidOval(),
  child: const SizedBox.square(dimension: 80),
);
```

---

### Touch glow: `GlassGlow` + `GlassGlowLayer`

Adds a responsive glow under your widget; the **layer** collects touch points, the **child** sends events to it (like `InkWell` with `Material`). ([Dart packages][14])

```dart
GlassGlowLayer(
  child: GlassGlow(
    glowColor: Colors.white24,
    glowRadius: 1.0,
    child: const SizedBox.square(dimension: 120),
  ),
);
```

---

### Organic motion: `LiquidStretch` / `RawLiquidStretch`

* **`LiquidStretch`** — plug-and-play “squash & stretch” on drag, with resistance and interaction scale.

  ```dart
  LiquidStretch(
    stretch: 0.5,            // px-per-drag multiplier
    resistance: 0.08,        // drag resistance
    interactionScale: 1.05,  // zoom while interacting
    child: YourGlassThing(),
  );
  ```

  Will listen to drag gestures without blocking other recognizers. ([Dart packages][15])

* **`RawLiquidStretch`** — bring your **own** `Offset stretchPixels` to control deformation precisely (e.g., physics, custom gestures). Prefer `LiquidStretch` for convenience. ([Dart packages][16])

---

### Full minimal example (stacked over content)

```dart
Stack(
  children: [
    Positioned.fill(
      child: Image.network('https://picsum.photos/seed/glass/1200/800', fit: BoxFit.cover),
    ),
    Center(
      child: LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 20,
          blur: 10,
          glassColor: Color(0x33FFFFFF),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlass.inLayer(
              shape: LiquidRoundedSuperellipse(borderRadius: 50),
              child: const SizedBox.square(dimension: 140),
            ),
            const SizedBox(height: 24),
            GlassGlow(
              glowColor: Colors.white24,
              glowRadius: 1.0,
              child: LiquidStretch(
                stretch: 0.4,
                interactionScale: 1.03,
                child: LiquidGlass.inLayer(
                  shape: LiquidRoundedRectangle(borderRadius: Radius.circular(24)),
                  child: const SizedBox.square(dimension: 120),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
```

This follows the package’s recommended layout: **background content** → **LiquidGlassLayer** → **glass widgets**; keeping the glass tree contiguous and minimizing animated re-renders. ([Dart packages][6])

---

### Platform & performance guidance (critical)

* **Impeller only** (for now). Web, Windows, Linux are listed as unsupported; performance depends heavily on device/GPU. Use **FakeGlass** where fidelity is less critical. Limit **animations** and **shapes per layer**; minimize layer area. Monitor memory due to texture caching and a referenced Flutter bug (temporary spikes while animating). ([Dart packages][6])

---

## When to use which?

* Want **native iOS controls** that already look “liquid glass”?
  → Use **`cupertino_native`** widgets (buttons, sliders, etc.) and symbols. ([Dart packages][2])

* Want **any Flutter widget** (your own shapes or content) to **physically refract** what’s behind it, blend together, glow, or stretch?
  → Wrap with **`liquid_glass_renderer`** (`LiquidGlassLayer` + shapes + optional `GlassGlow` / `LiquidStretch`). ([Dart packages][12])

---

## Quick reference (copy-paste)

### `cupertino_native`

```dart
// Button styles
CNButton(label: 'OK', onPressed: () {}, style: CNButtonStyle.glass);
CNButton.icon(icon: CNSymbol('heart.fill'), onPressed: () {}, style: CNButtonStyle.filled);

// Slider
CNSlider(value: v, min: 0, max: 100, onChanged: (nv) => setState(()=>v=nv));

// Switch
CNSwitch(value: on, onChanged: (b) => setState(()=>on=b));

// Segmented control
CNSegmentedControl(labels: const ['One','Two'], selectedIndex: idx, onValueChanged: (i){});

// Icon/SF Symbol
const CNIcon(symbol: CNSymbol('star', mode: CNSymbolRenderingMode.hierarchical));

// Popup menu
CNPopupMenuButton(buttonLabel: 'Actions', items: const [
  CNPopupMenuItem(label: 'New File', icon: CNSymbol('doc', size: 18)),
  CNPopupMenuDivider(),
  CNPopupMenuItem(label: 'Rename', icon: CNSymbol('rectangle.and.pencil.and.ellipsis', size: 18)),
], onSelected: (i) {});
// Tab bar
CNTabBar(items: const [
  CNTabBarItem(label:'Home', icon: CNSymbol('house.fill')),
  CNTabBarItem(label:'Settings', icon: CNSymbol('gearshape.fill')),
], currentIndex: tab, onTap: (i)=>setState(()=>tab=i));
```

([Dart packages][2])

### `liquid_glass_renderer`

```dart
// One shape with its own layer
LiquidGlass(
  shape: LiquidRoundedSuperellipse(borderRadius: 30),
  settings: const LiquidGlassSettings(thickness: 15, blur: 8),
  child: const SizedBox.square(dimension: 100),
);

// Multiple shapes blending in the same layer + glow + stretch
LiquidGlassLayer(
  settings: const LiquidGlassSettings(thickness: 20, blur: 10),
  child: GlassGlow(
    glowColor: Colors.white24,
    glowRadius: 1.0,
    child: LiquidStretch(
      stretch: 0.5, interactionScale: 1.05,
      child: Column(children: [
        LiquidGlass.inLayer(shape: LiquidRoundedSuperellipse(borderRadius: 50), child: const SizedBox.square(dimension: 120)),
        const SizedBox(height: 24),
        LiquidGlass.inLayer(shape: LiquidRoundedRectangle(borderRadius: Radius.circular(24)), child: const SizedBox.square(dimension: 120)),
      ]),
    ),
  ),
);
```

([Dart packages][8])

---

## Source notes

* `cupertino_native` README + API indexes (components, styles, symbols) were used for the exact constructors and enum values. ([Dart packages][2])
* `liquid_glass_renderer` package landing and API pages provide **all** class/constructor/property semantics referenced above, plus the **performance/limitations** guidance. ([Dart packages][6])


[1]: https://pub.dev/packages/cupertino_native "cupertino_native | Flutter package"
[2]: https://pub.dev/documentation/cupertino_native/latest/ "cupertino_native - Dart API docs"
[3]: https://pub.dev/documentation/cupertino_native/latest/components_button/CNButton-class.html "CNButton class - button library - Dart API"
[4]: https://pub.dev/documentation/cupertino_native/latest/style_button_style/CNButtonStyle.html "CNButtonStyle enum - button_style library - Dart API"
[5]: https://pub.dev/documentation/cupertino_native/latest/style_sf_symbol/CNSymbol-class.html "CNSymbol class - sf_symbol library - Dart API"
[6]: https://pub.dev/documentation/liquid_glass_renderer/latest/ "liquid_glass_renderer - Dart API docs"
[7]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/LiquidGlassLayer-class.html "LiquidGlassLayer class - liquid_glass_renderer library - Dart API"
[8]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/LiquidGlass-class.html "LiquidGlass class - liquid_glass_renderer library - Dart API"
[9]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/LiquidGlassSettings-class.html "LiquidGlassSettings class - liquid_glass_renderer library - Dart API"
[10]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/LiquidOval-class.html "LiquidOval class - liquid_glass_renderer library - Dart API"
[11]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/LiquidRoundedRectangle-class.html "LiquidRoundedRectangle class - liquid_glass_renderer library - Dart API"
[12]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/ "liquid_glass_renderer library - Dart API"
[13]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/FakeGlass-class.html "FakeGlass class - liquid_glass_renderer library - Dart API"
[14]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/GlassGlowLayer-class.html "GlassGlowLayer class - liquid_glass_renderer library - Dart API"
[15]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/LiquidStretch-class.html "LiquidStretch class - liquid_glass_renderer library - Dart API"
[16]: https://pub.dev/documentation/liquid_glass_renderer/latest/liquid_glass_renderer/RawLiquidStretch-class.html "RawLiquidStretch class - liquid_glass_renderer library - Dart API"
