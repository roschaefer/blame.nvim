{
  description = "Development environment for blame.nvim";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.neovim
            pkgs.git
            # `tests/minit.lua` bootstraps lazy.nvim with curl
            pkgs.curl
            pkgs.stylua
            pkgs.lua-language-server
            pkgs.luajitPackages.llscheck
          ];
        };
      });
    };
}
