{ config, pkgs, ... }: {
	imports = [
		../customization.nix
	];

	# configure basic network services
	networking = {
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
