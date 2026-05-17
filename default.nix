{...}:
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
in
rec {
  shells = {
    default = pkgs.mkShell {
      packages =  [ pkgs.npins pkgs.go pkgs.git ];
      buildInputs = [ pkgs.hugo ];
    };
  };
  package = {
    default = pkgs.stdenv.mkDerivation {
      name = "tfrancisl.github.io";
      src = ./.;

      buildPhase = ''
        ${pkgs.hugo}/bin/hugo build --gc --minify
      '';

      installPhase = "cp -r public $out";
    };
  };
  default = shells.default;
}
