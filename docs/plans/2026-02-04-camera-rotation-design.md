# Camera Rotation System Design

**Date:** 2026-02-04
**Status:** Approved
**Goal:** Add Q/E camera rotation to the isometric tactical grid with smooth cardinal direction snapping

## Overview

Add orbital camera rotation to the tactical game screen, allowing players to rotate the view around the isometric grid using Q and E keys. The camera will smoothly transition between four cardinal directions (North, East, South, West) at 90° intervals.

## Key Decisions

- **3D Camera Approach**: Migrate from Camera2D to Camera3D for true orbital rotation
- **Classic 30° Isometric Angle**: Maintain current 2:1 visual ratio
- **Snappy Transitions**: 0.25 second rotation animations
- **Input Blocking**: Disable all input during camera rotation
- **Static Grid**: Camera orbits around stationary grid (grid never rotates)
- **Solid Floor Tiles**: Use GridMap with visible floor meshes
- **3D Entity Models**: Simple geometric shapes (cylinders/capsules)

## Architecture

### Scene Hierarchy

```
TacticalGameScreen (Node3D)
├── Camera3D (orbiting camera)
├── IsometricGrid (Node3D)
│   ├── GridMap (floor tiles)
│   └── EntityContainer (Node3D)
│       └── [Entity meshes...]
└── CanvasLayer (UI - unchanged)
```

### Migration from 2D to 3D

**Current State:**
- TacticalGameScreen: Node2D
- Camera: Camera2D (fixed at position 960, 540)
- IsometricGrid: Node2D with custom `_draw()` rendering grid lines
- Entities: Node2D placeholders positioned with 2D coordinates

**Target State:**
- TacticalGameScreen: Node3D
- Camera: Camera3D (orbiting at ~1000 units from center)
- IsometricGrid: Node3D containing GridMap with floor tile meshes
- Entities: Node3D with MeshInstance3D bodies and Label3D labels

## Camera System

### Camera Positioning

The Camera3D creates a classic isometric view using orbital positioning:

```gdscript
# Configuration
var grid_center := Vector3(0, 0, 0)
var camera_distance := 1000.0  # Horizontal distance from center
var camera_angle := 30.0  # Degrees down from horizontal
var camera_height := camera_distance * tan(deg_to_rad(camera_angle))  # ~577

# Starting position (South view, 0°)
camera.position = Vector3(camera_distance, camera_height, 0)
camera.look_at(grid_center, Vector3.UP)
```

### Rotation States

Four cardinal directions, differing only in Y-axis rotation:
- **North (0°)**: Camera at south, looking north
- **East (90°)**: Camera at west, looking east
- **South (180°)**: Camera at north, looking south
- **West (270°)**: Camera at east, looking west

### Rotation Controller

**State Variables:**
```gdscript
var current_angle: float = 0.0  # 0, 90, 180, or 270
var is_rotating: bool = false
var rotation_tween: Tween = null
```

**Input Handling:**
```gdscript
func _input(event: InputEvent) -> void:
    if is_rotating:
        return  # Block all input during rotation

    if event.is_action_pressed("rotate_left"):  # Q key
        rotate_camera(-90)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("rotate_right"):  # E key
        rotate_camera(90)
        get_viewport().set_input_as_handled()
```

**Rotation Logic:**
```gdscript
func rotate_camera(delta_angle: float) -> void:
    is_rotating = true

    var target_angle := fmod(current_angle + delta_angle + 360, 360)

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

### Input Blocking

During rotation (`is_rotating == true`):
- Q/E input ignored
- Grid clicks ignored
- Entity selection disabled
- Other gameplay input disabled
- UI input (pause menu) still works

Implementation: Check `is_rotating` flag at the start of `_input()` and all interaction handlers.

## Grid System

### GridMap Setup

**GridMap Configuration:**
- Cell size: Match isometric tile dimensions (32x16)
- Orientation: XZ plane (Y=0 for floor)
- Grid size: 20x20 cells
- Center: Grid centered at world origin (0, 0, 0)

**MeshLibrary Creation:**
1. Create new MeshLibrary resource
2. Add floor tile mesh:
   - Diamond-shaped quad matching isometric projection
   - Size: 32 units wide × 16 units deep
   - Material: Simple StandardMaterial3D with subtle color/texture
   - Optional: Bake grid lines into texture
3. Assign to GridMap's `mesh_library` property

### Coordinate System

**Grid Coordinates** remain integers (x, y) representing grid cells.

**World Coordinates** conversion simplified:
```gdscript
# Old (2D isometric projection math)
func grid_to_world(grid_x: int, grid_y: int) -> Vector2:
    var world_x := (grid_x - grid_y) * (tile_width / 2)
    var world_y := (grid_x + grid_y) * (tile_height / 2)
    return Vector2(world_x, world_y)

# New (3D with camera doing projection)
func grid_to_world(grid_x: int, grid_y: int) -> Vector3:
    var tile_size := 32.0  # Or use GridMap.cell_size
    return Vector3(grid_x * tile_size, 0, grid_y * tile_size)
```

**Benefits:**
- Camera angle creates isometric view (no manual projection math)
- Coordinates don't change when camera rotates
- Simpler and more intuitive

### Grid Population

At initialization, populate the GridMap:
```gdscript
func _ready() -> void:
    for x in range(grid_width):
        for y in range(grid_height):
            grid_map.set_cell_item(Vector3i(x, 0, y), 0)  # 0 = floor tile ID
