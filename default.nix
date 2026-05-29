{...}:
let
  sources = import ./npins;
  pkgs = import sources.nixpkgs { };
  nativeBuildInputs = [
    pkgs.hugo
    pkgs.git
    pkgs.typst # for rendered documents
  ];
in
rec {
  shells = {
    default = pkgs.mkShellNoCC {
      packages = [
        pkgs.npins
      ];
      inherit nativeBuildInputs;
    };
  };
  package = {
    default = pkgs.stdenvNoCC.mkDerivation {
      name = "tfrancisl.github.io";
      # Include .git/ so Hugo can populate per-page .GitInfo in the sandbox.
      # Nix copies this to the build dir (owned by the build user), so git works.
      src = builtins.path {
        path = ./.;
        name = "tfrancisl.github.io-src";
        filter = path: type:
          let base = baseNameOf path; in
          base != "public" && base != "result" && base != ".direnv";
      };
      inherit nativeBuildInputs;
      buildPhase = ''
          typst compile documents/resume.typ content/resume.pdf
          hugo build --gc --minify
      '';
      installPhase = "cp -r public $out";
    };
  };
  default = shells.default;
}
