{ config, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/minimal.nix"
		"${modulesPath}/profiles/headless.nix"
		../customization.nix
	];
	system.stateVersion = "23.11";

	# FIXME: SSH crashes with the Rust nscd implementation
	services.nscd.enableNsncd = false;

	# system upgrades and garbage collection
	system.autoUpgrade = {
		enable = true;
		operation = "boot";
		channel = config.system.defaultChannel;
	};
	nix = {
		settings.max-jobs = 1;
		gc.automatic = true;
		gc.options = "--delete-older-than 100d";
	};

	# reduce writes to the SD card and enable trimming
	fileSystems."/".options = [ "noatime" ];
	fileSystems."/tmp" = {
		device = "none";
		fsType = "tmpfs";
		options = [ "mode=1777" ];
	};
	services.journald.extraConfig = "Storage=volatile";
	services.fstrim.enable = true;

	# configure basic network services
	networking = {
		hostName = "nixos-${builtins.baseNameOf ./.}";
		firewall.enable = false;
		wireless.enable = true;
		wireless.networks.${config.customization.wifi.ssid}.psk = config.customization.wifi.password;
	};
	services.avahi = {
		enable = true;
		publish.enable = true;
		publish.userServices = true;
		extraServiceFiles = {
			ssh = "${pkgs.avahi}/etc/avahi/services/ssh.service";
		};
	};
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
