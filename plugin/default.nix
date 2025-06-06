{buildNpmPackage, ...}:
buildNpmPackage {
  pname = "obsidian-plugin-obsidian-remote";
  version = "1.0.0";
  src = ./.;
  npmDepsHash = "sha256-JJV1EIT8LpFf4705clZLjHnDxZpA7m15QgQybGIasMc=";

  postInstall = ''
    cp -R $out/lib/node_modules/obsidian-remote/* $out
    rm -R $out/lib
  '';
}
