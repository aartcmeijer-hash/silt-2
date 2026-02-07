# Grid Lines Visibility Design

**Date:** 2026-02-07
**Feature:** Toggleable grid lines for tactical clarity

## Overview

Add clear, prominent visual borders around each grid tile in the isometric grid to improve tactical clarity. The gridlines will be toggleable via the settings menu with persistence across game sessions.

## Requirements

- Visual borders around each grid cell (20×20 grid)
- Clear and prominent styling for tactical gameplay
- Toggleable via settings menu
- Persistence across game sessions
- Future support for per-cell border effects (blinking, highlighting multiple cells)

## Architecture

### Components

1. **Settings Integration**
   - Store preference in `user://settings.cfg` using `ConfigFile`
   - `SettingsManager` autoload handles loading/saving and change notifications
   - Options menu updated with "Show Grid Lines" checkbox

2. **IsometricGrid Enhancement**
   - `MeshInstance3D` child node for gridline rendering
   - Uses `ImmediateMesh` for line geometry
   - Visibility controlled by settings

3. **Future Per-Cell Border System**
   - Separate `CellHighlightManager` for dynamic cell effects
   - Supports multi-cell highlighting with synchronized animations
   - Layered above base gridlines (Y=0.02+)

### Visual Implementation

**Base Gridlines:**
- `MeshInstance3D` node named "GridLines" as child of `IsometricGrid`
- `ImmediateMesh` with line geometry
- `StandardMaterial3D` configuration:
  - `shading_mode = UNSHADED` (consistent visibility)
  - `vertex_color_use_as_albedo = true`
  - Bright white/light gray color with 0.8-1.0 opacity
  - Line thickness: 1-2 units via geometry
- Position: Y = 0.01 (prevents z-fighting while appearing coplanar)
- Draws complete border around each of 400 cells (20×20)

**Drawing Logic:**
- Horizontal lines (Z-direction) for each X position
- Vertical lines (X-direction) for each Z position
- ~840 line segments total (21 horizontal + 21 vertical)
- Single mesh, drawn once and cached

### Future Per-Cell Highlights

**Design Considerations:**
- Each highlighted cell gets own visual effect node
- Position at Y = 0.02+ (layers above base gridlines)
- Animation via `Tween` or `AnimationPlayer`
- Independent visibility from base gridlines

**Multi-Cell Support:**
- Batch operations: `highlight_cells(Array[Vector2i], color, effect_type)`
- Synchronized effects across cell groups
- Group management for easy updates/clearing

**Example Use Cases:**
- Movement range (multiple cells, synchronized pulse)
- Attack area (area of effect indicator)
- Unit selection (group highlighting)

## Data Flow

**On Game Start:**
1. `SettingsManager` loads settings from `user://settings.cfg`
2. `IsometricGrid._ready()` queries `SettingsManager.get_gridlines_enabled()`
3. Gridlines mesh generated and visibility set

**When Player Changes Setting:**
1. Player toggles checkbox in `OptionsMenu`
2. `OptionsMenu` calls `SettingsManager.set_gridlines_enabled(value)`
3. `SettingsManager` saves to config and emits `gridlines_changed` signal
4. `IsometricGrid` updates `gridlines_node.visible`
5. Change is immediate and persists

**Component Responsibilities:**
- **SettingsManager**: Settings persistence and notifications
- **OptionsMenu**: UI presentation and user input
- **IsometricGrid**: Gridline rendering and setting response
- **CellHighlightManager** (future): Per-cell effects

## Defaults & Edge Cases

**Defaults:**
- Gridlines enabled by default on first launch
- Falls back to enabled if settings file missing/corrupted

**Edge Cases:**
- Queue gridline setup if `IsometricGrid` loads before `SettingsManager`
- Gridlines redraw automatically if grid dimensions change
- Immediate updates when toggled (no scene restart)

**Performance:**
- Single mesh with ~840 line segments
- Negligible performance impact
- Only visibility toggled at runtime

## Implementation Phases

### Phase 1: Base Gridlines (MVP)
- Create `SettingsManager` autoload
- Add gridline rendering to `IsometricGrid`
- Update options menu with toggle
- Settings persistence

### Phase 2: Per-Cell Highlights (Future)
- Create `CellHighlightManager`
- Implement batch highlighting
- Add synchronized animation support
- Integrate with game systems (movement, attacks, etc.)
