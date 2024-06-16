{
	description = "systems based on Nix and NixOS";
	nixConfig = {
		extra-substituters = [ "https://raspberry-pi-nix.cachix.org" ];
		extra-trusted-public-keys = [
			"raspberry-pi-nix.cachix.org-1:WmV2rdSangxW0rZjY/tBvBDSaNFQ3DyEQsVw8EvHn9o="
		];
	};
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	inputs.raspberry.url = "github:tstat/raspberry-pi-nix/6045de5f79ac8eb432cd75e82e1accfb48caff45";
	outputs = { self, nixpkgs, raspberry }: let
		systems = [ "x86_64-linux"  "x86_64-darwin" ];
		subdirs = [ "print-server" "rescue" "time-machine" ];
		modules = [ "auto-upgrade" "config-install" "conserve-storage" "ssh-wifi-access" "stress-test-tools" ];
		forAll = list: f: nixpkgs.lib.genAttrs list f;
		callPackage = system: nixpkgs.lib.callPackageWith (nixpkgs.legacyPackages.${system} // {
			inherit (nixpkgs) lib;
			inherit raspberry;
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
					configuration = { lib, modulesPath, ... }: {
						imports = [
							./${subdir}/configuration.nix
							"${modulesPath}/virtualisation/qemu-vm.nix"
						];
						nixpkgs.hostPlatform = lib.mkForce
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
						specialArgs = { name = subdir; inherit raspberry; };
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
				system = nixpkgs.lib.head systems;
				modules = [ ./${subdir}/configuration.nix ];
				specialArgs = { name = subdir; inherit raspberry; };
			}
		);
	};
}
