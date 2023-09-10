{ config, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/minimal.nix"
		"${modulesPath}/profiles/headless.nix"
		../customization.nix
	];
	system.stateVersion = "23.05";

	networking.hostName = "nixos-${builtins.baseNameOf ./.}";
	networking.firewall.enable = false;
	services.avahi.enable = true;
	services.openssh = {
		enable = true;
		settings.PermitRootLogin = "yes";
		settings.PasswordAuthentication = false;
	};

	users.users.root.openssh.authorizedKeys.keys = [
		config.customization.authorizedKey
	];
}
