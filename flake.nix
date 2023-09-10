{
	description = "systems based on Nix and NixOS";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	outputs = { self, nixpkgs }: let
		systems = [ "x86_64-linux"  "x86_64-darwin" ];
		subdirs = [ "print-server" "rescue" ];
		lib = import "${nixpkgs}/lib";
		forAll = list: f: lib.genAttrs list f;

	in {
		packages = forAll systems (system:
			forAll subdirs (subdir:
				import ./${subdir} { inherit nixpkgs system; }
			)
		);
	};
}
