# Generation prompt

Tool: built-in imagegen

Reference: ../ui_visual_system/sn_visual_baseline_v1.png (style reference)

transparent_background: true

```text
Use case: ui-mockup / production game UI sprite atlas.
Create one high-resolution PNG UI control atlas for Steam Navigator, genuinely transparent RGBA background (alpha zero in all gaps). Image 1 is ONLY a style reference: preserve its hand-painted inked dark petroleum-teal steel, aged brass corner hardware, warm parchment, muted blueprint blue, and cloth. Completely replace its composition with clean isolated TEXTLESS assets. No text, no letters, no numbers, no labels, no pseudo-writing, no diagrams, no pictograms, no measurement lines, no checkerboard painted into the image, no background scene, no presentation board.

Precise orderly atlas layout: landscape about 3072x2048, six columns by five rows with large fully transparent gutters, at least 64 source pixels between silhouettes and 64 outer margin. Each cell contains ONE isolated asset, centered, no overlap. All controls are perfectly orthographic front-facing and axis-aligned. Consistent line thickness, restrained top-left lighting. All instances within a row have equal outer size.

Row 1 six equal horizontal rectangular EMPTY steel button plates: normal dark teal, hover gently brass-highlighted, pressed darker inset, selected muted teal with brass inner keyline, disabled charcoal, danger muted rusty red. IDENTICAL corner geometry and outline; restrained crisp brass hardware exclusively in four corner squares, NO middle-edge rivets. Clean unmarked centers.
Row 2 six equal square resizable panel surfaces: dark teal steel frame, dark recessed steel frame, warm parchment sheet with subtly worn straight edges, muted dark blue technical paper WITHOUT grid, neutral pale canvas fabric rectangular panel, dark teal steel frame with fully TRANSPARENT CENTER. Square clean unmarked expanses, four modest corner anchors, continuous parallel straight horizontal/vertical edge bands.
Row 3 six equal long horizontal primitives: empty recessed input field, blank parchment list-row strip, empty progress-bar trough, unframed amber flat fill strip, unframed aqua flat fill strip, unframed sage-green flat fill strip. NO baked progress amounts, handles, symbols or numbers; fills are separate flat-ended stretchable rectangles.
Row 4 six equal upright rectangular SHORT hanging cloth flags: teal, slate-blue, parchment-cream, muted rust-red, dark desaturated disabled, selected teal with brighter brass hem. Blank faces. Straight flat bottom hems, NO pointed tails, NO dovetails; edge stitching only, no central folds. No hooks attached. Keep them suitable for nine-slice extension.
Row 5 six isolated fixed-size accessories: small empty square brass checkbox housing, small brass slider knob, brass hanging hook, short rope loop, brass paper clip, blank red wax seal with NO emblem. These fixed-size ornaments are separate from resizable controls.

CRITICAL NINE-SLICE ENGINEERING: every resizable control must have compact fixed corner areas no larger than 20% of its width/height; all distinctive rivets, seams and shine contained there. Middle 60% of each edge is straight, uniform-width and free of ornament. Center has very low-contrast nearly uniform color with subtle non-directional texture, no streaks or long scratches. No shadows or glow extending outside asset boundary, no external chains, no flourishes connecting sprites. Borders stay parallel, no perspective or bevel foreshortening. No baked tooltip arrows, central crests, corner-crossing ropes, gradients spanning a whole panel. Readable handcrafted silhouette at game size, not ornate baroque clutter. Preserve truly empty transparent gutters. This is a directly reusable texture sheet, not a concept screenshot.
```

