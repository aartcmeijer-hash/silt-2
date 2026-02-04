# Camera Rotation System Implementation Plan

**Status:** ✅ Complete (2026-02-04)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate the tactical game from 2D to 3D and add Q/E orbital camera rotation with smooth cardinal direction snapping.

**Architecture:** Convert TacticalGameScreen from Node2D to Node3D, replace Camera2D with orbiting Camera3D, use GridMap with floor tiles instead of drawn lines, and convert entities to 3D meshes with Label3D labels. Camera rotates around static grid with input blocking during transitions.

**Tech Stack:** Godot 4.5, GDScript, Camera3D, GridMap, MeshLibrary, Node3D, MeshInstance3D, Label3D

---

## Task 1: Create Floor Tile MeshLibrary

**Files:**
- Create: `resources/mesh_libraries/grid_tiles.tres` (MeshLibrary resource)
- Create: `resources/materials/floor_tile_material.tres` (StandardMaterial3D resource)

**Step 1: Create floor tile material in Godot Editor**

Open Godot Editor:
1. In FileSystem panel, navigate to `resources/` (create folder if needed)
2. Right-click → New Folder → name it `materials`
3. Right-click `materials/` → New Resource → StandardMaterial3D
4. Name it `floor_tile_material.tres`
5. In Inspector, set:
   - Albedo Color: `#3A4050` (subtle dark blue-gray)
   - Roughness: `0.8`
   - Metallic: `0.0`

**Step 2: Create MeshLibrary resource in Godot Editor**

In Godot Editor:
1. In FileSystem panel, create folder `resources/mesh_libraries/`
2. Right-click `mesh_libraries/` → New Resource → MeshLibrary
3. Name it `grid_tiles.tres`
4. Double-click to open in Inspector

**Step 3: Add floor tile mesh to MeshLibrary**

In MeshLibrary Inspector:
1. Click "Create Item" button
2. Item ID 0 will be created
3. Under "Mesh":
   - Click dropdown → New QuadMesh
   - Expand QuadMesh properties:
     - Size: X=`32`, Y=`32`
     - Orientation: `FACE_Y` (horizontal, faces up)
4. Under "Material":
   - Drag `floor_tile_material.tres` into the material slot
5. Save the resource (Ctrl+S)

Expected: MeshLibrary created with one floor tile (ID 0).

**Step 4: Verify MeshLibrary in editor**

In Godot Editor:
1. Select `grid_tiles.tres` in FileSystem
2. In Inspector, verify Item 0 exists with QuadMesh
3. Verify material is assigned

Expected: MeshLibrary shows Item 0 with quad mesh and material.

**Step 5: Commit**

```bash
git add resources/materials/floor_tile_material.tres resources/mesh_libraries/grid_tiles.tres
git commit -m "feat: create floor tile MeshLibrary for 3D grid

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Convert IsometricGrid to 3D with GridMap

**Files:**
- Modify: `scenes/game/isometric_grid.tscn` (convert Node2D → Node3D, add GridMap child)
- Modify: `scripts/game/isometric_grid.gd` (update for 3D coordinates)

**Step 1: Update IsometricGrid scene to 3D in Godot Editor**

Open Godot Editor:
1. Open `scenes/game/isometric_grid.tscn`
2. Right-click root `IsometricGrid` node → Change Type → `Node3D`
3. Click "Change" in confirmation dialog
4. Right-click `IsometricGrid` → Add Child Node → `GridMap`
5. Name it `GridMap`
6. Select GridMap node, in Inspector:
   - Theme → Mesh Library: drag `grid_tiles.tres` into slot
   - Cell → Size: X=`32`, Y=`32`, Z=`32`
   - Cell → Center Y: `false`
7. Save scene (Ctrl+S)

Expected: IsometricGrid is now Node3D with GridMap child.

**Step 2: Update IsometricGrid script for 3D**

Modify `scripts/game/isometric_grid.gd`:

```gdscript
class_name IsometricGrid
extends Node3D
## Renders a 20x20 isometric grid using GridMap and provides coordinate conversion.

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_size: float = 32.0

