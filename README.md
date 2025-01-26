# Obsidian Remote

Enables remote control of Obsidian via msgpack. Includes a reference cli client written in zig that interacts with the IPC server instantiated by the plugin.

## Disclaimer

This plugin relies on undocumented and untyped parts of the Obsidian JS API. As such, we can conclude that the Obsidian developers consider these APIs an implementation detail rather than a public interface. As such, they could potentially change at any time, breaking the plugin.

## Installing the plugin

Currently, there are no plans of submitting this plugin to the official directory since I'm not sure anyone else is interested. To install the plugin, simply copy the `plugin` folder to your vault's `.obsidian/plugins` directory. For example:

```bash
cp -r plugin ~/vaults/my-notes/.obsidian/plugins/obsidian-remote
```

## Installing the CLI tool

The main supported way of building and installing the tool is via nix:

```bash
nix build .#default
cp result/bin/obsidian-remote ~/bin # or wherever you keep your local binaries
```

If you want to try installing it without nix, make sure you have version `0.14.0-dev.2851+b074fb7dd` of zig installed, go to the `cli` directory and run:

```bash
zig build -Doptimize=ReleaseFast
cp zig-out/bin/obsidian-remote ~/bin # or wherever you keep your local binaries
```

## Using the CLI tool

Once the plugin is installed and activated in Obsidian, you can use the CLI tool to probe the command palette of the running Obsidian instance.

```bash
obsidian-remote list-commands --include-names
```

This returns a list of all commands in the palette:

```text
🛠️ editor:save-file
    Name: Save current file
🛠️ workspace:toggle-pin
    Name: Toggle pin
🛠️ workspace:split-vertical
    Name: Split right
🛠️ workspace:split-horizontal
    Name: Split down
🛠️ workspace:toggle-stacked-tabs
    Name: Toggle stacked tabs
🛠️ workspace:edit-file-title
    Name: Rename file
...
```

To run any command in the list, simply run:

```bash
obsidian-remote run-command editor:save-file
```


