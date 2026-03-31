#!/bin/bash
# Logging compliance check — run before commit or in CI
# Usage: ./scripts/check-logging.sh

echo "=== Logging Compliance Check ==="
ERRORS=0

# Check 1: No std.debug.print in src/
if grep -rn "std.debug.print\|std.log\." src/ --include="*.zig" | grep -v test | grep -v "//"; then
    echo "❌ FAIL: Found std.debug.print or std.log usage. Use framework Logger instead."
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PASS: No raw debug prints"
fi

# Check 2: HTTP handler files should have RequestTrace
if ! grep -q "request_trace" src/server/http_server.zig; then
    echo "❌ FAIL: http_server.zig missing RequestTrace"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PASS: HTTP server has RequestTrace"
fi

# Check 3: API handlers should have MethodTrace
if ! grep -q "MethodTrace" src/api/handlers.zig; then
    echo "❌ FAIL: api/handlers.zig missing MethodTrace"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PASS: API handlers have MethodTrace"
fi

# Check 4: Executor calls should have StepTrace
if ! grep -q "StepTrace" src/api/handlers.zig; then
    echo "❌ FAIL: Executor calls missing StepTrace"
    ERRORS=$((ERRORS + 1))
else
    echo "✅ PASS: Executor calls have StepTrace"
fi

# Check 5: Modules with external calls should have logger field
for f in src/auth/manager.zig src/scheduler/selector.zig src/config/hot_reload.zig src/management/handler.zig; do
    if [ -f "$f" ] && ! grep -q "logger" "$f"; then
        echo "❌ FAIL: $f missing logger field"
        ERRORS=$((ERRORS + 1))
    fi
done
echo "✅ PASS: Key modules have logger fields"

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All logging checks passed"
else
    echo "❌ $ERRORS logging check(s) failed"
    exit 1
fi
