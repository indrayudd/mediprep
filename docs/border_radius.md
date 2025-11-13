You’re passing a **`BorderRadius`** where the API expects a **`double`**.
In `liquid_glass_renderer`, all rounded shapes use a simple numeric `borderRadius` (uniform radius), **not** `BorderRadius`/`Radius` objects. The package docs explicitly call this out: “All shapes take a simple `double` for `borderRadius` instead of `BorderRadius` or `Radius`”.

### Correct usage from the docs

**Rounded superellipse (recommended)**

```dart
LiquidRoundedSuperellipse(borderRadius: 24)   // ✅ double, not BorderRadius
```

The class itself is a shape type used by `LiquidGlass` and expects `borderRadius` as a `double`.

**Rounded rectangle**

```dart
LiquidRoundedRectangle(borderRadius: 16)      // ✅ double, not BorderRadius
```

Same expectation: `borderRadius` is a `double` (uniform), not a `BorderRadius` object.

**Oval / circle**

```dart
LiquidOval()                                  // ✅ no borderRadius parameter
```

### How this appears in a real `LiquidGlass` tree (from package examples)

```dart
LiquidGlassLayer(
  settings: const LiquidGlassSettings(blur: 10, glassColor: Color(0x33FFFFFF)),
  child: Column(
    children: [
      LiquidGlass.inLayer(
        shape: LiquidRoundedSuperellipse(borderRadius: 20), // ✅ double
        child: const SizedBox.square(dimension: 120),
      ),
      const SizedBox(height: 24),
      LiquidGlass.inLayer(
        shape: LiquidRoundedRectangle(borderRadius: 24),     // ✅ double
        child: const SizedBox.square(dimension: 120),
      ),
    ],
  ),
);
```

This mirrors the usage shown on the package page and examples (note the plain numeric `borderRadius`).

### What to change in your file

Wherever you have something like:

```dart
// ❌ wrong
shape: LiquidRoundedRectangle(borderRadius: BorderRadius.circular(24)),
// or
shape: LiquidRoundedSuperellipse(borderRadius: Radius.circular(24)),
```

replace with:

```dart
// ✅ right
shape: LiquidRoundedRectangle(borderRadius: 24);
// or
shape: LiquidRoundedSuperellipse(borderRadius: 24);
```

If you need non-uniform corner radii, these shapes don’t support that—only a single uniform radius is supported.

**References (pub.dev):** Supported shapes & `borderRadius` note; examples using numeric `borderRadius`.
