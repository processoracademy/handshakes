{
  description = "systemverilog handshakes library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moppkgs.url = "github:Mop-u/moppkgs";
    fusesoc-flake.url = "github:Mop-u/fusesoc-flake/v0.3.0";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      forEachSystem = systems: f: builtins.foldl' (lib.recursiveUpdate) { } (map f systems);
    in
    (forEachSystem
      [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ]
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          inherit (inputs.moppkgs.packages.${system}) slang-server naturaldocs;
          inherit (inputs.fusesoc-flake.packages.${system}) fusesoc;

          externalCores = fusesoc.lib.mkCoreSet [ fusesoc.lib.cores.""."".fifo."1.3-r1" ];

          coreSet = fusesoc.lib.extendCoreSet externalCores (fusesoc.lib.importCores ./src);

          slangConf = pkgs.writeText "server.json" (
            builtins.toJSON {
              flags = lib.concatStringsSep " " [
                "-Weverything"
                "-Wno-empty-output-connection"
                "-DSIM_DEBUG"
                "-I src/handshakes/base/rtl"
              ];
              index = [
                {
                  dirs = [
                    "src"
                  ]
                  ++ (map (x: "${x}") (fusesoc.lib.toCoreList externalCores));
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
          legacyPackages.${system}.fusesocCores = coreSet;
          packages.${system}.default = fusesoc.lib.dumpCores coreSet;
          devShells.${system}.default = pkgs.mkShell {
            packages = [
              (fusesoc.lib.wrapFusesoc coreSet)
              slang-server
              pkgs.verible
              naturaldocs
            ];
            shellHook = ''
              export OBJCACHE=ccache
              mkdir -p .slang
              ln -vfs ${slangConf} .slang/server.json
              mkdir -p docs
              NaturalDocs nd_config
            '';
          };
          checks.${system} = {
            inherit ((coreSet.""."".fifo.withTools [ pkgs.iverilog ]).run)
              fifo_fwft_tb
              dual_clock_fifo_tb
              ;
          };
        }
      )
    );
}
