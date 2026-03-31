# Sub-Project 3: Authentication System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Authentication system with token store, API key validation, auth manager, and provider-specific authenticator stubs for all providers.

**Architecture:** Auth module with Store interface for token persistence (file-based), Manager for coordinating authenticators, API key middleware for inbound request auth, and per-provider authenticator stubs. OAuth flows will be implemented as provider-specific logic in later sub-projects when executors are ready.

**Tech Stack:** Zig 0.15.2, zig-framework (effects.FileSystem, workflow.WorkflowRunner), std.json

---

## File Structure

| File | Responsibility |
|------|---------------|
| `src/auth/root.zig` | Module exports |
| `src/auth/types.zig` | Auth record, Store interface, Authenticator interface |
| `src/auth/file_store.zig` | File-based token persistence |
| `src/auth/api_key.zig` | API key validation middleware |
| `src/auth/manager.zig` | Auth manager: register providers, coordinate login/refresh |
| `src/auth/providers.zig` | Provider ID constants and stub authenticator registry |

---

### Task 1: Auth Types

**Files:**
- Create: `src/auth/types.zig`
- Create: `src/auth/root.zig`

Core types: Auth record (id, provider, prefix, label, token, refresh_token, expires_at, metadata, disabled), Store interface (list, save, delete), Authenticator interface (provider, login).

### Task 2: File Store

**Files:**
- Create: `src/auth/file_store.zig`

File-based Store implementation. Save/load auth records as JSON files in auth_dir. List scans directory for .json files.

### Task 3: API Key Middleware

**Files:**
- Create: `src/auth/api_key.zig`

Middleware that checks X-Api-Key or Authorization header against configured api_keys list.

### Task 4: Auth Manager

**Files:**
- Create: `src/auth/manager.zig`

Manager struct: register authenticators by provider, lookup, list all auth records from store.

### Task 5: Provider Constants + Integration

**Files:**
- Create: `src/auth/providers.zig`
- Modify: `src/main.zig`

Provider ID constants (gemini, claude, codex, qwen, kimi, iflow, antigravity, vertex, aistudio, gemini_cli). Wire auth module into main.zig.
