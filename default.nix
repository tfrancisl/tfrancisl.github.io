{...}:
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
  nativeBuildInputs = [ pkgs.hugo pkgs.go pkgs.git ];
in
rec {
  shells = {
    default = pkgs.mkShell {
      packages =  [ pkgs.npins ];
      inherit nativeBuildInputs;
    };
  };
  package = {

    default = let
    hugoModules = pkgs.stdenvNoCC.mkDerivation {
        name = "hugo modules";
        outputHashMode = "recursive";
        inherit nativeBuildInputs;
        src = ./.;
        outputHash = "sha256-kuyhB/MTpcKc/HHWlHW2XtQAElpFF6cn+HadniLNC3g=";
        buildPhase = "hugo mod vendor";
        installPhase = ''
        cp -r _vendor/ $out
        '';
    };
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = "tfrancisl.github.io";
      src = ./.;
      inherit nativeBuildInputs;

      buildPhase = ''
        mkdir -p _vendor/
        cp -r ${hugoModules}/* _vendor/
        hugo build --gc --minify
      '';

      installPhase = "cp -r public $out";
    };
  };
  default = shells.default;
}
