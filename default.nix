{...}:
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
  nativeBuildInputs = [ pkgs.hugo pkgs.git ];
in
rec {
  shells = {
    default = pkgs.mkShell {
      packages = [ pkgs.npins ];
      inherit nativeBuildInputs;
    };
  };
  package = {
    default = pkgs.stdenvNoCC.mkDerivation {
      name = "tfrancisl.github.io";
      src = ./.;
      inherit nativeBuildInputs;
      buildPhase = "hugo build --gc --minify";
      installPhase = "cp -r public $out";
    };
  };
  default = shells.default;
}
