const std = @import("std");
const clap = @import("clap");
const api = @import("api.zig");

const unix_socket_path = "/tmp/obsidian-remote.sock";

const SubCommands = enum {
    @"list-commands",
    @"run-command",
};

const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
    .@"command-id" = clap.parsers.string,
};

const main_params = clap.parseParamsComptime(
    \\<command>                     The command to run. One of: list-commands, run-command.
    \\
    \\-h, --help                    Show this help message.
    \\
);

const MainArgs = clap.ResultEx(clap.Help, &main_params, main_parsers);

pub fn runCmd(allocator: std.mem.Allocator, cmd_id: []const u8) !void {
    const stdout = std.io.getStdOut();
    const stdout_writer = stdout.writer();

    const stream = try std.net.connectUnixSocket(unix_socket_path);
    defer stream.close();

    const msg_id = 0;

    const pack = try api.sendRunCmdRequest(allocator, stream, msg_id, cmd_id);

    const response = try pack.read(allocator);
    defer response.free(allocator);

    try api.ensureNoErrors(response);

    try stdout_writer.writeAll("OK!\n");
}

pub fn listCmds(allocator: std.mem.Allocator, include_names: bool, include_icons: bool) !void {
    const stdout = std.io.getStdOut();
    const stdout_writer = stdout.writer();

    const stream = try std.net.connectUnixSocket(unix_socket_path);
    defer stream.close();

    const msg_id = 0;

    const pack = try api.sendListCmdsRequest(allocator, stream, msg_id, include_names, include_icons);

    const response = try pack.read(allocator);
    defer response.free(allocator);

    try api.ensureNoErrors(response);

    var entry_buf: []api.CommandEntry = try allocator.alloc(api.CommandEntry, 1024);
    const entry_count = try api.handleListCmdsResponse(response, entry_buf, include_names, include_icons);

    try stdout_writer.writeAll(try std.fmt.allocPrint(allocator, "{d} commands found:\n", .{entry_count}));

    for (entry_buf[0..entry_count]) |entry| {
        try stdout_writer.writeAll(try std.fmt.allocPrint(allocator, "🛠️ {s}\n", .{entry.id}));

        if (include_names and entry.name[0] != 0) {
            try stdout_writer.writeAll(try std.fmt.allocPrint(allocator, "    Name: {s}\n", .{entry.name}));
        }

        if (include_icons and entry.icon[0] != 0) {
            try stdout_writer.writeAll(try std.fmt.allocPrint(allocator, "    Icon: {s}\n", .{entry.icon}));
        }
    }
}

pub fn listCmdsMain(allocator: std.mem.Allocator, iter: *std.process.ArgIterator, _: MainArgs) !void {
    const params = comptime clap.parseParamsComptime(
        \\--include-names           Include human readable command names in output.
        \\--include-icons           Include command palette icons in output.
        \\
        \\-h, --help                Show this help message
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, main_parsers, iter, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    var include_names: bool = false;
    var include_icons: bool = false;

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if (res.args.@"include-names" != 0) {
        include_names = true;
    }

    if (res.args.@"include-icons" != 0) {
        include_icons = true;
    }

    try listCmds(allocator, include_names, include_icons);
}

pub fn runCmdMain(allocator: std.mem.Allocator, iter: *std.process.ArgIterator, _: MainArgs) !void {
    const params = comptime clap.parseParamsComptime(
        \\ <command-id>         The ID of the command to run.
        \\
        \\ -h, --help           Show this help message
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, main_parsers, iter, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    const command_id = res.positionals[0] orelse {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    };

    try runCmd(allocator, command_id);
}

pub fn main() !void {
    var fixed_buffer: [10 * 1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&fixed_buffer);
    const allocator = fba.allocator();

    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    _ = iter.next();

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &iter, .{
        .diagnostic = &diag,
        .allocator = allocator,
        .terminating_positional = 0,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});
    }

    const command = res.positionals[0] orelse {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});
    };

    switch (command) {
        .@"list-commands" => {
            return listCmdsMain(allocator, &iter, res);
        },
        .@"run-command" => {
            return runCmdMain(allocator, &iter, res);
        },
    }

    return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});
}
