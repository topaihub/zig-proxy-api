# Architecture Rules

## Module Dependencies

Allowed dependency direction (top depends on bottom):

```
main.zig
├── api/          → server, translator, executor, auth
├── management/   → server, auth, config
├── tui/          → server (client only)
├── amp/          → server
├── wsrelay/      → server
├── server/       → framework
├── config/       → framework
├── auth/         → framework, config
├── translator/   → (standalone, no project deps)
├── executor/     → framework, translator
├── scheduler/    → (standalone, no project deps)
├── store/        → (standalone, no project deps)
└── logging/      → (standalone)
```

## Forbidden Dependencies

- `translator/` must NOT import `auth/`, `executor/`, `server/`
- `scheduler/` must NOT import `server/`, `auth/`
- `store/` must NOT import `server/`, `auth/`
- No circular dependencies between modules

## Adding a New Provider

1. Add executor in `src/executor/providers/{name}.zig` — implement Executor vtable
2. Add auth in `src/auth/providers/{name}.zig` — implement OAuth flow
3. Add provider constant in `src/auth/providers.zig`
4. Register executor in `main.zig`
5. Add format types in `src/translator/formats/` if protocol differs from existing
6. Register translation pairs in `src/translator/init.zig`

## Adding a New API Route

1. Add handler method to `src/api/handlers.zig`
2. Add file-level handler function in `src/main.zig`
3. Register route on router in `main.zig`
4. Handler MUST include MethodTrace (see logging rules)
