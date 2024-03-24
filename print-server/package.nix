{ lib }:

let
	configuration = { pkgs, modulesPath, ... }: {
		imports = [
			./configuration.nix
			../modules/config-install.nix
		];
		nix.configFolderName = builtins.baseNameOf ./.;
		sdImage = {
			imageBaseName = builtins.baseNameOf ./.;
			compressImage = false;
		};
	};

	nixos = lib.nixosSystem {
		modules = [ configuration ];
	};

in nixos.config.system.build.sdImage
