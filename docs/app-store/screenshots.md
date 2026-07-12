# App Store Screenshots

The repository includes a repeatable two-stage workflow: deterministic native captures, followed by benefit-led App Store marketing banners.

## Capture

Run from the repository root:

```sh
scripts/capture_app_store_screenshots.sh
```

Raw output:

```text
AppStore/screenshots-raw/
├── iphone-6.9/
│   ├── 01-today.png
│   ├── 02-craving-rescue.png
│   ├── 03-plan.png
│   ├── 04-insights.png
│   └── 05-ai-coach.png
└── ipad-13/
    ├── 01-today.png
    ├── 02-craving-rescue.png
    ├── 03-plan.png
    ├── 04-insights.png
    └── 05-ai-coach.png
```

The capture uses deterministic seeded data and the native simulator resolution. Current expected portrait sizes are:

- 6.9-inch iPhone (iPhone 17 Pro Max): 1320×2868.
- 13-inch iPad (iPad Pro 13-inch M5): 2064×2752.

Then render the marketing set:

```sh
node scripts/render_app_store_marketing_screenshots.cjs
```

Final upload-ready files are written to `AppStore/screenshots/` at the same exact dimensions. They combine real app UI with benefit-led headlines and TeoPateo's production color/type system.

Screens are ordered to tell the product story: immediate progress, one-tap craving rescue, a concrete quit plan, learned risk patterns, and the consented AI coach.

The editable Figma campaign source is [TeoPateo App Store Marketing Screenshots](https://www.figma.com/design/2uhCiejZj9KSyIMnXamx7w). The local renderer is the reproducible export fallback and should remain visually aligned with that file.