@onready var grid_map: GridMap = $GridMap


func _ready() -> void:
	_populate_grid()


func _populate_grid() -> void:
	# Center grid at origin by offsetting
	var offset_x := -grid_width / 2
	var offset_z := -grid_height / 2

	for x in range(grid_width):
		for z in range(grid_height):
			grid_map.set_cell_item(Vector3i(x + offset_x, 0, z + offset_z), 0)


func grid_to_world(grid_x: int, grid_y: int) -> Vector3:
	var offset_x := -grid_width / 2
	var offset_z := -grid_height / 2
	return Vector3((grid_x + offset_x) * tile_size, 0, (grid_y + offset_z) * tile_size)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	var offset_x := -grid_width / 2
	var offset_z := -grid_height / 2
	var grid_x := int(round(world_pos.x / tile_size)) - offset_x
	var grid_z := int(round(world_pos.z / tile_size)) - offset_z
	return Vector2i(grid_x, grid_z)


func get_grid_center() -> Vector2i:
	return Vector2i(grid_width / 2, grid_height / 2)


func get_bottom_row_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var start_x := (grid_width - count) / 2
	for i in range(count):
		positions.append(Vector2i(start_x + i, grid_height - 1))
	return positions
```

**Step 3: Test in Godot Editor**

Run the game:
1. Press F5 to run project
2. Navigate to tactical game screen
3. Verify grid appears (may not be visible yet due to camera)

Expected: No errors in console. Grid tiles created (even if not visible).

**Step 4: Commit**

```bash
git add scenes/game/isometric_grid.tscn scripts/game/isometric_grid.gd
git commit -m "feat: convert IsometricGrid to 3D with GridMap

Replace custom _draw() 2D rendering with GridMap using floor tiles.
Update coordinate conversion for 3D space with grid centered at origin.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Convert EntityPlaceholder to 3D

**Files:**
- Modify: `scenes/game/entity_placeholder.tscn` (convert to Node3D with MeshInstance3D and Label3D)
- Modify: `scripts/game/entity_placeholder.gd` (update for 3D rendering)

**Step 1: Update EntityPlaceholder scene to 3D in Godot Editor**

Open Godot Editor:
1. Open `scenes/game/entity_placeholder.tscn`
2. Right-click root `EntityPlaceholder` → Change Type → `Node3D`
3. Delete the `ColorRect` child node
4. Delete the `Label` child node
5. Right-click `EntityPlaceholder` → Add Child Node → `MeshInstance3D`
6. Name it `Body`
7. Select `Body`, in Inspector:
   - Mesh → New CapsuleMesh
   - Expand CapsuleMesh:
     - Radius: `10`
     - Height: `25`
   - Material Overlay → New StandardMaterial3D
8. Right-click `EntityPlaceholder` → Add Child Node → `Label3D`
9. Name it `Label3D`
10. Select `Label3D`, in Inspector:
    - Transform → Position: Y=`15`
    - Text: `Entity`
    - Font Size: `16`
    - Billboard: `Enabled`
    - Pixel Size: `0.015`
    - Modulate: `#FFFFFF`
11. Save scene (Ctrl+S)

Expected: EntityPlaceholder is now Node3D with capsule body and floating label.

**Step 2: Update EntityPlaceholder script for 3D**

Modify `scripts/game/entity_placeholder.gd`:

