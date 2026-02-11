{
    description = "systemverilog handshakes library";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
        fusesoc-flake.url = "github:Mop-u/fusesoc-flake";
    };

    outputs =
        inputs@{ flake-parts, ... }:
        flake-parts.lib.mkFlake { inherit inputs; } {
            imports = [ inputs.fusesoc-flake.flakeModule ];
            systems = [ "x86_64-linux" ];
            perSystem =
                {
                    config,
                    self',
                    inputs',
                    pkgs,
                    system,
                    ...
                }:
                {
                    fusesoc-project = {
                        withVerilator = true;
                        sources.local = "src";
                        extraPackages = [
                            pkgs.verible
                        ];
                    };
                };
        };
}
