{
  description = "Utility to control Neovim colorscheme from the terminal";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = {zig2nix, ...}: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
    # Zig flake helper
    # Check the flake.nix in zig2nix project for more options:
    # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
    env = zig2nix.outputs.zig-env.${system} {
      zig = zig2nix.packages.${system}.zig-0_14_1;
    };
  in {
    packages.default = env.package {
      pname = "obsidian-remote";
      version = "0.0.0";
      src = ./cli;

      meta = {
        description = "Reference client for obsidian-remote";
        mainProgram = "obsidian-remote";
      };
    };

    packages.plugin = env.pkgs.callPackage ./plugin env.pkgs;

    # nix run .#zon2json
    apps.zig2nix = env.app [env.zig2nix] "zig2nix \"$@\"";

    # nix develop
    devShells.default = env.mkShell {};
  }));
}
