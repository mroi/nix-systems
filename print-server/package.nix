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
		system = "aarch64-linux";
		modules = [ configuration ];
	};

in nixos.config.system.build.sdImage
