{ lib, system }:

let
	configuration = {
		imports = [
			./configuration.nix
		];
		image.baseName = lib.mkForce (builtins.baseNameOf ./.);
		isoImage = {
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
