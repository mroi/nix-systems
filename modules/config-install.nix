{ config, pkgs, name, ... }: {

	config.boot.postBootCommands = let
		configFiles = pkgs.stdenvNoCC.mkDerivation {
			name = "configuration";
			src = ./..;
			phases = [ "unpackPhase" "installPhase" ];
			installPhase = ''
				mkdir $out
				cp -r $src/${name} $out/
				cp -r $src/modules $out/
				cp $src/customization.nix $out/
				cp $src/flake.* $out/
			'';
		};
	in ''
		# copy system configuration flake
		if ! test -f /etc/nixos/flake.nix ; then
			cp -r ${configFiles}/* /etc/nixos/
			chmod -R u+w /etc/nixos/*
		fi
	'';
}
