const std = @import("std");
const types = @import("../../core/shared/types.zig");

/// Per-node expand/collapse for Marionette-style tiered transcript collapse.
/// Missing keys use defaults from `CollapseDefaults`.
pub const ToolCollapseTree = struct {
    turn_expanded: std.AutoHashMapUnmanaged(u64, bool) = .empty,
    group_expanded: std.AutoHashMapUnmanaged(u64, bool) = .empty,
    preferred_turn_key: ?u64 = null,
    /// After `]`, unrecorded T1 nodes stay collapsed until explicitly expanded.
    t1_force_collapsed: bool = false,

    pub fn deinit(self: *ToolCollapseTree, alloc: std.mem.Allocator) void {
        self.turn_expanded.deinit(alloc);
        self.group_expanded.deinit(alloc);
        self.* = .{};
    }

    pub fn setPreferredTurn(self: *ToolCollapseTree, turn_key: u64) void {
        self.preferred_turn_key = turn_key;
    }

    pub fn turnIsExpanded(self: *const ToolCollapseTree, turn_key: u64, defaults: CollapseDefaults) bool {
        return self.turn_expanded.get(turn_key) orelse defaults.turn_expanded;
    }

    pub fn groupIsExpanded(self: *const ToolCollapseTree, group_key: u64, defaults: CollapseDefaults) bool {
        if (self.group_expanded.get(group_key)) |value| return value;
        if (self.t1_force_collapsed) return false;
        return defaults.group_expanded;
    }

    pub fn setTurnExpanded(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64, expanded: bool) !void {
        try self.turn_expanded.put(alloc, turn_key, expanded);
        self.preferred_turn_key = turn_key;
    }

    pub fn setGroupExpanded(self: *ToolCollapseTree, alloc: std.mem.Allocator, group_key: u64, expanded: bool) !void {
        try self.group_expanded.put(alloc, group_key, expanded);
    }

    /// `[` — collapse preferred turn to T0 umbrella only.
    pub fn collapseAllToT0(self: *ToolCollapseTree, alloc: std.mem.Allocator) !void {
        if (self.preferred_turn_key) |turn_key| {
            try self.setTurnExpanded(alloc, turn_key, false);
            return;
        }
        var it = self.turn_expanded.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = false;
        }
    }

    /// `]` — expand T0; keep T1 at headers only.
    pub fn expandT0KeepT1Collapsed(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64) !void {
        try self.setTurnExpanded(alloc, turn_key, true);
        self.t1_force_collapsed = true;
        var it = self.group_expanded.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = false;
        }
    }

    pub fn toggleTurn(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64, defaults: CollapseDefaults) !void {
        const next = !self.turnIsExpanded(turn_key, defaults);
        try self.setTurnExpanded(alloc, turn_key, next);
    }
};

pub const CollapseDefaults = struct {
    turn_expanded: bool = true,
    group_expanded: bool = true,

    pub fn fromCollapseToolCalls(collapse_tool_calls: bool) CollapseDefaults {
        return .{
            .turn_expanded = true,
            .group_expanded = !collapse_tool_calls,
        };
    }
};

pub fn groupKeyForPresentation(group_id: types.ToolPresentationGroupId) u64 {
    return (@as(u64, @truncate(group_id.turn_id)) << 32) ^ group_id.anchor_step_id;
}

pub fn groupKeyForSequentialAnchor(entry_id: u32) u64 {
    return 0x8000_0000_0000_0000 | @as(u64, entry_id);
}

pub fn turnKeyFromLifecycle(turn_id: u64) u64 {
    return turn_id;
}

pub fn turnKeySynthetic(span_start_entry_id: u32) u64 {
    return 0xC000_0000_0000_0000 | @as(u64, span_start_entry_id);
}

test "collapse defaults follow collapse_tool_calls" {
    const collapsed = CollapseDefaults.fromCollapseToolCalls(true);
    try std.testing.expect(collapsed.turn_expanded);
    try std.testing.expect(!collapsed.group_expanded);
    const expanded = CollapseDefaults.fromCollapseToolCalls(false);
    try std.testing.expect(expanded.group_expanded);
}

test "tree bracket ops" {
    const alloc = std.testing.allocator;
    var tree: ToolCollapseTree = .{};
    defer tree.deinit(alloc);
    const defaults = CollapseDefaults.fromCollapseToolCalls(true);
    try tree.toggleTurn(alloc, 7, defaults);
    try std.testing.expect(!tree.turnIsExpanded(7, defaults));
    try tree.expandT0KeepT1Collapsed(alloc, 7);
    try std.testing.expect(tree.turnIsExpanded(7, defaults));
    try tree.setGroupExpanded(alloc, 99, true);
    try tree.expandT0KeepT1Collapsed(alloc, 7);
    try std.testing.expect(!tree.groupIsExpanded(99, defaults));
    try tree.collapseAllToT0(alloc);
    try std.testing.expect(!tree.turnIsExpanded(7, defaults));
}
