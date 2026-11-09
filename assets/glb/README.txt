ARTIST DROP FOLDER
==================
Put your .glb files in this folder (subfolders are fine).
Then open showcase.tscn and press Play (F6), or click "Generate" on the
Showcase node in the Inspector to preview the grid in the editor.

- Godot imports each GLB automatically when the editor regains focus.
- Models are laid out in a grid, centred in their cell, resting on the floor.
- The file name is shown as a label under each model.

BAKING SCENES (Godot editor)
----------------------------
Open one of these files in the Script editor and use File > Run (Ctrl+Shift+X):
  tools/generate_fly_level.gd   -> levels/generated/showcase_fly.tscn  (fly-around level)
  tools/generate_copy_scene.gd  -> levels/generated/showcase_copy.tscn (plain scene to copy/paste from)
Re-running overwrites the generated files, so copy what you need out of them.

Or from a terminal:
  godot --headless --path . --script res://tools/generate_cli.gd -- fly copy