```gdscript
class_name EntityPlaceholder
extends Node3D
## Visual placeholder for a game entity (monster or survivor).

enum EntityType { MONSTER, SURVIVOR }

@export var entity_type: EntityType = EntityType.SURVIVOR
@export var entity_color: Color = Color.WHITE
@export var entity_label: String = ""

var entity_id: String = ""

@onready var body: MeshInstance3D = $Body
@onready var label_3d: Label3D = $Label3D


func _ready() -> void:
	_update_visuals()


func setup(id: String, type: EntityType, display_label: String, color: Color) -> void:
	entity_id = id
	entity_type = type
	entity_label = display_label
	entity_color = color
	if is_inside_tree():
		_update_visuals()


func _update_visuals() -> void:
	if body:
		var material := StandardMaterial3D.new()
		material.albedo_color = entity_color
		body.set_surface_override_material(0, material)
	if label_3d:
		label_3d.text = entity_label
```

**Step 3: Test in Godot Editor**

Open `entity_placeholder.tscn` in editor:
1. Verify capsule mesh is visible in 3D viewport
2. Verify label appears above capsule
3. Use 3D navigation to inspect from different angles

Expected: Entity placeholder displays as 3D capsule with label.

**Step 4: Commit**

```bash
git add scenes/game/entity_placeholder.tscn scripts/game/entity_placeholder.gd
git commit -m "feat: convert EntityPlaceholder to 3D

Replace ColorRect with CapsuleMesh and Label with Label3D.
Label billboard-faces camera and floats above entity body.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Convert TacticalGameScreen to 3D

**Files:**
- Modify: `scenes/game/tactical_game_screen.tscn` (convert Node2D → Node3D, replace Camera2D with Camera3D)
- Modify: `scripts/game/tactical_game_screen.gd` (update entity spawning for 3D)

**Step 1: Update TacticalGameScreen scene to 3D in Godot Editor**

Open Godot Editor:
1. Open `scenes/game/tactical_game_screen.tscn`
2. Right-click root `TacticalGameScreen` → Change Type → `Node3D`
3. Select `Camera2D` node → Delete it
4. Right-click `TacticalGameScreen` → Add Child Node → `Camera3D`
5. Name it `Camera3D`
6. Select `Camera3D`, in Inspector:
   - Transform → Position: X=`0`, Y=`600`, Z=`1000`
   - (We'll configure it properly in code)
7. Select `IsometricGrid` node
8. In Inspector, clear Position (should be 0, 0, 0)
9. Select `EntityContainer` node (child of IsometricGrid)
10. Right-click → Change Type → `Node3D`
11. Save scene (Ctrl+S)

Expected: TacticalGameScreen is Node3D with Camera3D and 3D grid.

**Step 2: Update TacticalGameScreen script for 3D entities**

Modify `scripts/game/tactical_game_screen.gd`:

```gdscript
extends Node3D
## Main tactical game screen controller.
## Manages the isometric grid, entities, and turn-based gameplay.

const ENTITY_PLACEHOLDER_SCENE := preload("res://scenes/game/entity_placeholder.tscn")

@onready var grid: IsometricGrid = $IsometricGrid
@onready var entity_container: Node3D = $IsometricGrid/EntityContainer
@onready var tactical_ui: Control = $CanvasLayer/TacticalUI
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var resume_button: Button = $CanvasLayer/PauseMenu/VBoxContainer/ResumeButton
@onready var camera: Camera3D = $Camera3D

var turn_state: TurnState
var entities: Dictionary = {}
var is_paused: bool = false


func _ready() -> void:
	turn_state = TurnState.new()
	turn_state.turn_changed.connect(_on_turn_changed)

	tactical_ui.monster_turn_pressed.connect(_on_monster_turn_pressed)
	tactical_ui.end_turn_pressed.connect(_on_end_turn_pressed)

	pause_menu.hide()
	_setup_camera()
	_spawn_initial_entities()
	_update_ui()


