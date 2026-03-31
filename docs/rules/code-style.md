# Code Style Rules

## Language

- Zig 0.15.2+, targeting zig-framework (vnext branch)

## Patterns

- Use vtable interfaces for polymorphism (see `src/auth/types.zig` Store, `src/executor/types.zig` Executor)
- Use `std.json` for JSON parsing, manual `ArrayListUnmanaged(u8)` writer for complex JSON output
- All public types need at least one test
- Module structure: each module has `root.zig` that re-exports public types with `refAllDecls` test

## Naming

- Files: `snake_case.zig`
- Types: `PascalCase`
- Functions/methods: `camelCase`
- Constants: `snake_case` or `SCREAMING_SNAKE` for true constants

## Error Handling

- Return errors, don't panic
- Use `errdefer` for cleanup on error paths
- Optional logger fields: `?*framework.Logger = null` — always null-check before use

## Memory

- Prefer stack allocation and fixed-size buffers where possible
- Use allocator parameter for dynamic allocation
- Always `defer` or `errdefer` cleanup
- Use arena allocators for temporary work within a function
