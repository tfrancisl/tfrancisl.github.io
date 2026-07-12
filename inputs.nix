let
  inputs = import ./.tack;
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};

in
{
  inherit inputs pkgs system;
}