func _setup_camera() -> void:
	var grid_center := Vector3(0, 0, 0)
	var camera_distance := 1000.0
	var camera_angle := 30.0
	var camera_height := camera_distance * tan(deg_to_rad(camera_angle))

	camera.position = Vector3(0, camera_height, camera_distance)
	camera.look_at(grid_center, Vector3.UP)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _spawn_initial_entities() -> void:
	var monster_pos := grid.get_grid_center()
	_spawn_entity("monster_1", monster_pos, EntityPlaceholder.EntityType.MONSTER, "M", Color(0.9, 0.2, 0.2))

	var survivor_positions := grid.get_bottom_row_positions(4)
	for i in range(survivor_positions.size()):
		var pos := survivor_positions[i]
		var id := "survivor_%d" % (i + 1)
		_spawn_entity(id, pos, EntityPlaceholder.EntityType.SURVIVOR, "S%d" % (i + 1), Color(0.2, 0.6, 1.0))


func _spawn_entity(id: String, grid_pos: Vector2i, type: EntityPlaceholder.EntityType, label: String, color: Color) -> void:
	var entity: Node3D = ENTITY_PLACEHOLDER_SCENE.instantiate()
	entity_container.add_child(entity)
	entity.setup(id, type, label, color)
	entity.position = grid.grid_to_world(grid_pos.x, grid_pos.y)
	entities[id] = entity


func _on_monster_turn_pressed() -> void:
	turn_state.set_turn(TurnState.Turn.MONSTER)


func _on_end_turn_pressed() -> void:
	turn_state.set_turn(TurnState.Turn.PLAYER)


func _on_turn_changed(_new_turn: TurnState.Turn) -> void:
	_update_ui()


func _update_ui() -> void:
	tactical_ui.update_for_turn(turn_state.current_turn)


func toggle_pause() -> void:
	is_paused = not is_paused
	pause_menu.visible = is_paused
	get_tree().paused = is_paused

	if is_paused:
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.return_to_menu()
```

**Step 3: Test in Godot Editor**

Run the game (F5):
1. Navigate to tactical game screen
2. Verify 3D grid with floor tiles visible
3. Verify entities appear as colored capsules on grid
4. Verify labels visible above entities

Expected: 3D tactical screen renders with isometric camera view.

**Step 4: Commit**

```bash
git add scenes/game/tactical_game_screen.tscn scripts/game/tactical_game_screen.gd
git commit -m "feat: convert TacticalGameScreen to 3D

Replace Camera2D with Camera3D positioned for 30° isometric view.
Update entity spawning to use 3D coordinates (Vector3).
Camera positioned at 1000 units distance, looking at grid center.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Input Actions for Camera Rotation

**Files:**
- Modify: `project.godot` (add `rotate_left` and `rotate_right` input actions)

**Step 1: Add input actions in Godot Editor**

Open Godot Editor:
1. Project → Project Settings → Input Map tab
2. In "Add New Action" field, type: `rotate_left`
3. Click "Add" button
4. Click the "+" button next to `rotate_left`
5. Click "Keyboard" in popup
6. Press `Q` key
7. Click "OK"
8. Repeat for `rotate_right`:
   - Add action: `rotate_right`
   - Add keyboard key: `E`
9. Close Project Settings (changes auto-save)

Expected: Input actions `rotate_left` (Q) and `rotate_right` (E) added.

**Step 2: Verify in project.godot file**

Read `project.godot`:

```bash
grep -A3 "rotate_left" project.godot
grep -A3 "rotate_right" project.godot
```

Expected output showing input action entries.

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: add rotate_left (Q) and rotate_right (E) input actions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Implement Camera Rotation System

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd` (add rotation state and input handling)

**Step 1: Add camera rotation state variables**

Add to `scripts/game/tactical_game_screen.gd` after existing variables (around line 16):

```gdscript
# Camera rotation state
var current_angle: float = 0.0
var is_rotating: bool = false
var rotation_tween: Tween = null
```

**Step 2: Update _input() to handle rotation keys**

Replace the existing `_input()` function:

```gdscript
func _input(event: InputEvent) -> void:
	# Block all input during camera rotation
	if is_rotating:
		return

	if event.is_action_pressed("rotate_left"):
		rotate_camera(-90)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_right"):
		rotate_camera(90)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()
