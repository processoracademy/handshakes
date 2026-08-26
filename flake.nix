{
  description = "systemverilog handshakes library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moppkgs.url = "github:Mop-u/moppkgs";
    fusesoc-flake.url = "git+https://tangled.org/moppu.dev/fusesoc-flake?ref=refs/tags/v0.3.2";
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
          inherit (inputs.fusesoc-flake.legacyPackages.${system}) fusesocCores fusesocTools;

          externalCores = fusesocTools.mkCoreSet [ fusesocCores.""."".fifo."1.3-r1" ];

          coreSet = fusesocTools.extendCoreSet externalCores (fusesocTools.importCores ./src);

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
                  ++ (map (x: "${x}") (fusesocTools.toCoreList externalCores));
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
          packages.${system} = {
            default = fusesocTools.dumpCores self.legacyPackages.${system}.fusesocCores;
            docs = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
              pname = "handshakes-docs";
              inherit (coreSet.processoracademy.handshakes.handshakes) version;
              src = ./.;
              nativeBuildInputs = [ naturaldocs ];
              buildPhase = ''
                mkdir -p docs
                NaturalDocs nd_config --simple-console-output
              '';
              installPhase = ''
                mv ./docs $out
              '';
            });
          };
          devShells.${system}.default = pkgs.mkShell {
            packages = [
              fusesoc
              naturaldocs
              pkgs.verible
              slang-server
            ];
            shellHook = ''
              export OBJCACHE=ccache
              export FUSESOC_CONFIG=${fusesocTools.mkConf self.legacyPackages.${system}.fusesocCores}
              mkdir -p .slang
              ln -vfs ${slangConf} .slang/server.json
              mkdir -p docs
              NaturalDocs nd_config
            '';
          };
          checks.${system} = {
            inherit (self.packages.${system}) default docs;
            inherit ((self.legacyPackages.${system}.fusesocCores.""."".fifo.withTools [ pkgs.iverilog ]).run)
              fifo_fwft_tb
              dual_clock_fifo_tb
              ;
          };
        }
      )
    );
}
