{ config, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/minimal.nix"
		"${modulesPath}/profiles/headless.nix"
		../customization.nix
	];
	system.stateVersion = "23.11";

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

	networking.hostName = "nixos-${builtins.baseNameOf ./.}";
	networking.firewall.enable = false;
	services.avahi.enable = true;
	services.openssh = {
		enable = true;
		settings.PermitRootLogin = "yes";
		settings.PasswordAuthentication = false;
		settings.KbdInteractiveAuthentication = false;
	};
	users.users.root.openssh.authorizedKeys.keys = [
		config.customization.authorizedKey
	];
}