```

**Step 3: Implement rotate_camera() function**

Add after `_setup_camera()` function:

```gdscript
func rotate_camera(delta_angle: float) -> void:
	is_rotating = true

	var target_angle := fmod(current_angle + delta_angle + 360, 360)

	# Kill existing tween if rotating again
	if rotation_tween:
		rotation_tween.kill()

	rotation_tween = create_tween()
	rotation_tween.set_ease(Tween.EASE_IN_OUT)
	rotation_tween.set_trans(Tween.TRANS_CUBIC)
	rotation_tween.tween_property(camera, "rotation_degrees:y", target_angle, 0.25)
	rotation_tween.finished.connect(_on_rotation_complete)

	current_angle = target_angle


func _on_rotation_complete() -> void:
	is_rotating = false
	rotation_tween = null
```

**Step 4: Test camera rotation**

Run the game (F5):
1. Navigate to tactical screen
2. Press `E` key - camera should rotate 90° clockwise over 0.25s
3. Press `E` three more times - should complete 360° rotation
4. Press `Q` key - camera should rotate counter-clockwise
5. Try rapid Q/E presses - should block during rotation

Expected: Camera smoothly rotates around grid with Q/E, input blocked during rotation.

**Step 5: Commit**

```bash
git add scripts/game/tactical_game_screen.gd
git commit -m "feat: implement camera rotation with Q/E keys

Add orbital camera rotation with:
- 90° increments (4 cardinal directions)
- 0.25s smooth transitions with cubic easing
- Input blocking during rotation (prevents queuing)
- Rotation state tracking (current_angle, is_rotating)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Tune Camera Distance and Angle

**Files:**
- Modify: `scripts/game/tactical_game_screen.gd` (adjust camera distance if needed)

**Step 1: Test current camera view**

Run the game (F5):
1. Navigate to tactical screen
2. Observe grid visibility (can you see full 20x20 grid?)
3. Observe entity sizes (are they too small/large?)
4. Rotate camera to all 4 angles and check consistency

Current settings:
- Distance: 1000 units
- Angle: 30°
- Height: ~577 units

**Step 2: Adjust camera distance if needed**

If grid appears too small/large, modify `_setup_camera()` in `tactical_game_screen.gd`:

```gdscript
func _setup_camera() -> void:
	var grid_center := Vector3(0, 0, 0)
	var camera_distance := 800.0  # Reduced from 1000 if grid too small
	var camera_angle := 30.0
	var camera_height := camera_distance * tan(deg_to_rad(camera_angle))

	camera.position = Vector3(0, camera_height, camera_distance)
	camera.look_at(grid_center, Vector3.UP)
```

Try values: 800, 900, 1000, 1100 until grid fits nicely in viewport.

**Step 3: Verify isometric angle maintained**

At all distances, verify:
- Grid tiles appear diamond-shaped (isometric)
- Ratio of tile width to height is approximately 2:1
- Entities look consistent from all 4 rotation angles

**Step 4: Commit (if changes made)**

