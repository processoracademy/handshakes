{
  description = "systemverilog handshakes library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moppkgs.url = "github:Mop-u/moppkgs";
    fusesoc-flake.url = "github:Mop-u/fusesoc-flake";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      forEachSystem = systems: f: builtins.foldl' (lib.recursiveUpdate) { } (map f systems);
    in
    (forEachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        inherit (inputs.moppkgs.packages.${system})
          slang-server
          ;
        inherit (inputs.fusesoc-flake.packages.${system})
          fusesocLib
          mkFusesocCore
          runFusesocCore
          ;

        slangConf = pkgs.writeText "server.json" (
          builtins.toJSON {
            flags = lib.concatStringsSep " " [
              "-Weverything"
              "-Wno-empty-output-connection"
              "-DSIM_DEBUG"
              "-DSV2V"
              "-I ${./src/handshakes/base/rtl}"
            ];
            index = [
              {
                dirs = [ "src" ];
                excludeDirs = [
                  "build"
                  ".direnv"
                ];
              }
            ];
          }
        );

      in
      {
        devShells.${system}.default =
          (runFusesocCore (finalAttrs: {
            core = fusesocLib.readYAML ./src/handshakes/handshakes/handshakes.core;
            target = "default";
            dependencies = [ ./src/handshakes ];
            nativeBuildInputs = [
              slang-server
              pkgs.verible
            ];
          })).overrideAttrs
            (
              final: prev: {
                shellHook =
                  (prev.shellHook or "")
                  + "\n"
                  + ''
                    mkdir -p .slang
                    rm -f .slang/server.json
                    ln -s ${slangConf} .slang/server.json
                  '';
              }
            );
      }
    ));
}
