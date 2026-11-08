{
  description = "Nixos";
  inputs = {
    nixpkgs = {
      url = "nixpkgs/nixos-26.05";
    };

    filem = {
      url = "github:testinfd41-art/filem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs @ { self, nixpkgs, home-manager, spicetify-nix, noctalia, ... }: {
    nixosConfigurations.dope-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs noctalia; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = { inherit inputs spicetify-nix noctalia; };
            users.chris = {
              imports = [
                ./home.nix
                spicetify-nix.homeManagerModules.default
                noctalia.homeModules.default
              ];
            };
          };
        }
      ];
    };
  };
}