```bash
git add scripts/game/tactical_game_screen.gd
git commit -m "tune: adjust camera distance for optimal grid visibility

Set camera distance to [VALUE] units for better framing.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Final Testing and Verification

**Files:**
- None (testing only)

**Step 1: Visual verification**

Run the game (F5) and test:
1. Grid appears with 20x20 floor tiles
2. Tiles are diamond-shaped (isometric perspective)
3. Monster at grid center (red capsule with "M" label)
4. 4 survivors at bottom row (blue capsules with "S1"-"S4" labels)
5. UI elements (tactical UI, pause menu) render correctly

Expected: All visual elements render in 3D with isometric camera.

**Step 2: Rotation testing**

Test rotation behavior:
1. Press E → camera rotates 90° clockwise smoothly
2. Press E 3 more times → camera completes 360° and returns to start
3. Press Q → camera rotates 90° counter-clockwise
4. Press Q 4 times → camera completes -360° rotation
5. Rapidly press E multiple times → only one rotation happens at a time
6. During rotation, try clicking/pressing keys → input blocked

Expected: Smooth rotation with proper input blocking.

**Step 3: Coordinate consistency testing**

Test entity positions:
1. Note entity positions visually before rotation
2. Press E 4 times (complete 360° rotation)
3. Verify entities are in exact same positions as start
4. Entities never rotate (always face upward)
5. Labels always face camera (billboard effect)

Expected: Entities stay aligned to grid through all rotations.

**Step 4: UI and pause testing**

Test UI behavior:
1. Rotate camera → UI stays fixed (doesn't rotate)
2. Press ESC during rotation → pause menu appears
3. Verify tactical UI buttons still work after rotation

Expected: UI unaffected by camera rotation.

**Step 5: Edge case testing**

Test edge cases:
1. Rapid Q+E alternating → camera handles input blocking correctly
2. Rotate, then immediately pause → tween respects pause
3. Open pause menu, close, then rotate → works correctly

Expected: No crashes or visual glitches in edge cases.

**Step 6: Document any issues**

If any issues found:
- Note them in a comment or issue tracker
- Do NOT commit broken code
- Fix issues before proceeding

Expected: All tests pass before final commit.

---

## Task 9: Final Commit and Documentation

**Files:**
- Modify: `docs/plans/2026-02-04-camera-rotation-implementation.md` (mark as complete)

**Step 1: Update implementation plan status**

Add to top of this file after the header:

```markdown
**Status:** ✅ Complete (2026-02-04)
```

**Step 2: Create final summary commit**

```bash
git add docs/plans/2026-02-04-camera-rotation-implementation.md
git commit -m "docs: mark camera rotation implementation as complete

All tasks completed:
- Migrated from 2D to 3D rendering (Camera3D, GridMap, Node3D entities)
- Floor tile MeshLibrary with 32x32 quad meshes
- Entity placeholders using CapsuleMesh with Label3D
- Camera rotation with Q/E keys (90° increments, 0.25s transitions)
- Input blocking during rotation
- 30° isometric view maintained at all angles

Testing verified:
- Smooth camera rotation in all 4 cardinal directions
- Entity positions consistent through rotations
- UI remains fixed during camera movement
- Input correctly blocked during transitions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Step 3: Run final verification**

Run the game one final time:
1. Test all rotation directions
2. Verify visual quality
3. Check console for any warnings/errors

Expected: Clean execution with no errors.

**Step 4: Push changes (if using remote)**

If using git remote:
```bash
git push origin main
```

Expected: All commits pushed successfully.

---

## Success Criteria Checklist

- ✅ Camera rotates smoothly between 4 cardinal directions
- ✅ Q/E keys trigger rotation with 0.25s animation
- ✅ Input blocked during rotation (no double-rotations or grid clicks)
- ✅ Grid and entities remain stationary (only camera moves)
- ✅ Isometric 30° view maintained at all angles
- ✅ UI (CanvasLayer) unaffected by camera rotation
- ✅ No coordinate system bugs (entities stay aligned to grid)
- ✅ Smooth eased transitions (cubic easing, not linear)

## Notes for Implementer

**Godot Editor Workflows:**
- Most scene structure changes require using Godot Editor (changing node types, adding children)
- MeshLibrary creation is editor-only (cannot be done in code)
- Input actions must be added via Project Settings
- Test frequently in editor during scene modifications

**Common Pitfalls:**
- Forgetting to update `@onready` references after changing node types
- Not centering the grid at origin (causes rotation to look wrong)
- Forgetting to convert EntityContainer from Node2D to Node3D
- Not setting GridMap mesh_library property

**Testing Strategy:**
- Test in Godot Editor after each scene change
- Run game (F5) after each script change
- Verify rotation from all 4 angles before moving to next task
- Check console for errors frequently

**Performance Notes:**
- GridMap is more performant than drawing individual meshes
- Label3D billboarding has minimal performance cost
- Tween animations are efficient in Godot 4.5
