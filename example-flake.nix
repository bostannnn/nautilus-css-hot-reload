{
  description = "My configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    elephant.url = "github:abenz1267/elephant";
    matugen.url = "github:InioX/Matugen";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };
    quickshell = {
      url = "github:outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:bostannnn/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      url = "github:outfoxxed/hy3";
    };
    
    # Nautilus CSS hot-reload patch
    nautilus-css-hot-reload = {
      url = "github:bostannnn/nautilus-css-hot-reload";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ nixpkgs, nix-stable, chaotic, walker, quickshell, noctalia, home-manager, nautilus-css-hot-reload, ... }:
    let
      system = "x86_64-linux";
      
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      stable = import nix-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit stable noctalia inputs; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./configuration.nix
          chaotic.nixosModules.default
          walker.nixosModules.default
          home-manager.nixosModules.home-manager
          
          # Nautilus CSS hot-reload
          nautilus-css-hot-reload.nixosModules.default
          
          # Custom packages module
          ({ pkgs, ... }: {
            environment.systemPackages = [
              # git2txt
              (pkgs.buildNpmPackage rec {
                pname = "git2txt";
                version = "1.0.6";
                src = pkgs.fetchFromGitHub {
                  owner = "addyosmani";
                  repo = "git2txt";
                  rev = "main";
                  hash = "sha256-ItVYfKbounZnDQBJ+3klFT6Krvq/iA/gwUqeH8qD/Ms=";
                };
                npmDepsHash = "sha256-6/oMBMJbiu2mRL8NfwQJBDeSsoRdt70CeITmF2agg/E=";
                dontNpmBuild = true;
              })
              # steam-achievement-notifier
              (let
                pname = "steam-achievement-notifier";
                version = "1.9.34";
                src = pkgs.fetchurl {
                  url = "https://github.com/SteamAchievementNotifier/SteamAchievementNotifier/releases/download/${version}/SteamAchievementNotifier_V${version}.AppImage";
                  hash = "sha256-BAPiYroO1ztXkPC+yY6jE/8e5FLMjcmbPtSCRzjpouc=";
                };
                appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };
              in pkgs.appimageTools.wrapType2 {
                inherit pname version src;
                extraInstallCommands = ''
                  install -m 444 -D $(find ${appimageContents} -maxdepth 1 -name '*.desktop') \
                    $out/share/applications/${pname}.desktop
                  install -m 444 -D $(find ${appimageContents} -name '*.png' -path '*/icons/*' | head -1) \
                    $out/share/icons/hicolor/256x256/apps/${pname}.png
                  substituteInPlace $out/share/applications/${pname}.desktop \
                    --replace-fail 'Exec=AppRun' 'Exec=${pname}'
                '';
              })
            ];
          })
          
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit noctalia inputs; };
            home-manager.users.bostan = import ./home.nix;
          }
        ];
      };
    };
}
