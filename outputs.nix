{ pkgs, ... }: {
  package = {
    default = pkgs.stdenvNoCC.mkDerivation {
      name = "tfrancisl.github.io";
      # Include .git/ so Hugo can populate per-page .GitInfo in the sandbox.
      # Nix copies this to the build dir (owned by the build user), so git works.
      src = builtins.path {
        path = ./.;
        name = "tfrancisl.github.io-src";
        filter =
          path: _type:
          let
            base = baseNameOf path;
          in
          base != "public" && base != "result" && base != ".direnv";
      };
      nativeBuildInputs = [
        pkgs.hugo
        pkgs.git
        pkgs.typst # for rendered documents
      ];
      buildPhase = ''
        typst compile documents/resume.typ content/resume.pdf
        hugo build --gc --minify
      '';
      installPhase = "cp -r public $out";
    };
  };
}
