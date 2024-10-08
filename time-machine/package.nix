{ lib }:

let
	configuration = {
		imports = [
			./configuration.nix
			../modules/config-install.nix
		];
		sdImage = {
			imageBaseName = builtins.baseNameOf ./.;
			compressImage = false;
		};
	};

	nixos = lib.nixosSystem {
		modules = [ configuration ];
		specialArgs = { name = builtins.baseNameOf ./.; };
	};

in nixos.config.system.build.sdImage
