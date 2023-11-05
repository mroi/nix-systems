{
	description = "systems based on Nix and NixOS";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	outputs = { self, nixpkgs }: let
		systems = [ "x86_64-linux"  "x86_64-darwin" ];
		subdirs = [ "print-server" "rescue" ];
		modules = [ "auto-upgrade" "config-install" "ssh-wifi-access" "stress-test-tools" ];
		forAll = list: f: nixpkgs.lib.genAttrs list f;

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
						virtualisation.forwardPorts = [{
							from = "host";
							host.address = "127.0.0.1";
							host.port = 22022;
							guest.port = 22;
						}];
					};
					nixos = nixpkgs.lib.nixosSystem {
						modules = [ configuration ];
						system = builtins.replaceStrings [ "darwin" ] [ "linux" ] system;
					};
				in {
					type = "app";
					program = "${nixos.config.system.build.vm}/bin/run-${nixos.config.networking.hostName}-vm";
				}
			) // {
				ssh = {
					type = "app";
					program = "${nixpkgs.legacyPackages.${system}.writeScriptBin "ssh-nixos" ''
						ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -i ~/.ssh/nixos -p 22022 root@localhost
					''}/bin/ssh-nixos";
				};
			}
		);
		nixosModules = forAll modules (module:
			import modules/${module}.nix
		);
		nixosConfigurations = forAll subdirs (subdir:
			import ./${subdir}/configuration.nix
		);
	};
}
