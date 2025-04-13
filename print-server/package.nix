{ lib }:

let
	configuration = {
		imports = [
			./configuration.nix
			../modules/config-install.nix
		];
		image.baseName = builtins.baseNameOf ./.;
		sdImage.compressImage = false;
	};

	nixos = lib.nixosSystem {
		modules = [ configuration ];
		specialArgs = { name = builtins.baseNameOf ./.; };
	};

in nixos.config.system.build.sdImage
