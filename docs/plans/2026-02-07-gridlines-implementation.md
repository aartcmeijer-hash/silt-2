# Grid Lines Visibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add toggleable grid lines to the isometric grid with settings persistence for tactical clarity.

**Architecture:** Create SettingsManager autoload for settings persistence, enhance IsometricGrid with MeshInstance3D-based gridline rendering, add checkbox to OptionsMenu with signal-based updates.

**Tech Stack:** Godot 4.x (GDScript), ImmediateMesh for line rendering, ConfigFile for settings persistence

---

## Task 1: Create SettingsManager Autoload

**Files:**
- Create: `scripts/autoload/settings_manager.gd`
- Modify: `project.godot` (autoload registration)

**Step 1: Write settings manager script**

Create `scripts/autoload/settings_manager.gd`:

```gdscript
extends Node
## SettingsManager Autoload
## Handles game settings persistence and change notifications.

signal gridlines_changed(enabled: bool)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GRAPHICS := "graphics"
const KEY_GRIDLINES := "show_gridlines"

var _config: ConfigFile = ConfigFile.new()
var _gridlines_enabled: bool = true  # Default to enabled


func _ready() -> void:
	_load_settings()


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		# Settings file doesn't exist or is corrupted, use defaults
		_gridlines_enabled = true
		_save_settings()
	else:
		_gridlines_enabled = _config.get_value(SECTION_GRAPHICS, KEY_GRIDLINES, true)


func _save_settings() -> void:
	_config.set_value(SECTION_GRAPHICS, KEY_GRIDLINES, _gridlines_enabled)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Failed to save settings: " + str(err))


func get_gridlines_enabled() -> bool:
	return _gridlines_enabled


func set_gridlines_enabled(enabled: bool) -> void:
	if _gridlines_enabled == enabled:
		return

	_gridlines_enabled = enabled
	_save_settings()
	gridlines_changed.emit(enabled)
```

**Step 2: Register autoload in project settings**

Open `project.godot` and add to the `[autoload]` section:

```ini
SettingsManager="*res://scripts/autoload/settings_manager.gd"
```

If editing manually, find the `[autoload]` section and add the line. If using Godot Editor: Project → Project Settings → Autoload tab → Add `scripts/autoload/settings_manager.gd` with name `SettingsManager`.

**Step 3: Create UID file**

Create `scripts/autoload/settings_manager.gd.uid`:

```
uid://settings_manager_autoload
```

**Step 4: Test settings manager**

Run: Launch Godot editor and check Output for errors
Expected: No errors, SettingsManager loads successfully

**Step 5: Commit**

```bash
git add scripts/autoload/settings_manager.gd scripts/autoload/settings_manager.gd.uid project.godot
git commit -m "feat: add SettingsManager autoload for settings persistence

Add SettingsManager singleton to handle game settings with ConfigFile
persistence. Includes gridlines toggle with change notification signal.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add Gridline Rendering to IsometricGrid

**Files:**
- Modify: `scripts/game/isometric_grid.gd`

**Step 1: Add gridline rendering fields and methods**

Add to `scripts/game/isometric_grid.gd` after the `@onready var grid_map` line:

```gdscript
@onready var grid_map: GridMap = $GridMap

var _gridlines_mesh: MeshInstance3D = null
```

Add new methods at the end of the file:

```gdscript
func _create_gridlines() -> void:
	# Create MeshInstance3D for gridlines if it doesn't exist
	if _gridlines_mesh == null:
		_gridlines_mesh = MeshInstance3D.new()
		_gridlines_mesh.name = "GridLines"
		add_child(_gridlines_mesh)

	# Create material
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Create mesh
	var mesh := ImmediateMesh.new()
	_gridlines_mesh.mesh = mesh
	_gridlines_mesh.material_override = material

	# Draw gridlines
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var offset := _get_grid_offset()
	var y_pos := 0.01  # Slight offset to prevent z-fighting
	var line_color := Color(1.0, 1.0, 1.0, 0.9)  # Bright white, high opacity

	# Draw vertical lines (along Z-axis)
	for x in range(grid_width + 1):
		var world_x := (x + offset.x) * tile_size
		var start_z := offset.y * tile_size
		var end_z := (offset.y + grid_height) * tile_size

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(world_x, y_pos, start_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(world_x, y_pos, end_z))

	# Draw horizontal lines (along X-axis)
	for z in range(grid_height + 1):
		var world_z := (z + offset.y) * tile_size
		var start_x := offset.x * tile_size
		var end_x := (offset.x + grid_width) * tile_size

		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(start_x, y_pos, world_z))
		mesh.surface_set_color(line_color)
		mesh.surface_add_vertex(Vector3(end_x, y_pos, world_z))

	mesh.surface_end()


func _update_gridlines_visibility() -> void:
	if _gridlines_mesh != null:
		_gridlines_mesh.visible = SettingsManager.get_gridlines_enabled()


func _on_gridlines_setting_changed(enabled: bool) -> void:
	_update_gridlines_visibility()
```

**Step 2: Update _ready() to create and connect gridlines**

Modify the `_ready()` function in `scripts/game/isometric_grid.gd`:

```gdscript
func _ready() -> void:
	_populate_grid()
	_create_gridlines()
	_update_gridlines_visibility()
	SettingsManager.gridlines_changed.connect(_on_gridlines_setting_changed)
```

**Step 3: Test gridline rendering**

Run: Launch the game and enter tactical game screen
Expected: White gridlines visible on the isometric grid (if setting is enabled)

**Step 4: Commit**

```bash
git add scripts/game/isometric_grid.gd
git commit -m "feat: add gridline rendering to IsometricGrid

