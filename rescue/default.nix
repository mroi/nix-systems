{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:

let
	configuration = { modulesPath, ... }: {
		imports = [
			./configuration.nix
			"${modulesPath}/installer/cd-dvd/iso-image.nix"
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
