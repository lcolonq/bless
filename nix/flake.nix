{
  description = "bless";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fig.url = "github:lcolonq/fig-server";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      haskellOverrides = self: super: {
        fig-utils = inputs.fig.packages.${system}.figUtils;
        fig-bus = inputs.fig.packages.${system}.figBus;
      };
      haskellPackages = pkgs.haskell.packages.ghc94.override {
        overrides = haskellOverrides;
      };
      ghc = haskellPackages.ghcWithPackages (hpkgs: with hpkgs; [
        base
        aeson
        base64
        binary
        bytestring
        containers
        data-default-class
        directory
        errors
        filepath
        http-types
        http-client
        http-client-tls
        lens
        megaparsec
        mtl
        req
        safe-exceptions
        text
        time
        tomland
        transformers
        unordered-containers
        vector
        fig-utils
        fig-bus
      ]);
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          ghc
        ];
      };
    };
}
