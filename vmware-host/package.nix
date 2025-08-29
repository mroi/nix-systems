{ lib, path }:

let
	configuration = { config, pkgs, lib, ... }: {
		imports = [
			./configuration.nix
			../modules/config-install.nix
		];
		system.build.diskImage = import "${path}/nixos/lib/make-disk-image.nix" {
			inherit config pkgs lib;
			name = "${builtins.baseNameOf ./.}-disk-image";
			partitionTableType = "efi";
			additionalSpace = "0M";
		};
	};

	nixos = lib.nixosSystem {
		modules = [ configuration ];
		specialArgs = { name = builtins.baseNameOf ./.; };
	};

in nixos.config.system.build.diskImage
