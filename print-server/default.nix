{ nixpkgs, system }:

let
	configuration = { modulesPath, ... }: {
		imports = [
			./configuration.nix
			"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
		];
		sdImage = {
			imageBaseName = builtins.baseNameOf ./.;
			compressImage = false;
		};
	};

	nixos = nixpkgs.lib.nixosSystem {
		system = "aarch64-linux";
		modules = [ configuration ];
	};

in nixos.config.system.build.sdImage
