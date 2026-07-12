let
  inputs = import ./inputs.nix;
  inherit (inputs) pkgs;
in
pkgs.mkShellNoCC {
  packages = [
    pkgs.just
    pkgs.tack
    pkgs.nixfmt-tree
    pkgs.deadnix
    pkgs.statix
    pkgs.nixf-diagnose
    pkgs.gotmplfmt
    pkgs.hugo
    pkgs.git
    pkgs.typst # for rendered documents
  ];
}
