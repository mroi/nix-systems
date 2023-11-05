{ config, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
		"${modulesPath}/profiles/minimal.nix"
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "23.11";
	environment.noXlibs = false;  # set true by minimal.nix, but causes binary cache misses

	# FIXME: SSH crashes with the Rust nscd implementation
	services.nscd.enableNsncd = false;

	# reduce writes to the SD card and enable trimming
	fileSystems."/".options = [ "noatime" ];
	fileSystems."/tmp" = {
		device = "none";
		fsType = "tmpfs";
		options = [ "mode=1777" ];
	};
	services.journald.extraConfig = "Storage=volatile";
	services.fstrim.enable = true;

	# CUPS printing with HP driver
	networking.hostName = "nixos-${builtins.baseNameOf ./.}";
	services.printing = {
		enable = true;
		browsing = true;
		stateless = true;
		defaultShared = true;
		listenAddresses = [ "*:631" ];
		allowFrom = [ "all" ];
		drivers = [ pkgs.hplip ];
	};
}
