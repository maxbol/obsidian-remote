{buildNpmPackage, ...}:
buildNpmPackage {
  pname = "obsidian-plugin-obsidian-remote";
  version = "1.0.0";
  src = ./.;
  npmDepsHash = "sha256-JJV1EIT8LpFf4705clZLjHnDxZpA7m15QgQybGIasMc=";

  installPhase = ''
    mkdir -p $out
    cp -R $src/* $out
  '';
}
