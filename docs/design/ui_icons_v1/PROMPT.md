# Generation prompt

Tool: built-in imagegen

References: `../ui_visual_system/sn_visual_baseline_v1.png`, `../ui_controls_v1/sn_controls_atlas_v1.png`

`transparent_background: true`

```text
Use case: ui-mockup / production game UI icon sprite atlas.
Asset type: directly reusable transparent bitmap icon atlas for Steam Navigator.
Input image 1: SN Visual Baseline V1, style reference only.
Input image 2: existing transparent UI control atlas, palette/ink/hardware finish reference only.
Primary request: Create exactly 30 isolated TEXTLESS icons in a precise 6-column by 5-row grid on a genuinely transparent RGBA background. One icon per cell, centered, generous equal transparent gutters, no overlap, no plates, no badges, no frames, no circles behind icons, no labels. Canvas landscape approximately 1536×1280 or similar. At least 56 source pixels of fully transparent space between visible silhouettes and at least 48 outer margin. All icons approximately equal 150×150 visual footprint, front-facing or clean 3/4 pictogram view, consistent visual weight and stroke thickness.

EXACT ORDER, left to right:
Row 1 navigation: stacked market coins; pinned contract clipboard; crossed shipyard hammer and wrench; resupply barrel with droplet; intelligence binoculars; folded nautical chart with compass.
Row 2 navigation/resources: side-view steam cargo ship; angular coal chunks; single fresh-water droplet; durability gear with small shield; wooden cargo crate; stack of three coins.
Row 3 shipyard categories: riveted hull plate section; cylindrical steam boiler; cargo hold crate rack; brass navigation compass; life ring safety gear; simple passenger bunk bed; compact crossed utility tools.
Row 4 actions: plus sign made from brass bars; minus sign made from brass bars; bold checkmark; bold warning triangle with exclamation cutout; closed padlock; open padlock.
Row 5 statuses and route: anchor; clock/hourglass; three-wave weather symbol; stylized storm cloud with one lightning bolt; five-point reputation star; route marker made from two port dots connected by a curved dashed line.

STYLE: coherent hand-painted maritime steampunk pictograms matching Steam Navigator. Heavy dark hand-inked contour, simplified chunky silhouette, restrained aged brass, parchment cream, soot teal, muted blueprint blue, coal charcoal, water cyan, muted rust red and safety green accents. Subtle material texture inside shapes; crisp readable silhouette at 24–48 px. Light from upper left. Each icon should look from the same artist and same icon family.

PRODUCTION CONSTRAINTS: actual alpha-zero background everywhere outside icons; no colored haze, glow, shadow pool or vignette in gutters. No text, letters, numbers, pseudo-writing, watermark or logo. No scenery. No ornate micro-detail. No thin loose elements crossing cell boundaries. No duplicated or missing icons. No presentation board. Do not combine multiple cells into one scene. Icons must remain recognizable when downscaled.
```