Add ImmediateMesh-based gridline rendering with 0.01 Y-offset to prevent
z-fighting. Connects to SettingsManager for visibility control.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add UI Controls to Options Menu

**Files:**
- Modify: `scenes/menus/options_menu.tscn`
- Modify: `scripts/menus/options_menu.gd`

**Step 1: Add gridlines checkbox to options menu scene**

Open `scenes/menus/options_menu.tscn` in Godot Editor:

1. Navigate to VBoxContainer node
2. Add new HBoxContainer after the Fullscreen node, before Spacer2
3. Name it "GridLines"
4. Add Label child with:
   - `custom_minimum_size = Vector2(150, 0)`
   - `layout_mode = 2`
   - `theme_override_font_sizes/font_size = 20`
   - `text = "Show Grid Lines"`
5. Add CheckBox child with:
   - `layout_mode = 2`
   - `button_pressed = true`
   - Name it "GridLinesCheck"
6. Connect the CheckBox's `toggled` signal to the OptionsMenu script method `_on_gridlines_toggled`

If editing `.tscn` file manually, add after line 105 (after Fullscreen HBoxContainer):

```
[node name="GridLines" type="HBoxContainer" parent="VBoxContainer"]
layout_mode = 2

[node name="Label" type="Label" parent="VBoxContainer/GridLines"]
custom_minimum_size = Vector2(150, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "Show Grid Lines"

[node name="GridLinesCheck" type="CheckBox" parent="VBoxContainer/GridLines"]
layout_mode = 2
button_pressed = true
```

And add connection at the end (after line 120):

```
[connection signal="toggled" from="VBoxContainer/GridLines/GridLinesCheck" to="." method="_on_gridlines_toggled"]
```

**Step 2: Add gridlines checkbox reference and handler to options menu script**

Modify `scripts/menus/options_menu.gd`:

Add after line 8 (after `fullscreen_check` onready var):

```gdscript
@onready var gridlines_check: CheckBox = $VBoxContainer/GridLines/GridLinesCheck
```

Update `_ready()` function (around line 11):

```gdscript
func _ready() -> void:
	# Load current settings
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	gridlines_check.button_pressed = SettingsManager.get_gridlines_enabled()

	$VBoxContainer/BackButton.grab_focus()
```

Add new handler at the end of the file:

```gdscript
func _on_gridlines_toggled(toggled_on: bool) -> void:
	SettingsManager.set_gridlines_enabled(toggled_on)
```

**Step 3: Test options menu integration**

Run: Launch game → Options menu
Expected:
- "Show Grid Lines" checkbox appears
- Checkbox state matches current setting
- Toggling checkbox updates gridlines immediately in tactical screen
- Setting persists after restart

**Step 4: Commit**

```bash
git add scenes/menus/options_menu.tscn scripts/menus/options_menu.gd
git commit -m "feat: add gridlines toggle to options menu

Add checkbox control for gridlines visibility in options menu. Loads
current setting on ready and persists changes via SettingsManager.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Integration Testing

**Step 1: Test complete flow**

Manual testing checklist:
1. Launch game fresh (delete `user://settings.cfg` if it exists)
2. Enter tactical game screen
3. Verify gridlines are visible by default
4. Return to main menu → Options
5. Uncheck "Show Grid Lines"
6. Return to tactical screen
7. Verify gridlines are hidden
8. Exit and restart game
9. Enter tactical screen
10. Verify gridlines remain hidden (persistence)
11. Return to options and re-enable
12. Verify gridlines appear immediately

**Step 2: Verify settings file**

Check: `~/.local/share/godot/app_userdata/[ProjectName]/settings.cfg` (Linux) or equivalent on your platform
Expected content:
```ini
[graphics]
show_gridlines=true
```

**Step 3: Test edge cases**

Test scenarios:
1. Delete settings file while game is running → defaults to enabled
2. Manually corrupt settings file → falls back to defaults
3. Rapidly toggle setting → no crashes or visual glitches
4. Enter/exit tactical screen multiple times → consistent behavior

**Step 4: Document completion**

Update design doc `docs/plans/2026-02-07-gridlines-design.md` with "Implementation Status: Complete" section at the end:

```markdown
## Implementation Status

**Status:** Complete
**Date:** 2026-02-07

**Implemented:**
- SettingsManager autoload with ConfigFile persistence
- ImmediateMesh-based gridline rendering in IsometricGrid
- Options menu checkbox with signal-based updates
- Default to enabled on first launch
- Real-time updates when setting changes

**Verified:**
- Settings persist across sessions
- Gridlines render correctly (Y=0.01 offset)
- UI updates reflect current state
- Edge cases handled (missing/corrupt settings file)

**Future Work:**
- Per-cell highlight system (Phase 2, as designed)
```

**Step 5: Final commit**

```bash
git add docs/plans/2026-02-07-gridlines-design.md
git commit -m "docs: mark gridlines implementation as complete

Document implementation completion with verification notes.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

**Total Tasks:** 4
**Estimated Time:** 20-30 minutes
**Key Files Modified:** 5
**New Files Created:** 2

**Implementation Order:**
1. Settings infrastructure (SettingsManager)
2. Rendering system (IsometricGrid enhancement)
3. UI integration (Options menu)
4. Testing and verification

**Testing Strategy:**
- Test after each task for immediate feedback
- Manual integration testing at the end
- Edge case verification
- Settings persistence validation

**DRY/YAGNI Compliance:**
- No premature abstractions
- Single responsibility per component
- Minimal code for requirements
- Future-ready without over-engineering
