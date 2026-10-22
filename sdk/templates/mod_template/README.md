# Mod Template

A minimal data-only content mod for Steam Navigator's framework.

## Use

1. Copy this directory to `sdk/examples/<your_mod_id>/` or `user://mods_dev/<your_mod_id>/`.
2. Change `manifest.json`:
   - `id`: lowercase letters/digits/underscore, 3-32 chars, must match every definition ID prefix.
   - `version`: SemVer `1.0.0`.
   - `content` and `localization` lists.
3. Add JSON files under `content/`, following the schemas in `schemas/`.
4. Add localization keys for every `name_key` / `description_key`.
5. Validate with the runtime (this template uses the active `items` 2.0 type):

```text
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/your_mod
```

Content versions are declared per type (`items` is 2.0, `roles` is still 1.0, ...); a mixed
mod is valid as long as every file matches its own type. Draft-only types (`weapons`,
`story_arcs`, `story_levels`) cannot be loaded by the runtime: check them with
`--mode=draft`, and `sdk/pack_mod.gd --release` refuses to pack them.

## Rules

- Content mods are data, not code: no `.gd`, `.dll`, `.exe`, `.tscn` or `.tres`.
- Every definition ID must use your own namespace: `<mod_id>:<type>/<local_id>`.
- Never modify another mod's definition directly; use a `patches` content file.
- Keep all files inside your mod directory. Packing adds the `mods/<mod_id>/` prefix.
