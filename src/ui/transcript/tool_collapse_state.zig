const std = @import("std");
const types = @import("../../core/shared/types.zig");

/// Per-node expand/collapse for Marionette-style tiered transcript collapse.
/// Missing keys use defaults from `CollapseDefaults`.
pub const ToolCollapseTree = struct {
    turn_expanded: std.AutoHashMapUnmanaged(u64, bool) = .empty,
    group_expanded: std.AutoHashMapUnmanaged(u64, bool) = .empty,
    preferred_turn_key: ?u64 = null,
    /// After a headers-only step, unrecorded T1 nodes stay collapsed.
    t1_force_collapsed: bool = false,
    /// After a details step, unrecorded T1 nodes stay expanded.
    t1_force_expanded: bool = false,

    pub const Level = enum {
        /// ▶ T0 umbrella only
        t0_only,
        /// ▼ T0 + ● T1 headers
        t1_headers,
        /// ▼ T0 + expanded T1 tool rows
        t1_details,
    };

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
        if (self.t1_force_expanded) return true;
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

    pub fn levelForTurn(self: *const ToolCollapseTree, turn_key: u64, defaults: CollapseDefaults) Level {
        if (!self.turnIsExpanded(turn_key, defaults)) return .t0_only;
        if (self.t1_force_expanded) return .t1_details;
        if (self.t1_force_collapsed) return .t1_headers;
        if (defaults.group_expanded) return .t1_details;
        return .t1_headers;
    }

    /// `[` — step collapse: details → headers → T0 only.
    pub fn stepCollapse(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64, defaults: CollapseDefaults) !void {
        switch (self.levelForTurn(turn_key, defaults)) {
            .t1_details => try self.expandT0KeepT1Collapsed(alloc, turn_key),
            .t1_headers => try self.collapseAllToT0(alloc, turn_key),
            .t0_only => {
                self.setPreferredTurn(turn_key);
            },
        }
    }

    /// `]` — step expand: T0 only → headers → details.
    pub fn stepExpand(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64, defaults: CollapseDefaults) !void {
        switch (self.levelForTurn(turn_key, defaults)) {
            .t0_only => try self.expandT0KeepT1Collapsed(alloc, turn_key),
            .t1_headers => try self.expandT1Details(alloc, turn_key),
            .t1_details => {
                self.setPreferredTurn(turn_key);
            },
        }
    }

    pub fn collapseAllToT0(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64) !void {
        try self.setTurnExpanded(alloc, turn_key, false);
        self.t1_force_expanded = false;
        // Keep t1_force_collapsed so re-opening with ] lands on headers first.
        self.t1_force_collapsed = true;
        var it = self.group_expanded.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = false;
        }
    }

    pub fn expandT0KeepT1Collapsed(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64) !void {
        try self.setTurnExpanded(alloc, turn_key, true);
        self.t1_force_expanded = false;
        self.t1_force_collapsed = true;
        var it = self.group_expanded.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = false;
        }
    }

    pub fn expandT1Details(self: *ToolCollapseTree, alloc: std.mem.Allocator, turn_key: u64) !void {
        try self.setTurnExpanded(alloc, turn_key, true);
        self.t1_force_collapsed = false;
        self.t1_force_expanded = true;
        var it = self.group_expanded.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = true;
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

test "bracket level walk expands past T1 headers" {
    const alloc = std.testing.allocator;
    var tree: ToolCollapseTree = .{};
    defer tree.deinit(alloc);
    const defaults = CollapseDefaults.fromCollapseToolCalls(true);

    // Default with collapse_tool_calls: T0 open, T1 headers.
    try std.testing.expect(tree.levelForTurn(7, defaults) == .t1_headers);

    try tree.stepExpand(alloc, 7, defaults);
    try std.testing.expect(tree.levelForTurn(7, defaults) == .t1_details);
    try std.testing.expect(tree.groupIsExpanded(99, defaults));

    try tree.stepCollapse(alloc, 7, defaults);
    try std.testing.expect(tree.levelForTurn(7, defaults) == .t1_headers);
    try std.testing.expect(!tree.groupIsExpanded(99, defaults));

    try tree.stepCollapse(alloc, 7, defaults);
    try std.testing.expect(tree.levelForTurn(7, defaults) == .t0_only);

    try tree.stepExpand(alloc, 7, defaults);
    try std.testing.expect(tree.levelForTurn(7, defaults) == .t1_headers);

    try tree.stepExpand(alloc, 7, defaults);
    try std.testing.expect(tree.levelForTurn(7, defaults) == .t1_details);
}
