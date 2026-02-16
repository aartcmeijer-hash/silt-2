# CLAUDE.md

## GDScript Gotchas

**`abs()` and arithmetic on `Vector2i` components require explicit types**

GDScript cannot infer types from expressions involving `abs()` on `Vector2i` components (`.x`, `.y`), even on a single line. Use explicit type annotations instead of `:=`:

```gdscript
# Bad — Parser Error: Cannot infer the type of "d"
var d := abs(tile.x - other.x) + abs(tile.y - other.y)

# Bad — also fails when multi-line
var dist := (abs(a.x - b.x)
        + abs(a.y - b.y))

# Good
var d: int = abs(tile.x - other.x) + abs(tile.y - other.y)
var dist: int = (abs(a.x - b.x) + abs(a.y - b.y))
```
