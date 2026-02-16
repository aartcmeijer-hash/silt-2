# CLAUDE.md

## GDScript Gotchas

**Multi-line expressions require explicit types**

GDScript cannot infer types from expressions that span multiple lines. Use explicit type annotations instead of `:=`:

```gdscript
# Bad — Parser Error: Cannot infer the type of "dist"
var dist := (abs(a.x - b.x)
        + abs(a.y - b.y))

# Good
var dist: int = (abs(a.x - b.x)
        + abs(a.y - b.y))
```
