{
	description = "systems based on Nix and NixOS";
	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	outputs = { self, nixpkgs }: let
		systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux"  "x86_64-darwin" ];
		subdirs = [ "print-server" "rescue" "time-machine" "vmware-host" ];
		modules = [ "auto-upgrade" "config-install" "conserve-storage" "ssh-wifi-access" "stress-test-tools" ];
		forAll = list: f: nixpkgs.lib.genAttrs list f;
		callPackage = system: nixpkgs.lib.callPackageWith (nixpkgs.legacyPackages.${system} // {
			inherit (nixpkgs) lib;
		});
		unsupported = {
			"aarch64-darwin" = [ "vmware-host" ];
			"aarch64-linux" = [ "vmware-host" ];
		};

	in {
		packages = forAll systems (system:
			forAll subdirs (subdir:
				callPackage system ./${subdir}/package.nix {}
			)
		);
		apps = builtins.mapAttrs (n: v: builtins.removeAttrs v unsupported."${n}" or []) (
			forAll systems (system:
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
							specialArgs = { name = subdir; };
						};
					in {
						type = "app";
						program = "${nixos.config.system.build.vm}/bin/run-${nixos.config.networking.hostName}-vm";
						meta.description = "QEMU VM of ${subdir} for testing";
					}
				) // {
					ssh = {
						type = "app";
						program = "${nixpkgs.legacyPackages.${system}.writeScript "ssh-nixos" ''
							ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -i ~/.ssh/nixos -p 22022 root@localhost
						''}";
						meta.description = "SSH client connecting to a test VM";
					};
				}
			)
		);
		nixosModules = forAll modules (module:
			import modules/${module}.nix
		);
		nixosConfigurations = forAll subdirs (subdir:
			nixpkgs.lib.nixosSystem {
				system = "aarch64-linux";
				modules = [ ./${subdir}/configuration.nix ];
				specialArgs = { name = subdir; };
			}
		);
	};
}
