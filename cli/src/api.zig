const std = @import("std");
const msgpack = @import("msgpack");

const Pack = msgpack.Pack(std.net.Stream, std.net.Stream, std.net.Stream.WriteError, std.net.Stream.ReadError, std.net.Stream.write, std.net.Stream.read);

const MessageType = enum(u2) {
    Request = 0,
    Response = 1,
};

pub const CommandEntry = struct {
    icon: [256]u8,
    id: [512]u8,
    name: [1024]u8,
};

const LIST_CMDS = "list_cmds";
const RUN_CMD = "run_cmd";

fn allocMsgpackPayload(fn_name: []const u8, msg_id: u64, params: msgpack.Payload, allocator: std.mem.Allocator) !msgpack.Payload {
    var payload = try msgpack.Payload.arrPayload(4, allocator);

    try payload.setArrElement(0, msgpack.Payload.uintToPayload(@intFromEnum(MessageType.Request)));
    try payload.setArrElement(1, msgpack.Payload.uintToPayload(msg_id));
    try payload.setArrElement(2, try msgpack.Payload.strToPayload(fn_name, allocator));
    try payload.setArrElement(3, params);

    return payload;
}

pub fn sendListCmdsRequest(allocator: std.mem.Allocator, stream: std.net.Stream, msg_id: u8, include_names: bool, include_icons: bool) !Pack {
    const pack = Pack.init(stream, stream);

    try pack.write(blk: {
        var params = msgpack.Payload.mapPayload(allocator);
        try params.mapPut("includeNames", msgpack.Payload.boolToPayload(include_names));
        try params.mapPut("includeIcons", msgpack.Payload.boolToPayload(include_icons));
        break :blk try allocMsgpackPayload(LIST_CMDS, msg_id, params, allocator);
    });

    return pack;
}

pub fn sendRunCmdRequest(allocator: std.mem.Allocator, stream: std.net.Stream, msg_id: u8, cmd_id: []const u8) !Pack {
    const pack = Pack.init(stream, stream);

    try pack.write(blk: {
        var params = msgpack.Payload.mapPayload(allocator);
        try params.mapPut("cmdId", try msgpack.Payload.strToPayload(cmd_id, allocator));
        break :blk try allocMsgpackPayload(RUN_CMD, msg_id, params, allocator);
    });

    return pack;
}

pub fn handleListCmdsResponse(response: msgpack.Payload, out: []CommandEntry, include_names: bool, include_icons: bool) !usize {
    const data = switch (try response.getArrElement(3)) {
        .arr => |arr| arr,
        else => {
            return error.InvalidResponseData;
        },
    };

    var offset: usize = 0;

    for (data) |cmd_entry| {
        const map = switch (cmd_entry) {
            .map => |map| map,
            else => {
                return error.InvalidResponseData;
            },
        };

        const entry_id = switch (map.get("id") orelse return error.InvalidResponseData) {
            .str => |str| str,
            else => return error.InvalidResponseData,
        };

        if (offset >= out.len) {
            return error.BufferTooSmall;
        }

        const entry: *CommandEntry = &out[offset];
        entry.* = std.mem.zeroes(CommandEntry);

        if (include_names) {
            if (map.get("name")) |name| {
                const entry_name = switch (name) {
                    .str => |str| str,
                    else => null,
                };
                if (entry_name) |payload| {
                    const entry_name_value = payload.value();
                    @memcpy(entry.name[0..entry_name_value.len], entry_name_value);
                }
            }
        }

        if (include_icons) {
            if (map.get("icon")) |icon| {
                const entry_icon = switch (icon) {
                    .str => |entry_icon| entry_icon,
                    else => null,
                };
                if (entry_icon) |payload| {
                    const entry_icon_value = payload.value();
                    @memcpy(entry.icon[0..entry_icon_value.len], entry_icon_value);
                }
            }
        }

        const entry_id_value = entry_id.value();
        @memcpy(entry.id[0..entry_id_value.len], entry_id_value);

        offset += 1;
    }

    return offset;
}

pub fn ensureNoErrors(response: msgpack.Payload) !void {
    const err = switch (try response.getArrElement(2)) {
        .arr => |arr| arr,
        .nil => {
            return;
        },
        else => {
            return error.InvalidErrorObject;
        },
    };

    std.log.err("Encountered errors when parsing msgpack response:", .{});

    for (err) |e| {
        switch (e) {
            .str => |s| {
                std.log.err("  {s}", .{s.value()});
            },
            else => {
                return error.InvalidErrorObject;
            },
        }
    }

    return error.MsgpackResponseError;
}
