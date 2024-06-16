{ lib, raspberry, modulesPath, ... }: {
	imports = [
		raspberry.nixosModules.raspberry-pi
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/conserve-storage.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "24.11";
	nixpkgs.system = "aarch64-linux";

	# disable WiFi, Ethernet only
	networking.hostName = "chaldene";
	networking.wireless.enable = lib.mkForce false;
}
