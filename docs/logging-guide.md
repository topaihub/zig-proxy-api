# Logging Integration Guide

## Quick Reference

### 1. Adding logging to a new module

Every module that does meaningful work needs a logger. Pattern:

```zig
const framework = @import("framework");

pub const MyModule = struct {
    allocator: std.mem.Allocator,
    logger: ?*framework.Logger = null,

    pub fn setLogger(self: *MyModule, logger: *framework.Logger) void {
        self.logger = logger;
    }

    pub fn doWork(self: *MyModule) !void {
        // Structured log
        if (self.logger) |l| l.subsystem("mymodule").info("work started", &.{
            framework.LogField.string("key", value),
        });

        // Step trace for external call
        var step: ?framework.StepTrace = null;
        if (self.logger) |l| {
            step = try framework.StepTrace.begin(self.allocator, l, "mymodule/external", "call_name", 5000);
        }
        defer if (step) |*s| s.deinit();

        // ... do external call ...

        if (step) |*s| s.finish(null);
    }
};
```

### 2. Wiring logger in main.zig

After creating AppContext:
```zig
var my_module = MyModule.init(allocator);
my_module.setLogger(app_ctx.logger);
```

### 3. Decision tree

```
Is this an HTTP request entry point?
  → YES: Use RequestTrace (begin + complete)

Is this a method that does significant work?
  → YES: Use MethodTrace (begin + finishSuccess/finishError)

Does this call an external system?
  → YES: Use StepTrace (begin + finish)

Is this a state change or notable event?
  → YES: Use logger.subsystem("x").info("msg", &.{fields})

None of the above?
  → No logging needed
```

### 4. Error path logging

ALWAYS log errors with context:
```zig
result catch |err| {
    if (self.logger) |l| l.subsystem("mymodule").err("operation failed", &.{
        framework.LogField.string("error", @errorName(err)),
        framework.LogField.string("context", relevant_info),
    });
    return err;
};
```
