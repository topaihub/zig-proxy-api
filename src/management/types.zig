pub const ManagementResponse = struct {
    success: bool = true,
    message: []const u8 = "",
    data: ?[]const u8 = null,
};

pub const AuthListEntry = struct {
    id: []const u8 = "",
    provider: []const u8 = "",
    label: []const u8 = "",
    disabled: bool = false,
};
