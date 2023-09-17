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
		apps = forAll systems (system:
			forAll subdirs (subdir:
				let
					configuration = { modulesPath, ... }: {
						imports = [
							./${subdir}/configuration.nix
							"${modulesPath}/virtualisation/qemu-vm.nix"
						];
						virtualisation.host.pkgs = nixpkgs.legacyPackages.${system};
						virtualisation.qemu.guestAgent.enable = false;
					};
					nixos = nixpkgs.lib.nixosSystem {
						modules = [ configuration ];
						system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
					};
				in {
					type = "app";
					program = "${nixos.config.system.build.vm}/bin/run-${nixos.config.networking.hostName}-vm";
				}
			)
		);
	};
}
