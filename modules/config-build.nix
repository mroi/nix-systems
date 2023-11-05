{ pkgs ? (import <nixpkgs> {}), folder }:

pkgs.stdenvNoCC.mkDerivation {
	name = "configuration";
	src = ./..;
	phases = [ "unpackPhase" "installPhase" ];
	installPhase = ''
		mkdir $out
		cp -r $src/${folder} $out/
		cp -r $src/modules $out/
		cp $src/customization.nix $out/
	'';
}