```

## Entity System

### Entity Scene Structure

**EntityPlaceholder (Node3D):**
```
EntityPlaceholder (Node3D)
├── MeshInstance3D (body)
│   └── CylinderMesh or CapsuleMesh
└── Label3D (identifier text)
```

### Entity Mesh

**Configuration:**
- **Mesh Type**: CylinderMesh or CapsuleMesh
- **Dimensions**:
  - Height: 20-30 units
  - Radius: 10-12 units
- **Material**: StandardMaterial3D
  - Set `albedo_color` to entity's color (red for monsters, blue for survivors)
- **Position**: Y=0 (floor level) or slightly raised (~2 units) for visual pop

### Entity Label

**Label3D Configuration:**
- **Text**: Entity identifier ("M", "S1", "S2", etc.)
- **Billboard Mode**: `BILLBOARD_ENABLED` (always faces camera)
- **Pixel Size**: 0.01-0.02 (tune for readability)
- **Offset**: Position above entity (Y=25-30 units)
- **Modulate**: White or contrasting color for visibility

### Entity Positioning

Entities remain in EntityContainer, positioned using grid coordinates:

```gdscript
func _spawn_entity(id: String, grid_pos: Vector2i, type: EntityType, label: String, color: Color) -> void:
    var entity: Node3D = ENTITY_PLACEHOLDER_SCENE.instantiate()
    entity_container.add_child(entity)
    entity.setup(id, type, label, color)
    entity.position = grid.grid_to_world(grid_pos.x, grid_pos.y)  # Returns Vector3
    entities[id] = entity
```

Entities never rotate - they maintain upright orientation regardless of camera angle.

## Implementation Checklist

### Phase 1: 3D Conversion
- [ ] Create floor tile mesh and MeshLibrary
- [ ] Update IsometricGrid scene: Node2D → Node3D with GridMap
- [ ] Update IsometricGrid script: Remove `_draw()`, add GridMap population
- [ ] Update EntityPlaceholder scene to 3D structure
- [ ] Update EntityPlaceholder script for 3D (MeshInstance3D + Label3D)
- [ ] Replace Camera2D with Camera3D in TacticalGameScreen scene
- [ ] Update TacticalGameScreen: Node2D → Node3D

### Phase 2: Camera Rotation
- [ ] Add input actions: `rotate_left` (Q), `rotate_right` (E)
- [ ] Add camera rotation state variables to TacticalGameScreen
- [ ] Implement `rotate_camera()` function with tween
- [ ] Implement input blocking during rotation
- [ ] Position camera for 30° isometric view
- [ ] Test all four rotation angles

### Phase 3: Testing & Polish
- [ ] Verify entity positions consistent through rotations
- [ ] Test input blocking works correctly
- [ ] Verify UI (CanvasLayer) remains fixed
- [ ] Check pause menu works during rotation
- [ ] Tune camera distance and transition speed
- [ ] Add easing to rotation tween for smoothness

## Edge Cases & Considerations

### Rapid Input
- **Issue**: Player rapidly presses Q/E
- **Solution**: Input blocked during rotation prevents queuing
- **Behavior**: Additional presses ignored until rotation completes

### Pause During Rotation
- **Issue**: Player pauses while camera is rotating
- **Solution**: Configure tween to respect pause mode
- **Implementation**: `rotation_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)`

### Mouse Clicks During Rotation
- **Issue**: Player clicks grid while camera is moving
- **Solution**: Input handler checks `is_rotating` flag
- **Behavior**: Clicks ignored during rotation

### Camera Distance Tuning
- **Initial**: 1000 units
- **Adjust**: If grid appears too small/large, tune `camera_distance`
- **Constraint**: Maintain 30° angle (height = distance × tan(30°))

## Future Extensions

**Possible enhancements not in initial scope:**
- Terrain elevation (height variations in grid)
- Camera zoom (adjust distance with mouse wheel)
- Free rotation (non-cardinal angles)
- Camera tilt adjustment
- Smooth camera pan/movement
- Minimap that rotates with camera
- Rotation transition effects (particles, sound)

## Testing Strategy

### Visual Verification
1. Start game in tactical screen
2. Verify isometric grid appears with floor tiles
3. Check entities positioned correctly on grid
4. Press E repeatedly, verify 4 rotations return to original view
5. Press Q repeatedly, verify counter-clockwise rotation
6. Confirm UI stays fixed during rotation

### Input Testing
1. Press Q/E rapidly, verify only one rotation happens at a time
2. Click grid during rotation, verify clicks ignored
3. Pause during rotation, verify tween respects pause
4. Test other gameplay inputs blocked during rotation

### Coordinate Testing
1. Note entity positions before rotation
2. Rotate camera 360° (four 90° rotations)
3. Verify entities return to exact same positions
4. Test grid click coordinates work from all angles

## Success Criteria

- Camera smoothly rotates between 4 cardinal directions
- Q/E keys trigger rotation with snappy 0.25s animation
- Input blocked during rotation (no double-rotations or grid clicks)
- Grid and entities remain stationary (only camera moves)
- Isometric 30° view maintained at all angles
- UI (CanvasLayer) unaffected by camera rotation
- No coordinate system bugs (entities stay aligned to grid)
- Smooth eased transitions (not linear)
