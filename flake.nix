{
  description = "Nautilus CSS hot-reload patch - live theme updates with matugen";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = import ./module.nix;
    nixosModules.nautilus-css-hot-reload = import ./module.nix;
    
    # Overlay for manual use
    overlays.default = import ./overlay.nix;
  };
}
