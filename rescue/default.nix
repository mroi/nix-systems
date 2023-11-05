{ nixpkgs, system }:

let
	configuration = { modulesPath, ... }: {
		imports = [
			./configuration.nix
		];
		isoImage = {
			isoBaseName = builtins.baseNameOf ./.;
			makeEfiBootable = true;
			makeUsbBootable = true;
			prependToMenuLabel = "Rescue ";
			appendToMenuLabel = "";
		};
	};

	nixos = nixpkgs.lib.nixosSystem {
		system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
		modules = [ configuration ];
	};

in nixos.config.system.build.isoImage
