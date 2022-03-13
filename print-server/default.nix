{ nixpkgs ? <nixpkgs>, system ? builtins.currentSystem }:
with import nixpkgs { inherit system; };

let
	configuration = { pkgs, ... }: {
		# full cross compilation is possible, but too expensive
		# nixpkgs.crossSystem = { config = "aarch64-linux"; };
		imports = [
			(nixpkgs + "/nixos/modules/installer/sd-card/sd-image-aarch64.nix")
			(nixpkgs + "/nixos/modules/profiles/minimal.nix")
		];
		sdImage.compressImage = false;
	};

	nixos = import (nixpkgs + "/nixos") {
		inherit configuration;
		system = "aarch64-linux";
	};

in nixos.config.system.build.sdImage
