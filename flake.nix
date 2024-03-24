{
	description = "systems based on Nix and NixOS";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	outputs = { self, nixpkgs }: let
		systems = [ "x86_64-linux"  "x86_64-darwin" ];
		subdirs = [ "print-server" "rescue" ];
		modules = [ "auto-upgrade" "config-install" "ssh-wifi-access" "stress-test-tools" ];
		forAll = list: f: nixpkgs.lib.genAttrs list f;
		callPackage = system: nixpkgs.lib.callPackageWith (nixpkgs.legacyPackages.${system} // {
			inherit (nixpkgs) lib;
		});

	in {
		packages = forAll systems (system:
			forAll subdirs (subdir:
				callPackage system ./${subdir}/package.nix {}
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
						nixpkgs.system = nixpkgs.lib.mkForce
							(builtins.replaceStrings [ "darwin" ] [ "linux" ] system);
						virtualisation.host.pkgs = nixpkgs.legacyPackages.${system};
						virtualisation.qemu.guestAgent.enable = false;
						virtualisation.forwardPorts = [{
							from = "host";
							host.address = "127.0.0.1";
							host.port = 22022;
							guest.port = 22;
						}];
					};
					nixos = nixpkgs.lib.nixosSystem {
						modules = [ configuration ];
					};
				in {
					type = "app";
					program = "${nixos.config.system.build.vm}/bin/run-${nixos.config.networking.hostName}-vm";
				}
			) // {
				ssh = {
					type = "app";
					program = "${nixpkgs.legacyPackages.${system}.writeScript "ssh-nixos" ''
						ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -i ~/.ssh/nixos -p 22022 root@localhost
					''}";
				};
			}
		);
		nixosModules = forAll modules (module:
			import modules/${module}.nix
		);
		nixosConfigurations = forAll subdirs (subdir:
			nixpkgs.lib.nixosSystem {
				modules = [ ./${subdir}/configuration.nix ];
			}
		);
	};
}
