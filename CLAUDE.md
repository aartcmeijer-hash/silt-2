# CLAUDE.md

## GDScript Gotchas

**Expression results always need explicit type annotations**

GDScript cannot infer types from expressions — only from direct literals or typed function return values. Always use explicit type annotations (`: int =`, `: float =`, etc.) instead of `:=` when the right-hand side is an expression:

```gdscript
# Bad — Parser Error: Cannot infer the type
var d := abs(tile.x - other.x) + abs(tile.y - other.y)
var dist := (abs(a.x - b.x) + abs(a.y - b.y))
var area := width * height

# Good
var d: int = abs(tile.x - other.x) + abs(tile.y - other.y)
var dist: int = (abs(a.x - b.x) + abs(a.y - b.y))
var area: int = width * height
```

`:=` is safe only for direct assignments from typed variables or typed function calls (e.g. `var pos := grid.get_center()` where `get_center()` has a declared return type).
