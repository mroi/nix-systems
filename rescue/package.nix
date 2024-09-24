{ lib, system }:

let
	configuration = {
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

	nixos = lib.nixosSystem {
		system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
		modules = [ configuration ];
	};

in nixos.config.system.build.isoImage
