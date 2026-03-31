const std = @import("std");

pub const TlsConfig = struct { enable: bool = false, cert: []const u8 = "", key: []const u8 = "" };
pub const RemoteManagement = struct { allow_remote: bool = false, secret_key: []const u8 = "", disable_control_panel: bool = false };
pub const QuotaExceeded = struct { switch_project: bool = true, switch_preview_model: bool = true };
pub const RoutingConfig = struct { strategy: []const u8 = "round-robin" };
pub const StreamingConfig = struct { keepalive_seconds: u16 = 0, bootstrap_retries: u8 = 0 };
pub const ModelEntry = struct { name: []const u8 = "", alias: []const u8 = "" };
pub const CloakConfig = struct { mode: []const u8 = "auto", strict_mode: bool = false, sensitive_words: []const []const u8 = &.{}, cache_user_id: bool = false };
pub const ClaudeHeaderDefaults = struct { user_agent: []const u8 = "", package_version: []const u8 = "", runtime_version: []const u8 = "", os: []const u8 = "", arch: []const u8 = "", timeout: []const u8 = "" };
pub const CodexHeaderDefaults = struct { user_agent: []const u8 = "", beta_features: []const u8 = "" };

pub const GeminiKey = struct { api_key: []const u8 = "", priority: u8 = 0, prefix: []const u8 = "", base_url: []const u8 = "", proxy_url: []const u8 = "", models: []const ModelEntry = &.{}, excluded_models: []const []const u8 = &.{} };
pub const ClaudeKey = struct { api_key: []const u8 = "", priority: u8 = 0, prefix: []const u8 = "", base_url: []const u8 = "", proxy_url: []const u8 = "", models: []const ModelEntry = &.{}, excluded_models: []const []const u8 = &.{}, cloak: CloakConfig = .{} };
pub const CodexKey = struct { api_key: []const u8 = "", priority: u8 = 0, prefix: []const u8 = "", base_url: []const u8 = "", websockets: bool = false, proxy_url: []const u8 = "", models: []const ModelEntry = &.{}, excluded_models: []const []const u8 = &.{} };
pub const OpenAICompatApiKey = struct { api_key: []const u8 = "", proxy_url: []const u8 = "" };
pub const OpenAICompatModel = struct { name: []const u8 = "", alias: []const u8 = "" };
pub const OpenAICompat = struct { name: []const u8 = "", priority: u8 = 0, prefix: []const u8 = "", base_url: []const u8 = "", api_key_entries: []const OpenAICompatApiKey = &.{}, models: []const OpenAICompatModel = &.{} };
pub const VertexKey = struct { api_key: []const u8 = "", prefix: []const u8 = "", base_url: []const u8 = "", proxy_url: []const u8 = "", models: []const ModelEntry = &.{}, excluded_models: []const []const u8 = &.{} };
pub const AmpModelMapping = struct { from: []const u8 = "", to: []const u8 = "" };
pub const AmpCode = struct { upstream_url: []const u8 = "", upstream_api_key: []const u8 = "", model_mappings: []const AmpModelMapping = &.{}, restrict_management_to_localhost: bool = false };

pub const Config = struct {
    host: []const u8 = "",
    port: u16 = 8317,
    tls: TlsConfig = .{},
    remote_management: RemoteManagement = .{},
    auth_dir: []const u8 = "~/.cli-proxy-api",
    api_keys: []const []const u8 = &.{},
    debug: bool = false,
    commercial_mode: bool = false,
    logging_to_file: bool = false,
    logs_max_total_size_mb: u32 = 0,
    error_logs_max_files: u32 = 10,
    usage_statistics_enabled: bool = false,
    proxy_url: []const u8 = "",
    force_model_prefix: bool = false,
    passthrough_headers: bool = false,
    request_retry: u8 = 3,
    max_retry_credentials: u8 = 0,
    max_retry_interval: u16 = 30,
    quota_exceeded: QuotaExceeded = .{},
    routing: RoutingConfig = .{},
    ws_auth: bool = false,
    streaming: StreamingConfig = .{},
    nonstream_keepalive_interval: u16 = 0,
    request_log: bool = false,
    gemini_api_key: []const GeminiKey = &.{},
    codex_api_key: []const CodexKey = &.{},
    claude_api_key: []const ClaudeKey = &.{},
    openai_compatibility: []const OpenAICompat = &.{},
    vertex_api_key: []const VertexKey = &.{},
    ampcode: AmpCode = .{},
    claude_header_defaults: ClaudeHeaderDefaults = .{},
    codex_header_defaults: CodexHeaderDefaults = .{},
};

test "default config has expected values" {
    const cfg = Config{};
    try std.testing.expectEqual(@as(u16, 8317), cfg.port);
    try std.testing.expectEqualStrings("", cfg.host);
    try std.testing.expectEqual(false, cfg.debug);
    try std.testing.expectEqual(@as(u8, 3), cfg.request_retry);
}
